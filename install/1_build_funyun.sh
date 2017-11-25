#!/usr/bin/env bash
#
# starting from clean empty directory
#
set -e
if [ -z "$FUNYUN_BUILD_DIR" ]; then
   echo "You must source the defs script first."
   exit 1
fi
mkdir -p $FUNYUN_BUILD_DIR
cd $FUNYUN_BUILD_DIR
ln -s ${FNY_ROOT}/../install/funyun_tool.sh funyun_tool
chmod 755 funyun_tool
ln -s ${FNY_SCRIPT_DIR}/my_build.sh .
ln -s ${FNY_SCRIPT_DIR}/my_config.sh .
./funyun_tool build -y
./funyun_tool configure_pkg -y
./funyun_tool testify -y
echo "If you see this line, you can be quite sure that funyun is properly installed as ${FNY_INSTALLER}."
