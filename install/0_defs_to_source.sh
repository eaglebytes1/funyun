#!/usr/bin/env bash
DOC="""Set up the proper environmental variables.

Usage:
   source ${BASH_SOURCE}
"""
#
# Check to see that this script was sourced, not run.
#
if [[ $_ == $0 ]]; then # this file was run, not sourced
  echo "$DOC"
  exit 1
fi
#
# Check for required files and define envvars based on them.
#
txtfilelist=("secret_key"
             "sentry_dsn"
             "crashmail_email")
for txtfile in "${txtfilelist[@]}" ; do
   if [ ! -e ${txtfile}.txt ]; then
      echo "ERROR--must create ${txtfile}.txt file in this directory."
      exit 1
   else
      export FNY_$(echo $txtfile | tr /a-z/ /A-Z/)="$(cat ${txtfile}.txt)"
   fi
done
#
# Exports: edit this to suit yourself.
#
#        FNY-* : Local to the build scripts only.
#      FUNYUN-* : Used in funyun_tool
#
export FNY_VERSION="0.24"
export FNY_ROOT="~/funyun/env"
export FNY_DEV_HOSTNAME="eaglebytes.org"
export FNY_DEV_IP="10.24.27.202"
export FNY_STAGE_HOSTNAME="eaglebytes.org"
export FNY_STAGE_IP="10.24.27.228"
export FNY_PROD_HOSTNAME="eaglebytes.org"
export FNY_PROD_IP="129.186.136.163"
export FNY_INSTALLER=$USER
export FNY_USER="ec2-user"
export FNY_GROUP="ec2-user"
export FNY_SCRIPT_DIR=$PWD
export FNY_VAR=/var/funyun/${FNY_VERSION}
export FNY_TMP=/tmp/funyun
export FNY_LOG=/var/log/funyun
export FNY_INSTALLER_HOME=~
export FUNYUN_BUILD_DIR="${FNY_ROOT}/build"
export FUNYUN_TEST_DIR="${FNY_ROOT}/test"
#
# The following assumes that the user has full sudo
# privs on dev, but only sudo -u $FNY_USER on stage.
#
hostname=$(hostname)
if [ "$hostname" == "$FNY_DEV_HOSTNAME" ]; then
  export FNY_STAGE="dev"
elif [ "$hostname" == "$FNY_STAGE_HOSTNAME" ]; then
  export FNY_STAGE="stage"
elif [ "$hostname" == "$FNY_PROD_HOSTNAME" ]; then
  export FNY_STAGE="prod"
else
  echo "ERROR-unknown host $(hostname)"
  exit 1
fi

#
# Set up the links to config files.
#
if [ "$USER" == "$FNY_INSTALLER" ]; then
  rm -f ~/.funyun
  ln -s ~/.funyun-$FNY_STAGE ~/.funyun
else
  echo "Warning--you are not ${FNY_INSTALLER}, links to ~${FNY_INSTALLER}i/.funyun will be preserved."
fi
#
# Define convenient aliases.
#
alias cd_funyun="cd $FNY_ROOT"
