#!/usr/bin/env bash
set -e
error_exit() {
  >&2 echo "ERROR--unexpected exit from ${BASH_SOURCE} script at line:"
  >&2 echo "   $BASH_COMMAND"
  >&2 echo "This failure may have left a running server instance."
  >&2 echo "You should stop it with the command"
  >&2 echo "   \"sudo service funyun stop\"."
}
trap error_exit EXIT
sudo cp ${FNY_ROOT}/etc/rc.d/funyun /etc/rc.d/init.d/funyun
sudo chmod 555 /etc/rc.d/init.d/funyun
sudo chown root:root /etc/rc.d/init.d/funyun
sudo cp ${FNY_ROOT}/etc/conf.d/funyun /etc/sysconfig/funyun
sudo chmod 555 /etc/sysconfig/funyun
sudo chown root:root /etc/sysconfig/funyun
echo "enabling service.."
sudo chkconfig --add funyun
echo "starting service..."
sudo service funyun start
echo "restarting service..."
sudo service funyun restart
echo "stopping service..."
sudo service funyun stop
trap - EXIT
