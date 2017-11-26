#!/bin/bash
# Build configuration system.
set -e # exit on error
script_name="$(basename "${BASH_SOURCE}")"
pkg="${script_name%_tool}"
PKG="$(echo ${pkg} | tr /a-z/ /A-Z/)"
PKG_BUILD_DIR="${PKG}_BUILD_DIR"
PKG_TEST_DIR="${PKG}_TEST_DIR"
PKG_GIT_DIR="${PKG}_BUILD_FROM_GIT"
if [ -z "${!PKG_BUILD_DIR}" ]; then
   build_dir=~/.${pkg}/build
else
   build_dir="${!PKG_BUILD_DIR}"
fi
build_root_dir="$(dirname $build_dir)"
confdir="${build_dir}/config"
if [ -z "${!PKG_TEST_DIR}" ]; then
   test_dir="${build_root_dir}/test"
else
   test_dir="${!PKG_TEST_DIR}"
fi
version="0.94"
platform="$(uname)"
error_exit() {
   >&2 echo "ERROR--unexpected exit from ${BASH_SOURCE} script at line:"
   >&2 echo "   $BASH_COMMAND"
   >&2 echo "Build directory is \"${build_dir}\"."
   >&2 echo "Test directory is \"${test_dir}\"."
}
trap error_exit EXIT
TOP_DOC="""Builds and installs ${pkg} components.

Usage:
        $script_name COMMAND [COMMAND_OPTIONS]

Commands:
          build - metacommand to build all configured binary packages.
         config - Set/print build-time configuration variables.
  configure_pkg - metacommand to configure the ${pkg} instance.
 create_scripts - creates/updates my_build.sh and my_config.sh customization scripts.
           init - Set system-specific defaults for the build.
        install - Install one or all binary packages.
       link_env - Link the ${pkg}_env file to bin_dir for convenience.
    link_python - Create python and pip links.
      make_dirs - Create needed directories in ${pkg} root directory.
    pip_install - Do pip installations.
           pypi - Get latest pypi version.
          shell - Run a shell in installation environment.
        testify - Run tests.
         update - Updates this script.
        version - Get installed ${pkg} version.

Variables (accessed by \"config\" command):
      alert_manager - The prometheus.io alert_manager version string.
            bin_dir - A writable directory in PATH for script links.
                 cc - The C compiler to use.
  directory_version - ${pkg} version for directory naming purposes.
              nginx - The nginx version string.
      node_exporter - The prometheus.io node_exporter version string.
  node_exporter_sys - The node_exporter platform string.
         prometheus - The prometheus version string.
     prometheus_sys - The prometheus platform string.
        pushgateway - The prometheus.io pushgateway version string.
             python - The python version string.
           root_dir - Path to the root directory.
            version - Installed version.

Environmental variables:
       ${PKG}_BUILD_DIR - The location of the build, configuration, and test
                          files.  If not set, they go in ~/.${pkg}/.
                          The current setting is \"${build_dir}\".
        ${PKG}_TEST_DIR - The location of the test directory.  If not set,
                          they go in ${PKG}_BUILD_DIR/test.
                          The current setting is
                          \"${test_dir}\".

Platforms supported:
   uname must return one of three values, \"Linux\", \"Darwin\",
   or \"*BSD\"; other values are not recognized.  This platform
   is \"$platform\".
"""
#
# Helper functions begin here.
#
set_value() {
   if [ ! -e ${confdir} ]; then
      >&2 echo "Making ${confdir} directory."
      mkdir -p ${confdir}
   fi
   echo "$2" > "${confdir}/${1}"
}
get_value() {
  if [ -e ${confdir}/${1} ]; then
    cat ${confdir}/${1}
  else
    trap - EXIT
    >&2 echo "ERROR--value for $1 variable not found."
    exit 1
  fi
}
#
# Installation functions.
#
install_python() {
   >&1 echo "Installing Python $1 to ${2}."
   curl -L -o Python-${1}.tar.gz  https://www.python.org/ftp/python/${1}/Python-${1}.tar.xz
   tar xf Python-${1}.tar.gz
   rm Python-${1}.tar.gz
   pushd Python-${1}
   ./configure --prefix="${2}" CC="${3}"
   ${4} install
   popd
   rm -r Python-${1}
}
install_nginx() {
   var="$(get_value var_dir)"
   tmp="$(get_value tmp_dir)"
   log="$(get_value log_dir)"
   >&1 echo "Installing nginx $1 to ${2}."
   curl -L -o nginx-${1}.tar.gz http://nginx.org/download/nginx-${1}.tar.gz
   tar xf nginx-${1}.tar.gz
   rm nginx-${1}.tar.gz
   mkdir -p ${2}/etc/nginx
   pushd nginx-${1}
   ./configure --prefix="${2}" \
   --with-threads \
   --with-stream \
   --with-stream=dynamic \
   --with-pcre \
   --with-cc="${3}" \
   --with-http_ssl_module \
   --with-http_v2_module \
   --with-http_auth_request_module \
   --with-http_addition_module \
   --with-http_gzip_static_module \
   --with-http_realip_module \
   --with-http_sub_module \
   --sbin-path=bin \
   --modules-path="${root}/lib/nginx/modules" \
   --conf-path="${root}/etc/nginx/nginx.conf" \
   --error-log-path="${log}/nginx/error.log" \
   --http-log-path="${log}/nginx/access.log" \
   --pid-path="${var}/run/nginx/nginx.pid" \
   --lock-path="${var}/run/nginx/nginx.lock" \
   --http-fastcgi-temp-path="${tmp}/nginx/fastcgi" \
   --http-client-body-temp-path="${tmp}/nginx/client" \
   --http-proxy-temp-path="${tmp}/nginx/proxy" \
   --http-uwsgi-temp-path="${tmp}/nginx/uwsgi" \
   --http-scgi-temp-path="${tmp}/nginx/scgi"
   ${4} install
   rm -f ${root}/etc/nginx/* # remove generated etc files
   rm -rf ${root}/html # and html
   popd
   rm -r nginx-${1}
}
install_prometheus() {
   sys="$(get_value prometheus_sys)"
   >&1 echo "Installing prometheus $1 to ${2}."
   curl -L -o prometheus.tar.gz  http://github.com/prometheus/prometheus/releases/download/v${1}/prometheus-${1}.${sys}-amd64.tar.gz
   tar xf prometheus.tar.gz -C "$2"
   rm prometheus.tar.gz
}
install_alertmanager() {
   sys="$(get_value prometheus_sys)"
   >&1 echo "Installing alertmanager $1 to ${2}."
   curl -L -o alertmanager.tar.gz  http://github.com/prometheus/alertmanager/releases/download/v${1}/alertmanager-${1}.${sys}-amd64.tar.gz
   tar xf alertmanager.tar.gz -C "$2"
   rm alertmanager.tar.gz
}
install_node_exporter() {
   sys="$(get_value node_exporter_sys)"
   >&1 echo "Installing node_exporter $1 to ${2}."
   curl -L -o node_exporter.tar.gz  http://github.com/prometheus/node_exporter/releases/download/v${1}/node_exporter-${1}.${sys}-amd64.tar.gz
   tar xf node_exporter.tar.gz -C "$2"
   rm node_exporter.tar.gz
}
install_pushgateway() {
   sys="$(get_value prometheus_sys)"
   >&1 echo "Installing pushgateway $1 to ${2}."
   curl -L -o pushgateway.tar.gz  http://github.com/prometheus/pushgateway/releases/download/v${1}/pushgateway-${1}.${sys}-amd64.tar.gz
   tar xf pushgateway.tar.gz -C "$2"
   rm pushgateway.tar.gz
}
#
# Command functions begin here.
#
build() {
   BUILD_DOC="""This command downloads, builds, and installs ${pkg} and its dependencies.
It sources the \"my_build.sh\" script after initializaiton to allow customization.
You should stop and edit my_build.sh if you wish to:
   * install ${pkg} to non-default locations
   * use RAxML and your system has AVX or AVX2 hardware

You may run this command with a \"-y\" argument to skip this question.
"""
   if [ "$1" != "-y" ]; then
      >&1 echo "$BUILD_DOC"
      read -p "Do you want to continue? <(y)> " response
      if [ ! -z "$response" ]; then
         if [ "$response" != "y" ]; then
            trap - EXIT
            exit 1
         fi
      fi
   fi
   # Configure the build.
   init
   if [ -e my_build.sh ]; then
      >&1 echo "Sourcing build specifics in my_build.sh."
      source my_build.sh
   else
      >&2 echo "WARNING--my_build.sh not found, using defaults."
   fi
   set_value all
   make_dirs
   # Build the binaries.
   >&1 echo "Doing C/C++ binary installs."
   install
   # The following exports are needed for the freshly-built python to run
   # on BSD (and probably harmless on others).
   if [ -z "$LC_ALL" ]; then
      export LC_ALL="en_US.UTF-8"
   fi
   if [ -z "$LANG" ]; then
      export LANG="en_US.UTF-8"
   fi
   # Do pip installs.
   >&1 echo "Doing python installs."
   link_python    # python and pip links
   pip_install    # Do installs for server and dependencies
   link_env       # put server_env in PATH
   # Test to make sure it runs.
   >&1 echo "Testing ${pkg} binary."
   root="$(get_value root_dir)"
   version > ${root}/version
   >&1 echo "Installation was successful."
   >&1 echo "You should now proceed with configuring ${pkg} via the command"
   >&1 echo "   ./${script_name} configure_pkg"
}
config() {
  CONFIG_DOC="""Sets/displays key/value pairs for the $pkg build system.

Usage:
   $scriptname set KEY [VALUE]

Arguments:
   if KEY is \"all\", all values will be set.
   If VALUE is present, the value will be set.
   If VALUE is absent, the current value will be displayed.
"""
  if [ "$#" -eq 0 ]; then #doc
      trap - EXIT
      >&2 echo "$CONFIG_DOC"
      exit 1
    elif [ "$#" -eq 1 ]; then # get
      if [ "$1" == "all" ]; then
        >&1 echo "Build configuration values for ${pkg}."
        >&1 echo "These values are stored in ${confdir}."
        >&1 echo -e "       key         \t       value"
        >&1 echo -e "-------------------\t------------------"
        for key in $(ls ${confdir}); do
          value="$(get_value ${key})"
        printf '%-20s\t%s\n' ${key} ${value} >&1
      done
    elif [ -e ${confdir}/${1} ]; then
      echo "$(get_value $1)"
    else
      trap - EXIT
      >&2 echo "${1} has not been set."
      exit 1
    fi
  elif [ "$#" -eq 2 ]; then # set
    set_value $1 $2
  else
    trap - EXIT
    >&2 echo "$CONFIG_DOC"
    >&2 echo "ERROR--too many arguments (${#})."
    exit 1
  fi
}
configure_pkg() {
   CONFIGURE_DOC="""This command configures ${pkg} and creates an instance ready to run.
It sources the \"my_config.sh\" script after initializaiton to allow customization.
You should stop and edit my_config.sh if you wish to:
      * serve at a public IP or non-default port
      * use a non-default path for DATA or USERDATA
      * enable monitoring services (crashmail, sentry)

You may run this command with a \"-y\" argument to skip this question.
"""
   if [ "$1" == "-y" ]; then
      shift 1
   else
      >&1 echo "$CONFIGURE_DOC"
      read -p "Do you want to continue? <(y)> " response
      if [ ! -z "$response" ]; then
         if [ "$response" != "y" ]; then
            trap - EXIT
            exit 1
         fi
      fi
   fi
   root="$(get_value root_dir)"
   version="$(get_value directory_version)"
   var_dir="$(get_value var_dir)"
   log_dir="$(get_value log_dir)"
   tmp_dir="$(get_value tmp_dir)"
   if [ "$var_dir" != "${root}/var" ]; then
      >&1 echo "Configuring non-default var directory ${var_dir}."
      ${root}/bin/${pkg}_env ${pkg} config var $var_dir
   fi
   if [ "$log_dir" != "${var_dir}/log" ]; then
      >&1 echo "Configuring non-default log directory ${log_dir}."
      ${root}/bin/${pkg}_env ${pkg} config log $log_dir
   fi
   if [ "$tmp_dir" != "${var_dir}/tmp" ]; then
      >&1 echo "Configuring non-default tmp directory ${tmp_dir}."
      ${root}/bin/${pkg}_env ${pkg} config tmp $tmp_dir
   fi
   if [ -e my_config.sh ]; then
      >&1 echo "Sourcing configuration specifics in my_config.sh."
      source my_config.sh
   else
      >&2 echo "WARNING--my_config.sh not found, using defaults."
   fi
   # Save a copy of the configuration to a time-stamped file.
   config_filename="${pkg}_config-$(date '+%Y-%m-%d-%H-%M').txt"
   ${root}/bin/${pkg}_env ${pkg} config > ${confdir}/${config_filename}
   # Create the configured instance.
   >&1 echo "Creating a configured instance at ${root}."
   if [ "$#" -ne 0 ]; then
      >&1 echo "Using additional arguments to create_instance \"$@\"."
   fi
   ${root}/bin/${pkg}_env ${pkg} create_instance --force $@
   # Set the password for restricted parts of the site.
   passwd="$(${root}/bin/${pkg}_env ${pkg} config secret_key)"
   >&1 echo "Setting the http password to \"${passwd}\";"
   >&1 echo "please write it down, because you will need it to access some services."
   ${root}/bin/${pkg}_env ${pkg} set_htpasswd --force
   >&1 echo "To run the test suite, issue the command:"
   >&1 echo "   ./${script_name} testify"
}
create_scripts() {
(
cat << 'EOF'
#
# ${pkg}_tool init configures the following default values, which you may
# override by uncommenting here.  These default values are for a linux
# build and may be different then the values created by ${pkg}_tools init
# command.
#
# Note that if you are building nginx, some of these configuration values
# are compile-time-only settings which cannot be overridden.
#
#./${pkg}_tool config directory_version 0.94
#./${pkg}_tool config root_dir "~/.${pkg}/$(./${pkg}_tool config directory_version)"
#./${pkg}_tool config var_dir "$(./${pkg}_tool config root_dir)/var"
#./${pkg}_tool config tmp_dir "$(./${pkg}_tool config var_dir)/tmp"
#./${pkg}_tool config log_dir "$(./${pkg}_tool config var_dir)/log"
#
# Version numbers of packages.  Setting these to "system" will cause them
# not to be built.
#
#./${pkg}_tool config python 3.6.3
#./${pkg}_tool config nginx 1.13.7
#./${pkg}_tool config prometheus 2.0.0
#./${pkg}_tool config alertmanager 0.11.0
#./${pkg}_tool config node_exporter 0.15.1
#./${pkg}_tool config pushgateway 0.4.0
#
# The following defaults are platform-specific.  Linux defaults are shown.
#
#./${pkg}_tool config platform linux
#./${pkg}_tool config bin_dir ~/bin  # dir in PATH where ${pkg}_env is symlinked
#./${pkg}_tool config make make
#./${pkg}_tool config cc gcc
#./${pkg}_tool config redis_cflags ""
#./${pkg}_tool config prometheus_sys linux
#./${pkg}_tool config node_exporter_sys linux
#
EOF
) > build_example.sh.new

(
cat <<'EOF'
#
# This file is sourced after ${pkg}_tool configure_pkg does initializations,
# including picking up non-default values from the build configuration for
# root_dir, var_dir, tmp_dir, and log_dir.
#
# The customizations below are the main ones needed to configure a
# server at non-default locations.  Uncomment and edit as needed.
# Values shown are not defaults, but rather example values.
#
#version="0.94"
#${root}/bin/${pkg}_env ${pkg} config user_config_path ~/.funyun
#${root}/bin/${pkg}_env ${pkg} config secret_key mysecret
#${root}/bin/${pkg}_env ${pkg} config data /usr/local/www/data/${pkg}/${version}
#${root}/bin/${pkg}_env ${pkg} config userdata /persist/${pkg}/${version}
#${root}/bin/${pkg}_env ${pkg} config host 127.0.0.1
#${root}/bin/${pkg}_env ${pkg} config rc_user www
#${root}/bin/${pkg}_env ${pkg} config rc_group www
#${root}/bin/${pkg}_env ${pkg} config rc_verbose True
#${root}/bin/${pkg}_env ${pkg} config nginx_server_name mywebsite.org
#${root}/bin/${pkg}_env ${pkg} config port 58927
#${root}/bin/${pkg}_env ${pkg} config sentry_dsn https://MYDSN@sentry.io/${pkg}
#${root}/bin/${pkg}_env ${pkg} config crashmail_email user@example.com
EOF
) > config_example.sh.new
   # Check for updates to other files, in an edit-aware way.
   for f in build_example.sh config_example.sh; do
      if [ -e ${f} ]; then
         if cmp -s ${f} ${f}.new; then
            rm ${f}.new # no change
         else
           >&1 echo "$f has been updated."
           mv ${f} ${f}.old
           chmod 755 ${f}.new
           mv ${f}.new ${f}
         fi
      else
         chmod 755 ${f}.new
         mv ${f}.new ${f}
      fi
   # If my_ files have changed versus example, warn but do not replace.
     my_f="my_${f/_example/}"
     if [ -e ${f}.old ]; then
        cmp_f="${f}.old" # look for changes against old file
     else
        cmp_f="$f"       # look for changes against current file
     fi
     if [ -e ${my_f} ]; then
       if cmp -s ${cmp_f} ${my_f}; then
          if [ -e ${f}.old ]; then
            # No changes from old example, copy current file to my_f.
            cp ${f} ${my_f}
          fi
       else
          if [ -e ${f}.old ]; then
            mv ${f}.old ${f}.save
            >&1 echo "Example file on which your edited ${my_f} was based has changed."
            >&1 echo "Review the following differences between ${f} and ${f}.save"
            >&1 echo "and apply them, if necessary to ${my_f}:"
            set +e
            diff -u ${f}.save ${f}
          else
            >&1 echo "${my_f} differs from the (unchanged) example file."
          fi
       fi
       else
       cp ${f} ${my_f}
     fi
   done
   rm -f $build_example.sh.old config_example.sh.old
}
init() {
   #
   #  Initialize build parameters.
   #
   set_value root_dir ${build_root_dir}/${version}
   set_value directory_version ${version}
   set_value var_dir "$(get_value root_dir)/var"
   set_value tmp_dir "$(get_value var_dir)/tmp"
   set_value log_dir "$(get_value var_dir)/log"
   set_value python 3.6.3
   set_value nginx 1.13.7
   set_value prometheus 2.0.0
   set_value alertmanager 0.11.0
   set_value node_exporter 0.15.1
   set_value pushgateway 0.4.0
   if [[ "$platform" == "Linux" ]]; then
      >&1 echo "Platform is linux."
      set_value bin_dir ~/bin
      set_value platform linux
      set_value make make
      set_value cc gcc
      set_value prometheus_sys linux
      set_value node_exporter_sys linux
   elif [[ "$platform" == *"BSD" ]]; then
      >&1 echo "Platform is bsd."
      set_value platform bsd
      set_value bin_dir ~/bin
      set_value make gmake
      set_value cc clang
      set_value prometheus_sys freebsd
      set_value node_exporter_sys netbsd
   elif [[ "$platform" == "Darwin" ]]; then
      >&2 echo "Platform is mac.  Warning: You must have XCODE installed."
      set_value platform mac
      set_value bin_dir /usr/local/bin
      set_value make make
      set_value cc clang
      set_value prometheus_sys darwin
      set_value node_exporter_sys darwin
   else
      >&2 echo "WARNING--Unknown platform ${platform}, pretending it is linux."
      set_value platform linux
      set_value bin_dir ~/bin
      set_value make make
      set_value cc gcc
      set_value prometheus_sys linux
      set_value node_exporter_sys linux
   fi
}
install() {
  INSTALL_DOC="""Installs a binary package.

Usage:
   $scriptname install PACKAGE

Packages:
  alertmanager - prometheus.io alert manager.
         nginx - nginx web proxy server.
 node_exporter - prometheus.io node statistics exporter.
    prometheus - prometheus.io statistics server.
   pushgateway - prometheus.io push gateway.
        python - Python interpreter.
"""
  root=$(get_value root_dir)
  cc="$(get_value cc)"
  make="$(get_value make)"
  commandlist="python nginx prometheus alertmanager node_exporter pushgateway"
  if [ "$#" -eq 0 ]; then # install the whole list
      for package in $commandlist; do
         version="$(get_value $package)"
         if [ "$version" == "system" ]; then
           >&1 echo "System version of $package will be used, skipping build."
         else
           install_$package ${version} ${root} ${cc} ${make}
         fi
      done
  else
     case $commandlist in
        *"$1"*)
           install_$1 $(get_value $1) ${root} ${cc} ${make}
        ;;
        $commandlist)
          trap - EXIT
          cat "$INSTALL_DOC"
          >&2 echo  "ERROR--unrecognized package $1"
          exit 1
        ;;
      esac
   fi
}
link_env() {
   #
   # Link the _env script to $bin_dir.
   #
   root="$(get_value root_dir)"
   bin_dir="$(get_value bin_dir)"
   >&1 echo "linking ${pkg}_env to ${bin_dir}"
   if [ ! -e ${bin_dir} ]; then
     >&1 echo "Creating binary directory at ${bin_dir}"
     >&1 echo "Make sure it is on your PATH."
     mkdir ${bin_dir}
   elif [ -h ${bin_dir}/${pkg}_env ]; then
     rm -f ${bin_dir}/${pkg}_env
   fi
   ln -s  ${root}/bin/${pkg}_env ${bin_dir}
}
make_dirs() {
   #
   # Make required build-time directories.
   #
   root="$(get_value root_dir)"
   dirlist=("${root}/bin"
            "${root}/etc/nginx")
   for dir in "${dirlist[@]}" ; do
      if [ ! -e "$dir" ]; then
         >&1 echo "making directory $dir"
         mkdir -p $dir
      else
         >&1 echo "directory $dir already exists"
      fi
   done
}
link_python() {
   root="$(get_value root_dir)"
   root_bin="${root}/bin"
   python_version="$(get_value python)"
   cd $root_bin
   if [ ! -e python ]; then
      >&1 echo "creating python ${python_version} link in ${root_bin}."
      ln -s python${python_version%.*} python
   fi
   if [ ! -e pip ]; then
      >&1 echo "creating pip link in ${root_bin}."
      ln -s pip${python_version%%.*} pip
   fi
}
pip_install() {
   #
   # Do pip installations for package.
   #
   root="$(get_value root_dir)"
   if [[ ":$PATH:" != *"${root}:"* ]]; then
      export PATH="${root}/bin:${PATH}"
   fi
   cd $root # src/ directory is left behind by git
   pip install -U setuptools # This one is needed for parsing setup.cfg
   pip install -U setuptools-scm # This one is needed to work behind proxy
   pip install -U packaging  # Ditto on proxy
   pip install -e 'git+https://github.com/LegumeFederation/supervisor.git@4.0.0#egg=supervisor==4.0.0'
   if [ -z ${!PKG_GIT_DIR} ]; then
     cd ${!PKG_GIT_DIR}
     pip install .
   else
      pip install -U ${pkg}
   fi
   pkg_env_path="${root}/bin/${pkg}_env"
   pkg_version="$(${pkg_env_path} ${pkg} config version)"
   set_value version $pkg_version
   >&1 echo "${pkg} version $pkg_version is now installed."
}
pip_upgrade() {
   #
   # Upgrade an existing installation.
   #
   root="$(get_value root_dir)"
   if [[ ":$PATH:" != *"${root}:"* ]]; then
      export PATH="${root}/bin:${PATH}"
   fi
   cd $root # src/ directory is left behind by git
   pip install -U setuptools
   pip install -e 'git+https://github.com/LegumeFederation/supervisor.git@4.0.0#egg=supervisor==4.0.0'
   pip install -U ${pkg}
   pkg_env_path="${root}/bin/${pkg}_env"
   pkg_version="$(${pkg_env_path} ${pkg} config version)"
   set_value version $pkg_version
   >&1 echo "${pkg} version $pkg_version is now installed."
}
pypi() {
  #
  # Get the current pypi package version.
  #
  set +e
  trap - EXIT
  #
  # The piped function below does version sorting using only awk.
  #
  simple_url="https://pypi.python.org/simple/${pkg}"
  latest="$(curl -L -s ${simple_url} |\
          grep tar.gz |\
          sed -e "s/.*${pkg}-//g" -e 's#.tar.gz</a><br/>##g'|\
          awk -F. '{ printf("%03d%03d%03d\n", $1, $2, $3); }'|\
          sort -g |\
          awk '{printf("%d.%d.%d\n", substr($0,0,3),substr($0,4,3),substr($0,7,3))}'|\
          tail -1)"
   if [ "$?" -eq 0 ]; then
     echo "$latest"
   else
     echo "Unable to determine latest pypi version".
     exit 1
   fi
}
shell() {
   #
   # Execute in build environment.
   #
   root="$(get_value root_dir)"
   export PATH="${root}/bin:${PATH}"
   trap - EXIT
   set +e
   old_prompt="$PS1"
   pushd $root 2&>/dev/null
   >&1 echo "Executing commands in ${root} with ${root}/bin in path, control-D to exit."
   export PS1="${script_name}> "
   bash
   popd 2&>/dev/null
   export PS1="$old_prompt"
}
testify() {
   TEST_DOC="""You are about to run a short test of the ${pkg} installation
in the ${test_dir} directory.
Testing should take about 2 minutes on modest hardware.
Interrupt this script if you do not wish to test at this time.
"""
   set +e
   if [ "$1" != "-y" ]; then
      >&1 echo "$TEST_DOC"
      read -p "Do you want to continue? <(y)> " response
      if [ ! -z "$response" ]; then
         if [ "$response" != "y" ]; then
            exit 1
         fi
      fi
   fi
   set -e
   root="$(get_value root_dir)"
   >&1 echo "Running ${pkg} processes."
   ${root}/bin/${pkg}_env -v start
   # Create the test directory and cd to it.
   mkdir -p ${test_dir}
   pushd ${test_dir}
   >&1 echo "Getting a set of test files in the ${test_dir} directory."
   ${root}/bin/${pkg}_env ${pkg} create_test_files --force
   >&1 echo "Running test of ${pkg} server."
   ./test_targets.sh
   >&1 echo ""
   popd
   # Clean up.  Note that server process doesn't stop properly from
   # shutdown alone across all platforms.
   >&1 echo "Stopping ${pkg} processes."
   ${root}/bin/${pkg}_env stop
   >&1 echo "Tests completed successfully."
}
update() {
   #
   # Updates self.
   #
   if [ -z "${!PKG_BUILD_FROM_GIT}" ]; then
      git pull
      newversion="$(pypi)"
    else
       rawsite="https://raw.githubusercontent.com/LegumeFederation/${pkg}/master/build_scripts"
       printf "Checking for self-update..."
       curl -L -s -o ${pkg}_tool.new ${rawsite}/${pkg}_tool.sh
       chmod 755 ${pkg}_tool.new
       if cmp -s ${pkg}_tool ${pkg}_tool.new ; then
          rm ${pkg}_tool.new
          >&1 echo "not needed." >&1
       else
          mv ${pkg}_tool.new ${pkg}_tool
                >&2 echo "This script was updated. Please re-build ${pkg} using"
          if [ -e my_build.sh ] ; then
             >&2 echo "   ./${script_name} create_scripts"
             >&2 echo "and"
          fi
          >&2 echo "    ./${script_name} build"
       fi
       newversion=$(awk -F"'" '/^version/ {print $2 }' ${build_root_dir}/funyun/version)
   fi
   version="$(version)"
   if [ "${version}" == "${pkg} build not configured" ]; then
      >&1 echo "Next run \"./${script_name} build\" to build and configure ${pkg}."
   elif [ "$newversion" == "$version" ]; then
      >&1 echo "The latest version of ${pkg} (${pypi}) is installed, no need for updates."
   else
      >&1 echo "You can update from installed version (${version}) to latest (${newversion}) with"
      >&1 echo "   ./${script_name} pip_install"
   fi
}
version() {
  #
  # Get installed version.
  #
   set +e
   trap - EXIT
   if [ -e ${confdir}/root_dir ]; then
    root="$(cat ${confdir}/root_dir)"
      pkg_env_path="${root}/bin/${pkg}_env"
      if [ -e $pkg_env_path ]; then
         echo "$(${pkg_env_path} ${pkg} config version)"
      else
         >&2 echo "${pkg} package not installed"
         exit 0
      fi
  else
    >&2 echo "${pkg} build not configured"
    exit 0
   fi
}
#
# Command-line interpreter.
#
if [ "$#" -eq 0 ]; then
   trap - EXIT
   >&2 echo "$TOP_DOC"
   exit 1
fi
command="$1"
shift 1
case $command in
"build")
  build $@
  ;;
"config")
  config $@
  ;;
"configure_pkg")
  configure_pkg $@
  ;;
"create_scripts")
  create_scripts $@
  ;;
"init")
   init $@
   ;;
"install")
  install $@
  ;;
"link_env")
   link_env $@
   ;;
"make_dirs")
   make_dirs $@
   ;;
"link_python")
   link_python $@
   ;;
"pip_install")
   pip_install $@
   ;;
"pypi")
  pypi $@
  ;;
"shell")
   shell $@
   ;;
"testify")
   testify $@
   ;;
"update")
  update $@
  ;;
"version")
   version $@
   ;;
*)
  trap - EXIT
  >&2 echo "ERROR--command $command not recognized."
  exit 1
  ;;
esac
trap - EXIT
exit 0
