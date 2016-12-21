#!/bin/bash

VERSION="0.0.1"

SHORT_OPTS="c:l:deftnrzvh"

CONFIG_FILE="provision.conf"
LOG_FILE="aws.log"

ENABLED=0
DISABLED=0
TRUE=0
FALSE=0
ZERO=0
NONZERO=0

VERBOSE=0


usage() {
    cat <<EOF
usage: $0 [ options ] env

options

  -c  file    specify configuration file [$CONFIG_FILE]
  -l  file    set log file [$LOG_FILE]

  -e          show stacks that are enabled (same as -r)
  -f          show stacks that are set false
  -t          show stacks that are set true
  -n          show stacks that are non-zero
  -r          show stacks that will be run (default)
  -d          show stacks that are disabled
  -z          same as -0, show stacks that are zero

  -v          verbose
  -h          display this help and exit

Version $VERSION
EOF
}

logerror() {
    echo $(date "+%Y-%m-%dT%H:%M:%S - ") "ERROR: " $@ | tee -a $LOG_FILE -
}

extract_env_config() { # $1=env
    local ENV="$1"
    if grep  "\[$ENV\]" $CONFIG_FILE > /dev/null 2>&1 ; then
	:
    else
	logerror "$ENV not found in $CONFIG_FILE"
	exit 2
    fi
    sed -n "/^\[$ENV\]/,/^\[$ENV\]/p" $CONFIG_FILE | \
	sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | \
	grep '^RUN_.*STACK='
}

message() {
  local msg="$1"
  if [ $VERBOSE = 1 ]; then
      echo $msg
  fi
}

#
# Process Command Line options
#

prog=`basename $0`

while getopts ":$SHORT_OPTS" opt; do
    case $opt in
	f) FALSE=1 ;;
	t) TRUE=1 ;;
	n) NONZERO=1 ;;
	d) DISABLED=1 ;;
      r|e) ENABLED=1 ;;
	z) ZERO=1 ;;

	c) CONFIG_FILE="$OPTARG" ;;
	l) LOG_FILE="$OPTARG" ;;

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

if [ $# -ne 1 ]; then
  logerror "must specify an environment on the command line"
  usage
  exit 1
fi

sum=$(( $ENABLED + $DISABLED + $ZERO + $NONZERO + $TRUE + $FALSE ))

if [ $sum = 0 ]; then
    # default to showing just the enabled (runnable) stacks
    ENABLED=1
elif [ $sum -gt 1 ]; then
    echo "more than one class was specified, VERBOSE mode enabled"
    VERBOSE=1
fi

ENVIRONMENT=$( echo $1 | tr a-z A-Z )


if [ $ENABLED = 1 ]; then
    message "-- enabled stacks --"
    extract_env_config "$ENVIRONMENT" | \
	grep -v '=0$' | \
	grep -v '=false'
fi

if [ $DISABLED = 1 ]; then
    message "-- disabled stacks --"
    extract_env_config "$ENVIRONMENT" | \
	egrep '=0$|=false$'
fi

if [ $TRUE = 1 ]; then
    message "-- true stacks --"
    extract_env_config "$ENVIRONMENT" | \
	grep '=true$'
fi

if [ $FALSE = 1 ]; then
    message "-- false stacks --"
    extract_env_config "$ENVIRONMENT" | \
	grep '=false$'
fi

if [ $ZERO = 1 ]; then
    message "-- zero stacks --"
    extract_env_config "$ENVIRONMENT" | \
	grep '=0$'
fi

if [ $NONZERO = 1 ]; then
    message "-- non-zero stacks --"
    extract_env_config "$ENVIRONMENT" | \
	grep '=[0-9]*[1-9][0-9]*$'
fi


# ChangeLog
#
# 2014-09-04 0.0.1 SGC initial version
