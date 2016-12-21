#!/bin/bash

SHORT_OPTS="c:km:np:r:uw:vh"

AWS_PROFILE="$PROVISION_AWS_PROFILE"
AWS_RETRIES=10
KEEP=0
NORUN=0
UPDATE=0
DEFAULT_STACK_WAIT=1
VERBOSE=0
VERSION="0.4.1"

CONFIG_FILE=NO-cloudformation_config.ini

CF4DIR=.

MAKEFILE=""

# is there a makefile in the CF4DIR ?
if [ -r $CF4DIR/Makefile ]; then
    MAKEFILE=Makefile
elif [ -r $CF4DIR/makefile ]; then
    MAKEFILE=makefile
fi

# set logging file
LOG_FILE=aws.log
AWS_HOSTS_FILE=/tmp/np-aws_hosts.txt.$$


# this isn't working in osx
mlog () {
  (
   flock -s 200
   echo $(date "+%Y-%m-%dT%H:%M:%S - ") $@ >> $LOG_FILE
  )200>log.flock
}

# use this if running on osx
log () {
   echo $(date "+%Y-%m-%dT%H:%M:%S - ") $@ | tee -a $LOG_FILE
}

logerror() {
   echo $(date "+%Y-%m-%dT%H:%M:%S - ") "ERROR: " $@ | tee -a $LOG_FILE
}


awsCmdWithRetries() { # $1=parms
                      # try to run an aws command with retries
                      # the paraeters rae passed in, so quoting is tricky
                      # it's best to avoid any embedded spaces
    local parms="$1"
    local value cmd try rc delay

    try=0
    cmd="aws $AWS_REGION --profile $AWS_PROFILE --output text $parms"

    rc=255                      # trick into first iteration
    while [ $try -lt $AWS_RETRIES -a $rc != 0 ]; do
        value=$( $cmd )
        rc=$?
        if [ $rc = 255 ]; then
            # assume it was a throttle, do a small sleep
            delay=$(( $RANDOM % $AWS_RETRIES + 1 ))
            log "throttled on try $try, will retry in $delay seconds"
            sleep $delay
        fi
        try=$(( try + 1 ))
    done
    echo "$value"
}


# fetch a resource from an existing cf stack
# the resource can be specified in one of two ways to this function
#   as the first (only) parm as "stack::resource", or
#   as two separate parms, "stack resource"
#
#   arn's often have multiple :'s in them, so we look out for those
# this uses the awsCmdWithRetries becuase too many
# fetch resource calls in a short perioed will get throttled

fetchStackResource() { #
    local stack="$1"
    local logical_id="$2"
    local value

    if [[ -z "$logical_id" && "$stack" == *::* && "$stack" != arn:aws:* ]]; then
        logical_id=`echo $stack | sed 's/^.*:://'`
        stack=`echo $stack | sed 's/::.*$//'`
    fi

    parms='cloudformation list-stack-resources --stack-name '"$stack"'
            --query StackResourceSummaries[?LogicalResourceId==`'"$logical_id"'`].PhysicalResourceId'

    value=$( awsCmdWithRetries "$parms" )
    echo $value
}

# fetch a stack output from an existing cf stack
# the output key resource can be specified in one of two ways
#   as the first (only) parm as "stack::key",
#   as two separate parms, "stack key"
#
# this uses the awsCmdWithRetries becuase too many
# fetch resource calls in a short perioed will get throttled
#
# TODO: have resolve call this if fetchResource returned nothing

fetchStackOutput() { #
    local stack="$1"
    local output_key="$2"
    local value parms

    if [[ -z "$output_key" && "$stack" == *::* && "$stack" != arn:aws:* ]]; then
        output_key=`echo $stack | sed 's/^.*:://'`
        stack=`echo $stack | sed 's/::.*$//'`
    fi

    parms='cloudformation describe-stacks --stack-name '"$stack"'
            --query Stacks[*].Outputs[?OutputKey==`'"$output_key"'`].OutputValue'
    value=$( awsCmdWithRetries "$parms" )

    echo $value
}


#
# convert a param value to its actual stack object if it is a x::y
#   essentially, this is a conditional call to fetchStackresource
# otherwise, just return the original value

function resolveParam() { # $1=pvalue
  local pvalue="$1"
  local newpvalue

  if [[ "$pvalue" == *::* && "$pvalue" != arn:aws:* ]]; then
      newpvalue=$( fetchStackResource "$pvalue" )
      if [ -z "$newpvalue" ]; then
          logerror ".. $pvalue does not resolve"
          exit 5
      fi
      pvalue="$newpvalue"
  fi
  echo "$pvalue"
  return 0
}

