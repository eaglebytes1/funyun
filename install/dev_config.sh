#!/usr/bin/env bash
#
# These defs are for use on a development instance.
#
${root}/bin/funyun_env funyun config user_config_path ~/.funyun-dev
${root}/bin/funyun_env funyun config secret_key $FNY_SECRET_KEY
${root}/bin/funyun_env funyun config rc_user $FNY_USER
${root}/bin/funyun_env funyun config rc_group $FNY_GROUP
${root}/bin/funyun_env funyun config rc_verbose True
${root}/bin/funyun_env funyun config host $FNY_DEV_IP
${root}/bin/funyun_env funyun config nginx_server_name $FNY_DEV_HOSTNAME
