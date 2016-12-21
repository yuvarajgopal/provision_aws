
PROVISION_AWS 0.3.6 ( TAG = v0.3.6 )
====================================

The provision_aws tool processes a .conf file to automate the
provisioning of AWS resources via calls to CloudFormation.

Documentation
-------------

This README provides some documentation, but more information can be
found in Confluence.

Installation
------------

### Obtaining provision_aws

The script is currently obtainable and installable from the
provision_aws.git repository on the stash server under the DEVOPS
project. It is always best to clone the latest *tagged* version.

Clone this repo, and then do a `make install` from the src/ directory.
This will install files and directories under **/usr/local/aws/cf**.
This directory will need to exist on your system and be writable by
your user id.  The following sequence assumes the latest tag is "v0.3.6".

    cd some-directory
    git clone ssh://git@stash.synchronoss.net:7999/devops/provision_aws.git
    cd provision_aws
    git checkout v0.3.6
    cd src
    make install

  * **DO NOT ATTEMPT TO COMMIT/PUSH TO THIS REPO**

Once it is installed, you will likely want to add the directory
**/usr/local/aws/cf/bin** to your PATH in your profile.

The script seems to work on RHEL/CentOS Linux, as well as MacOS.

provision_aws does require some other tools to be installed.  These include

  * jq, a command line JSON parser, manipulator, and extractor

  * awscli, the AWS command Line Interface.  The AWSCLI will need to
    be properly configured with AWS credentials to manipulate the
    environments.


Change History
--------------

### Changes in Release 0.3.6

  * The function getNewCurrentHostIndex() has been simplified to just take a count of the current number of existing (non-terminated) nodes exist. It would fail to "guess" the correct next nodeindex to use 1/2 of the time.

### Changes in Release 0.3.5

  * The STACK_WAIT parameter in the conf file

### Changes in Release 0.3.4

  * Updated README.md to reflect current version

### Changes in Release 0.3.3

  * add a retry feature for the fetchStackResource function.  This
    kicks in when AWS throttles us because we are sending too many
    requests for resource lookups.

### Changes in Release 0.3.2

  * Fixed a bug with instance naming.  When creating instances using the
    "count" feature, some instances would appear to get node numbers
    count with the wrong  starting value.

  * Converted this REAMDE to markdown and added some information.

### Changes in Release 0.3.1

  * added the -m option specify a Makefile.

### Changes in Release 0.2.13

  * Implement a precedence order for specifying the awscli profile

### Changes in Release 0.2.12

  * fix node numbering for the unpaired node creation

### Changes in Release 0.2.10

  * fixed a host array naming bug
