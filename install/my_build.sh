#!/usr/bin/env bash
./funyun_tool config root_dir ${FNY_ROOT}
./funyun_tool config var_dir ${FNY_VAR}
./funyun_tool config tmp_dir ${FNY_TMP}
./funyun_tool config log_dir ${FNY_LOG}
./funyun_tool config python system
./funyun_tool config nginx system
./funyun_tool config prometheus system
./funyun_tool config alertmanager system
./funyun_tool config nodeexporter system
./funyun_tool config pushgateway system