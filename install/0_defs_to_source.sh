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
export FNY_ROOT=~/funyun/env
export FNY_HOSTNAME="eaglebytes.org"
export FNY_IP="172.31.24.184"
export FNY_SCRIPT_DIR=$PWD
export FNY_VAR=/var/funyun/${FNY_VERSION}
export FNY_TMP=/tmp/funyun
export FNY_LOG=/var/log/funyun
export FNY_INSTALLER_HOME=~
#
# If FUNYUN_GIT_DIR is defined, the package
# will be installed from git repository, otherwise
# the latest pip version will be used.
# The directory must already have been created via
# git clone https://github.com/EagleBytes2017/funyun.git
#
export FUNYUN_GIT_DIR=~/funyun
export FUNYUN_BUILD_DIR="${FNY_ROOT}/build"
export FUNYUN_TEST_DIR="${FNY_ROOT}/test"