# get the hosts names of entities in the vpc

function getVpcHosts() {
    local stack
    local logical_id
    local rc

    if [ -z "$VpcId" ]; then
        logerror "A VpcId must be defined!"
        exit 5
    fi

    if [[ "$VpcId" == *::* ]]; then
        stack=`echo "$VpcId" | sed 's/::.*$//'`
        logical_id=`echo "$VpcId" | sed 's/^.*:://'`
        VpcId=$( fetchStackResource "$stack" "$logical_id" )
    fi

    if [[ "$VpcId" =~ "vpc-[0-9a-f]{8}" ]]; then
        logerror "$VpcId is not a valid VpcId"
        exit 5
    fi

    log "Fetching host list from $VpcId to $AWS_HOSTS_FILE"

    aws --profile $AWS_PROFILE --output text ec2 describe-instances  \
        --filters Name=vpc-id,Values=$VpcId \
                  Name=instance-state-code,Values=0,16,32,64,80 \
        --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' | \
        sort > $AWS_HOSTS_FILE
    rc=$?
    if [ $rc != 0 ]; then
        logerror "unable to fetch hosts from $VpcId"
        exit 5
    fi
}

# return the status of a stack as a string
function getStackStatus() { # $1=Stack
    local stack="$1"
    aws --profile $AWS_PROFILE  \
        cloudformation describe-stacks --stack-name $stack | \
        jq -r '.Stacks[0] | .StackStatus'
}


function stackfailout {
    local STACKNAME="$1"

    until [[ `getStackStatus $STACKNAME` == [CU]*ATE_COMPLETE ]]
    do

        if [ "ROLLBACK_IN_PROGRESS" = "`getStackStatus $STACKNAME`" ]; then

            until [ "ROLLBACK_COMPLETE" = "`getStackStatus $STACKNAME`" ]
            do
                log "Rollback of $STACKNAME in progress.."
                sleep 30
            done

            log "Rollback of $STACKNAME Complete... Deleting Stack..."
            aws cloudformation delete-stack --profile $AWS_PROFILE --stack-name $STACKNAME
            RESPONSETEST=$(aws cloudformation describe-stacks --profile $AWS_PROFILE --stack-name $STACKNAME 2> /dev/null )
            STATUS=$?
            if [ $STATUS -ne 0 ]; then
                log "Delete $STACKNAME Complete exiting now."
                exit 9
            fi

            until [ "DELETE_COMPLETE" = "`getStackStatus $STACKNAME`" ]
            do
                RESPONSETEST=$(aws cloudformation describe-stacks --profile $AWS_PROFILE --stack-name $STACKNAME | grep -q 'does not exist')
                STATUS=$?
                if [ $STATUS ]; then
                    break
                fi
                if [ "DELETE_FAILED" = "`getStackStatus $STACKNAME`" ]; then
                    log "Delete Failed.. Exiting. Check the console for reasons of failure"
                    exit 9
                fi
                log "Delete $STACKNAME in progress.."
                sleep 20
            done
            log "Delete $STACKNAME Complete exiting now."
            exit
        fi

        sleep 30
        log "Waiting for stack $STACKNAME to be created..."

    done
}

function mkParameter() {
  printf '{ "ParameterKey" : "%s", "ParameterValue" : "%s" }' $1 $2
}

# usage: addParameter key value jsonArray
function addParameter {
  NEW_PARAM=`mkParameter $1 $2`
  TMP=$(echo "$3" | sed "s![[:space:]]\]!, ${NEW_PARAM} ]!")
  echo $TMP
}

function getNextLoopIndex {
  echo $(( $1 + 1 ))
}

function getLoopMax {
  echo $(( $1 + $2 ))
}

# this was the old way of finding the current number of
# hosts with a given prefix
# I think it can be replaced by the new version (below)
function getCurrentHostIndex { # $1=nodeprefix
  HOST=$(cat $AWS_HOSTS_FILE | sort | grep "^$1[0-9]\{1,\}\$" | tail -1)

  if [ -z $HOST ]; then
        CURRENT_HOST_INDEX=0
  else
        CURRENT_HOST_INDEX=${HOST: -2}

        if [[ $CURRENT_HOST_INDEX == 0* ]]; then
                CURRENT_HOST_INDEX=${CURRENT_HOST_INDEX: 1}
        fi
  fi
  echo $CURRENT_HOST_INDEX
}

