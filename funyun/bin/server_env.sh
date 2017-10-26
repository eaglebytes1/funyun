#!/usr/bin/env bash
#
# Launch a command in its own proper environment without relying
# on environmental variables being pre-defined.
#
# This script derives the names and values of the variables it creates
# from its own name and its own real path. It makes some use of the
# (slightly unusual) indirect variable expansion ${!var} which evaluates
# to the value referenced by the value of $var.
#
set -e # exit on error
#
error_exit() {
  echo "ERROR--unexpected exit from environment script." 1>&2
}
trap error_exit EXIT
#
myrealpath() {
  if hash realpath 2>/dev/null; then
     realpath "$@"
  else # realpath doesn't exist, fake it
     pushd "$(dirname "$1")" 2&>/dev/null
     islink="$(readlink "$(basename "$1")")"
     while [ "$islink" ]; do
       cd "$(dirname "$islink")"
       islink="$(readlink "$(basename "$1")")"
     done
     path="${PWD}/$(basename "$1")"
     popd 2&>/dev/null
     echo "$path"
  fi
}
#
# Get real paths for later.
#
script_path="$(myrealpath "${BASH_SOURCE}")"
script_name="$(basename "${script_path}")"
bin_dir="$(dirname "${script_path}")"
root_dir="$(dirname "${bin_dir}")"
conf_dir="${root_dir}/etc/conf.d"
#
# Get the names of variables to be defined.
#
pkg="${script_name%_env}"
PKG="$(echo ${pkg} | tr /a-z/ /A-Z/)"
PKG_ROOT="${PKG}_ROOT"
PKG_VAR="${PKG}_VAR"
PKG_TMP="${PKG}_TMP"
PKG_LOG="${PKG}_LOG"
#
# Create the docstring.
#
DOC="""Runs a command in the proper $pkg environment.

Usage:
        ${pkg}_env [-h] [-v] [-i] COMMAND
Flags:
    -h  Print this help message and exit.
    -v  Verbose output on environment before executing command.
    -i  Interactive mode, read commands in a loop.
    -r  Returns the root directory.
Commands:
      The following internal commands are defined:
          start       Starts the ${pkg} server.
           stop       Stops the ${pkg} server.
      All else will launch commands via the shell.
Environmental variables:
      PATH            Will have the binary director(ies) prepended.
      FLASK_APP       Set to \"${pkg}\"
      ${PKG_ROOT}     Set to the parent of the directory this file resides in.
      ${PKG_VAR}      If not set, will be set to \$${PKG_ROOT}/var.
      ${PKG_LOG}      If not set, will be set to \$${PKG_VAR}/log.
      ${PKG_TMP}      If not set, will be set to \$${PKG_VAR}/tmp.
Files:
      ${PKG_ROOT}/etc/conf.d/${pkg}
                      If this file exists, will be sourced before testing
                      the variables above.  This file is generally created
                      at create_instance time.
Location:
     ${script_path}/${script_name}

Joel Berendzen <joelb@ncgr.org>. Copyright (C) 2017, The National Center
for Genome Resources.  All rights reserved.
"""
#
# Process command-line arguments.
#
if [ "$1" == "-h" ]; then
  trap - EXIT
  echo "$DOC"
  exit 0
fi
_V=0
if [ "$1" == "-v" ]; then
  _V=1
  shift 1
fi
_I=0
if [ "$1" == "-i" ]; then
  _I=1
  shift 1
elif [ "$#" -eq 0 ]; then
  trap - EXIT
  echo "$DOC"
  exit 1
fi
if [ "$1" == "-i" ]; then
  echo "$root_dir"
fi
#
start_server() {
   # Create directories, start processes, wait until started.
   pkg_var="${pkg}_var"
   pkg_tmp="${pkg}_tmp"
   pkg_log="${pkg}_log"
   pkg_data="${pkg}_data"
   # Source configuration script.
   if [ ! -e "${conf_dir}/${pkg}" ]; then
      >&2 echo "Unable to source ${conf_dir}/${pkg}."
      trap - EXIT
      exit 1
   fi
   source "${conf_dir}/${pkg}"
   pathlist=("${!pkg_var}"
             "${!pkg_var}/html"
             "${!pkg_var}/run"
             "${!pkg_var}/run/nginx"
             "${!pkg_tmp}"
             "${!pkg_tmp}/nginx"
             "${!pkg_log}"
             "${!pkg_log}/nginx"
             "${!pkg_data}")
   pkg_umask="${pkg}_umask"
   mask="${!pkg_umask}"
   # Create directories, if needed.
   umask $mask
   if [ "$_V" -eq 1 ]; then
      >&2 echo "${pkg}_env start running as user $(whoami)."
   fi
   for path in "${pathlist[@]}" ; do
      if [ ! -d "${path}" ]; then
         if [ "$_V" -eq 1 ]; then
            >&2 echo "Creating directory ${path} with umask ${mask}."
         fi
         mkdir -p ${path}
      fi
   done
   # Start all processes.
   >&2 supervisord -c ${root_dir}/etc/supervisord.conf
   # Wait until starting is done.
   trap - EXIT
   set +e
   while ${script_name} supervisorctl  -c ${root_dir}/etc/supervisord.conf status | grep STARTING >/dev/null; do
      sleep 5
   done
   if [ "$_V" -eq 1 ]; then
      >&2 supervisorctl  -c ${root_dir}/etc/supervisord.conf status
   fi
}
#
stop_server() {
   if [ "$_V" -eq 1 ]; then
      >&2 echo "Stopping ${pkg} processes as user $(whoami)."
   fi
   >&2 supervisorctl  -c ${root_dir}/etc/supervisord.conf mstop \*
   >&2 supervisorctl  -c ${root_dir}/etc/supervisord.conf shutdown
}
#
# Copy command out of argv, else it can mess up later sourcings.
#
command=( "$@" )
shift $#
#
# Set environmental variables.
#
export FLASK_APP="${pkg}"
if [ -e "${root_dir}/etc/${pkg}-conf.sh" ]; then
        source "${root_dir}/etc/${pkg}-conf.sh"
