#!/usr/bin/env bash
# 파일명: debug_cores.sh

source "/home/pangui/scripts/retropangui/retropangui_setup.sh"

source "/home/pangui/scripts/retropangui/scriptmodules/install_base_4_in_5_cores.sh"

install_base_cores || exit 1