# for the new (unpaired) style, it must undo the new sequence
# e.g, with 2 subnets, [101, 201, 102, 202] -> 1,2,3,4
#           3          [101, 201, 301, 102] -> 1,2,3,4
# this function returns the count of the existing hosts
#     with the specified host prefix and end with the index
function getNewCurrentHostIndex { # $1=node-prefix $2=nsubnets
    local nodeprefix="$1"
    local nsubnets="$2"         # not used

    NHOSTS=$( grep "^${nodeprefix}[0-9]\{1,\}\$" $AWS_HOSTS_FILE | wc -l )
  echo $NHOSTS
}

function uploadCloudFormationTemplate { # $1=stack_name $2=cf_template
    local stack_name="$1"
    local stack_cf="$2"
    local TEMPLATEURL
    TEMPLATEURL="s3://${PRIVATE_BUCKET}/cf/${stack_name}-${stack_cf}"
    if [ "$NORUN" = "1" ]; then
        log ".. NOT Uploading Cloud Formation Template for $stack_name"
    else
        log ".. Uploading $stack_cf Template to S3"
        aws --profile $AWS_PROFILE  $AWS_REGION \
            s3 cp $stack_cf $TEMPLATEURL  >>$LOG_FILE 2>&1
    fi
}


function uploadCloudFormationParameters() { # $1 = stackname, $2=Parameters
  local stack="$1"
  local parms="$2"
  local tmpfile=/tmp/np-${stack}-parms.$$
  local PARMSURL
  PARMSURL="s3://${PRIVATE_BUCKET}/cf/$stack-parameters.json"
  echo "$parms" | jq . > $tmpfile
  if [ "$NORUN" = "1" ]; then
      log ".. NOT Uploading Parameters for $stack"
  else
      log ".. Uploading Parameters for $stack"
      aws --profile $AWS_PROFILE $AWS_REGION \
          s3 cp $tmpfile $PARMSURL >>$LOG_FILE
  fi
  if [ $KEEP = 0 ]; then
      rm -f $tmpfile
  fi
}

extract_conf_variables() { # $1 = config file $2 = section
    local config_file="$1"
    local section="$2"

    sed \
        -e 's/[;#].*$//' \
        -e 's/[[:space:]]*$//' \
        -e 's/^[[:space:]]*//' \
        -e '/^$/d' \
        -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
        -e "s/^\(.*\)=\([^\"']*\)$/\1=\"\2\"/" \
        < $config_file | \
        sed -n -e "/^\s*\[${section}\]/,/^\s*\[/p" | \
        sed -e '/^\[/d'
}


usage() {
cat <<EOF
usage: $0 [ options ] env

options

  -c  file     specify configuration file [$CONFIG_FILE]
  -k           keep (don't delete) tempfiles
  -m  file     specify a makefile [$MAKEFILE]
  -n           don't actually create stacks
  -p  profile  specify profile for awscli [$AWS_PROFILE]
  -r  retries  setthe number of aws retries for some calls [$AWS_RETRIES]
  -u           do an update instead of create
  -w  wait     set default stack wait (true|1 or false|0) [$DEFAULT_STACK_WAIT]
  -v           verbose
  -h           display this help and exit

uses a configuration file to provision one or more cloud formation templates

The templates are expected to be the current directory

Version: $VERSION

EOF
}


#
# Process Command Line options
#

prog=`basename $0`

while getopts ":$SHORT_OPTS" opt; do
  case $opt in
       u) UPDATE=1 ;;
       c) CONFIG_FILE="$OPTARG" ;;
       k) KEEP=1 ;;
       m) MAKEFILE="$OPTARG" ;;
       n) NORUN=1 ;;
       p) AWS_PROFILE="$OPTARG" ;;
       r) AWS_RETRIES="$OPTARG" ;;
       w) DEFAULT_STACK_WAIT="$OPTARG" ;;
       h) usage; exit 0 ;;
       v) VERBOSE=1 ;;
       :) echo "Option -$OPTARG requires an argument." >&2
          exit 1
          ;;
      \?) echo "Invalid option: -$OPTARG" >&2
          usage
          exit 1
          ;;
   esac
done

shift $(($OPTIND - 1))

#
# CHECK COMMAND LINE ARGUMENTS
#