fi
export ${PKG}_ROOT="${root_dir}"
if [ -z "${!PKG_VAR}" ]; then
    export ${PKG_VAR}="${!PKG_ROOT}/var"
fi
if [ -z "${!PKG_LOG}" ]; then
    export ${PKG_LOG}="${!PKG_VAR}/log"
fi
if [ -z "${!PKG_TMP}" ]; then
    export ${PKG_TMP}="${!PKG_VAR}/tmp"
fi
#
# Do platform-specific things.
#
platform="$(uname)"
if [[ "$platform" == 'Linux' ]]; then
    :
elif [[ "$platform" == *'BSD' ]]; then
   if [ -z "$LC_ALL" ]; then
      export LC_ALL="en_US.UTF-8"
   fi
   if [ -z "$LANG" ]; then
      export LANG="en_US.UTF-8"
   fi
   platform="BSD"
elif [[ "$platform" == 'Darwin' ]]; then
   :
else
   platform="unrecognized"
fi
#
# Activate the virtual environment if necessary.
#
in_venv=0
if [ -x "${bin_dir}/conda" ]; then
    # Running Anaconda python.  Check to see if the virtual environment
    # is already active.  If not, find the name of the virtual environment
    # corresponding to the installation directory and "source activate" it
    # before running COMMAND.
   venv_type="conda"
   active_env="$(${bin_dir}/conda env list | grep \* | awk '{print $3}')"
   active_env_name="$(${bin_dir}/conda env list | grep \* | awk '{print $1}')"
   if [ "$active_env" == "${!PKG_ROOT}" ]; then # already in environment
        in_venv=1
        if [ -z "$CONDA_DEFAULT_ENV" ] ; then
           venv_name="$active_env_name"
        else
           venv_name="$CONDA_DEFAULT_ENV"
        fi
   else
      # conda venv needs activation
      environments="$(${bin_dir}/conda env list | grep -v \# | grep -v \*)"
      while read -r envline; do
         env_path="$(echo ${envline} | awk '{print $2}')"
         env_name="$(echo ${envline} | awk '{print $1}')"
         if [ "$env_path" == "${!PKG_ROOT}" ]; then
            venv_name="$env_name"
            break
         fi
      done <<< "$environments"
      if [ -z "$venv_name" ] ; then
        trap - EXIT
        echo "ERROR -- conda virtual environment not properly configured"
        exit 1
      fi
      source activate ${venv_name}
   fi
else
    # Not Anaconda python, check to see if the environment is a virtual one.
    # If not and if "activate" script is found in the directory with this
    # script, source the activate script.
    venv_type="normal"
    real_prefix="$(${bin_dir}/${pkg}_python -c 'import sys; print(hasattr(sys, "real_prefix"))')"
    if [ "$real_prefix" == "True" ]; then # in a venv already
        in_venv=1
    else
       # Check if we need to activate the virtual environment.
       if [ -x ${bin_dir}/activate ]; then
          in_venv=1
          venv_name="${!PKG_ROOT}"
          source ${bin_dir}/activate
       fi
    fi
fi
#
# If environment python's binary directory and $bin_dir are not in the path,
# prepend them.
#
sys_bin_dir="$(${bin_dir}/${pkg}_python -c 'import os,sys; print(os.path.dirname(sys.executable))')"
if [[ ":$PATH:" != *"${sys_bin_dir}:"* ]]; then
    export PATH="${sys_bin_dir}:${PATH}"
fi
if [[ ":$PATH:" != *"${bin_dir}:"* ]]; then
    export PATH="${bin_dir}:${PATH}"
fi
#
# Get printable information for environment.
#
if [ "$in_venv" -eq 1 ]; then
  environ="${venv_type} ${venv_name} virtual environment"
else
  environ="${pkg} real environment"
fi
#
# In proper environment now, exec command(s).
#
if [ "$_I" -eq 1 ]; then
   echo "Executing commands in ${environ}, control-D to exit."
   trap - EXIT
   set +e
   PS1="${script_name}> " bash
   echo ""
elif [ "${command[0]}" == "start" ]; then
   start_server ${command[*]}
elif [ "${command[0]}" == "stop" ]; then
   trap - EXIT
   set +e
   stop_server ${command[*]}
else
   if [ "$_V" -eq 1 ]; then
      echo "Executing \"${command[*]}\" in ${environ}."
   fi
      trap - EXIT
      set +e
      ${command[*]}
fi