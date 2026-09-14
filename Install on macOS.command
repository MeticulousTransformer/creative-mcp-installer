#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
log_dir="$HOME/.creative-mcps/logs"
mkdir -p "$log_dir" || exit 1
log_file="$log_dir/install-$(date +%Y%m%d-%H%M%S).log"
bash ./install-mcps.sh "$@" 2>&1 | tee "$log_file"
result=${PIPESTATUS[0]}
printf '\nInstallation log: %s\n' "$log_file"
if [ -t 0 ]; then read -r -p 'Press Enter to close this installer.' answer; fi
exit "$result"
