#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

output_dir=$1
shift

mkdir -p "$output_dir"

ssh -p $WPET_REMOTE_SSH_PORT "$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST" "run_sunspider(){ cd /tests/SunSpider; ./sunspider --shell=/usr/bin/jsc --suite=sunspider-1.0.2 --output auto-sunspider.js --args $@; }; run_sunspider" > "$output_dir/summary.log" 2>&1

scp -P $WPET_REMOTE_SSH_PORT "$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST:/tests/SunSpider/auto-sunspider.js" "$output_dir/"
