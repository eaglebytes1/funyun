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
sudo cp ${FNY_ROOT}/etc/rc.d/funyun /etc/rc.d/funyun
sudo chmod 555 /etc/rc.d/funyun
sudo cp ${FNY_ROOT}/etc/conf.d/funyun /etc/conf.d/funyun
sudo chmod 555 /etc/rc.d/funyun
echo "starting service..."
sudo service funyun start
echo "Stopping the service..."
sudo service funyun stop
trap - EXIT