if [ $# -eq 1 ]; then
  ENVIRONMENT=$1
  EnvironmentVar=$1
else
  echo 'Specify environment for the template. (e.g. dev or qa)'
  usage
  exit 1
fi

if [[ ! "$AWS_RETRIES" =~ ^[0-9]+$ ]]; then
    logerror "The retry count $AWS_RETRIES is not numeric!"
    exit 5
fi

if [ -n "$MAKEFILE" ]; then
    if [ -r "$MAKEFILE" ]; then
        ( cd $CF4DIR ; make -f "$MAKEFILE")
        if [ $? != 0 ]; then
            logerror "make in $CF4DIR failed, exiting.."
            exit 9
        fi
    else
        logerror "makefile $MAKEFILE missing or unreadable"
        exit 9
    fi
fi

log "Provisioning AWS environment... $ENVIRONMENT from $CONFIG_FILE"

STACK_BUILD_CMD="create-stack"
if [ $UPDATE = 1 ]; then
    log '.. Updating'
    STACK_BUILD_CMD="update-stack"
fi


# Read environment variables from INI file
ENVIRONMENT_UC=$(echo $ENVIRONMENT | awk '{print toupper($0)}')
ENVIRONMENT_LC=$(echo $ENVIRONMENT | awk '{print tolower($0)}')

# read the default and then ENV specific sections from the config file
# this first rea dis just to get the AWS_PROFILE if present

if [ -z "$AWS_PROFILE" ]; then # if unset, look for AWS_PROFILE in the .conf
    eval $( extract_conf_variables $CONFIG_FILE default | \
        grep '\bAWS_PROFILE\b' )
    eval $( extract_conf_variables $CONFIG_FILE $ENVIRONMENT_UC | \
        grep '\bAWS_PROFILE\b' )
fi

# by now, AWS_PROFILE needs to have been defined

if [ -z "$AWS_PROFILE" ]; then
    logerror "AWS_PROFILE missing or empty"
    exit 2
fi

# get availability zones for account

AVAILABILITY_ZONES=$(aws ec2 describe-availability-zones --profile $AWS_PROFILE | jq -r '.AvailabilityZones[] | .ZoneName')
log 'Availability Zones:' $AVAILABILITY_ZONES

AZ1=$(echo $AVAILABILITY_ZONES | cut -f 1 -d ' ')
AZ2=$(echo $AVAILABILITY_ZONES | cut -f 2 -d ' ')
log "Account AZ1=$AZ1 AZ2=$AZ2"

# read the default and then ENV specific sections from the config file
# don't read the AWS_PROFILE setting again

eval $( extract_conf_variables $CONFIG_FILE default | \
    grep -v '\bAWS_PROFILE\b' )
eval $( extract_conf_variables $CONFIG_FILE $ENVIRONMENT_UC | \
    grep -v '\bAWS_PROFILE\b' | tee /tmp/vars.out )

if [ -n "$AWS_REGION" ]; then
  AWS_REGION="--region $AWS_REGION"
fi

if [ -z "$CF_PROJECT" ]; then
    logerror "CF_PROJECT name missing or empty"
    exit 2
fi


PRIVATE_BUCKET="private.${ENVIRONMENT_LC}.${CF_PROJECT}.sncr"
BASETEMPLATEURL="https://s3.amazonaws.com/$PRIVATE_BUCKET/cf"


log 'Environment:' $ENVIRONMENT_UC
log 'AWS Profile:' $AWS_PROFILE

STACKS=`sed -n '/^\['$ENVIRONMENT_UC'\]/,/^\[/p' $CONFIG_FILE | \
    egrep '^RUN_[A-Za-z_][A-Za-z_0-9]*_STACK=(true|[1-9][0-9]*)' | \
    sed -e 's/^RUN_//' -e 's/_STACK=.*$//'`

log "Stacks to run: $STACKS"

# create tags for the template build if create (only)
TAGS=""
if [ "$STACK_BUILD_CMD" = "create-stack" ]; then
  CF_TAGS="--tags Key=project,Value=$CF_PROJECT Key=environment,Value=$ENVIRONMENT_UC"
fi

for stack in $STACKS; do

  eval run_stack_count=\$RUN_${stack}_STACK
  eval stack_name=\$${stack}_STACK_NAME
  eval stack_cf_template=\$${stack}_CF_TEMPLATE
  eval stack_wait=\$${stack}_STACK_WAIT

  # check for the $stack_STACK_NAME and $stack_CF_TEMPLATE directives
  if [ -z "$stack_name" -o -z "$stack_cf_template" ]; then

      if [ -z "$stack_name" ]; then
          logerror "${stack}_STACK_NAME is undefined in $CONFIG_FILE"
      fi

      if [ -z "$stack_cf_template" ]; then
          logerror "${stack}_CF_TEMPLATE is undefined in $CONFIG_FILE"
      fi

      exit 4
  fi

  if [ ! -r "$stack_cf_template" ]; then
      logerror "template file $stack_cf_template is missing or unreadable"
      exit 4
  fi

  if [ -z "$stack_wait" ]; then
      stack_wait="$DEFAULT_STACK_WAIT"
  fi

  # valcheck stack_wait and coerce it to 0 or 1
  case "$stack_wait" in
      [Tt]rue|1) stack_wait=1;;
      [Ff]alse|0) stack_wait=0 ;;
      *) logerror "${stack}_STACK_WAIT must be true(1) or false(0)"
          exit 9 ;;
  esac

  log "Processing $stack stack ($run_stack_count) from $stack_cf_template"

  # find the parameters of the stack
  PARMS=`jq -c  ".Parameters| keys" $stack_cf_template | \
      tr ][\", ' '`

  PARAMETERS="[ ]"

  for pname in $PARMS; do
    # first check for the long param declaraion
    eval pvalue=\$${stack}_CF_PARAM_${pname}

    # if that is empty (undefined), try the short name
    if [ -z "$pvalue" ]; then
      eval pvalue=\$$pname
    fi

    if [ -z "$pvalue" ]; then
      log ".. $pname will use template default"
    elif [[ "$pvalue" == *::* && "$pvalue" != arn:aws:* ]]; then
      log ".. $pname will resolve from $pvalue"
      newpvalue=$( fetchStackResource "$pvalue" )
      if [ -z "$newpvalue" ]; then
        logerror ".. $pvalue does not resolve!!"
        exit 5
      fi
    log ".. $pname set to $newpvalue"
    eval $pname="$newpvalue"
    PARAMETERS=`addParameter $pname $newpvalue "$PARAMETERS"`
    else
      log ".. $pname set to $pvalue"
      PARAMETERS=`addParameter $pname $pvalue "$PARAMETERS"`
    fi
  done
  # now get rid of the extra "," after the opening "["
  PARAMETERS=`echo $PARAMETERS | sed 's/\[,/\[/'`
  # echo "after loop, PARAMETERS=$PARAMETERS"


  # upload the template to s3
  HTTPTEMPLATEURL=$BASETEMPLATEURL/${stack_name}-${stack_cf_template}
  uploadCloudFormationTemplate ${stack_name} ${stack_cf_template}

  cf_caps=""
  # do we need the IAM capability?
  if grep -q 'Type.*:.*AWS::IAM::' $stack_cf_template; then
      cf_caps="CAPABILITY_IAM"
  fi
  if [ -n "$cf_caps" ]; then
      cf_caps="--capabilities $cf_caps"
  fi

  if [ $run_stack_count = "true" ]; then
      # a single stack instantiation

      uploadCloudFormationParameters $stack_name "$PARAMETERS"

      if [ "$NORUN" = "1" ]; then
          log ".. NOT Creating $stack_name"
      else
          log ".. Creating $stack_name"
          aws cloudformation $STACK_BUILD_CMD \
              --profile $AWS_PROFILE $AWS_REGION \
              --stack-name $stack_name --template-url $HTTPTEMPLATEURL \
              $cf_caps \
              --parameters "$PARAMETERS" $CF_TAGS
          rc=$?
          if [ $rc != 0 ]; then
              logerror "stack create failed (rc=$rc)"
              exit 10
          fi

          stackfailout $stack_name
      fi

  else
      # multiple stack instantiations with a LoopIndex

      getVpcHosts               # populate the aws hosts file

      eval node_name=\$${stack}_CF_PARAM_NodeName
      if [ -z "$node_name" ]; then
          logerror ".. NodeName missing in configuration for $stack"
          exit 5
      fi

      unset subnets subnet_list nsubnets
      eval subnets=\$${stack}_CF_PARAM_SUBNETS
      if [ -z "$subnets" ]; then
          log ".. ${stack}_CF_PARAM_SUBNETS not found"
          current_loop_index=$(getCurrentHostIndex "$node_name")
      else
          log ".. Subnet List is $subnets"

          subnet_list=($subnets)
          nsubnets=${#subnet_list[@]}

          # resolve array elements if they are stack::resource references
          for((i=0; i<$nsubnets; i++)); do
              subnet_list[$i]=$(resolveParam "${subnet_list[$i]}" )
          done

          log ".. Subnet List resolves to ${subnet_list[@]}"

          current_loop_index=$(getNewCurrentHostIndex "$node_name" "#nsubnets")
      fi

      next_loop_index=$(getNextLoopIndex "$current_loop_index")
      loop_max=$(getLoopMax $current_loop_index $run_stack_count)

      log ".. Generating $next_loop_index .. $loop_max stacks"

      for((i=$next_loop_index; i<=$loop_max; i++)); do
          parms="$PARAMETERS"
          node_index=$( printf "%02d" "$i" )

          if [ -n "$nsubnets" ]; then # process subnet list
              zindex=$(( $i - 1 )) # zero-based loop index
              subnet_index=$(( $zindex % $nsubnets ))
              subnet=${subnet_list[subnet_index]}
              subnet=$( resolveParam "$subnet" )
              parms=$(addParameter "Subnet" "$subnet" "$parms")
              log ".. setting Subnet to $subnet"

              # change the node_index to be a three digit value
              subnet_index_p1=$(( $subnet_index + 1 ))
              node_suffix=$(( $zindex / $nsubnets + 1 ))
              node_index=$( printf "%1d%02d" $subnet_index_p1 $node_suffix )
          fi

          parms=$(addParameter "NodeIndex" "$node_index" "$parms")
          log ".. setting NodeIndex to $node_index"

          uploadCloudFormationParameters $stack_name-${node_index} "$parms"

          if [ "$NORUN" = "1" ]; then
              log ".. NOT Creating $stack_name-${node_index}"
          else
              log ".. Creating $stack_name-${node_index}"
              aws cloudformation $STACK_BUILD_CMD \
                  --profile $AWS_PROFILE $AWS_REGION \
                  --stack-name ${stack_name}-${node_index} \
                  --template-url $HTTPTEMPLATEURL \
                  $cf_caps \
                  --parameters "$parms" $CF_TAGS
              rc=$?
              if [ $rc != 0 ]; then
                  logerror "stack create failed (rc=$rc)"
                  exit 10
              fi

              stackfailout ${stack_name}-${node_index} &
          fi

      done

      if [ $stack_wait = 1 ]; then
          wait
      else
          log "not waiting for ${stack} completions"
      fi

  fi

done

# cleanup
if [ $KEEP = 0 ]; then
  rm -f $AWS_HOSTS_FILE
fi

log 'Completed provisioning AWS'
exit 0

# ChangeLog
#
# 0.4.1  2015-12-21 SGC add tags to cf templates
# 0.3.2  2015-04-07 SGC improve hostname regex to reduce overlap mismatches
# 0.3.1  2014-12-09 SGC add -m f to specify a makefile
# 0.2.13 2014-10-09 SGC configurable awscli profile specification
#                       order: env PROVISION_AWS_PROFILE, -p profile, .conf
#                       moved some shell functions to head of file
# 0.2.12 2014-09-30 SGC fix node numbering scheme for new (unpaired) style
# 0.2.11 2014-09-10 SGC bump version
# 0.2.10 2014-09-09 SGC improve conf file variable extraction
# 0.2.9 2014-08-19 SGC host arrays numbered 101,201,...
# 0.2.8 2014-08-12 SGC fix "make" failure to exit provision_aws run
# 0.2.7 2014-08-05 SGC handle subnet list for host arrays
# 0.2.6 2014-08-01 SGC prefix s3 template name with stack name
# 0.2.5 2014-08-01 SGC same as 0.2.2, just moved to new dir
# 0.2.2 2014-06-16 SGC removed long option processing (again)
#                      added error checking for some stack directives
# 0.2.1 2014-06-03 SGC run from "current" directory, not ..; handle ::'s in ARNS
# y.y.y 2014-yy-yy SGC conf file for all configuration
# x.x.x 2013-xx-xx     original version

# TODO
#
# extract stack outputs for values, maybe as STACK..OUTPUT
#
# e.g.,
#
# aws --profile aws-devops cloudformation \
#    describe-stacks --stack-name CHEF-PROXY  \
#    --query 'Stacks[0].Outputs[?OutputKey==`ChefProxyUrl`].OutputValue' \
#    --output text

# Local Variables:
# indent-tabs-mode: nil
# End:
