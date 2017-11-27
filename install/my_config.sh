#!/usr/bin/env bash
#
# These defs are for use on a development instance.
#
${root}/bin/funyun_env funyun config user_config_path ~/.funyun
${root}/bin/funyun_env funyun config secret_key $FNY_SECRET_KEY
${root}/bin/funyun_env funyun config rc_verbose True
${root}/bin/funyun_env funyun config host $FNY_IP
${root}/bin/funyun_env funyun config nginx_server_name $FNY_HOSTNAME
${root}/bin/funyun_env funyun config supervisord_start_nginx False
${root}/bin/funyun_env funyun config sentry_dsn $FNY_SENTRY_DSN