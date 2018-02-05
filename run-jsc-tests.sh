#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

now=`date +'%Y%m%d-%H%M%S'`
filebase="jsc-tests-$WPET_OUTPUT_NAME-$now"
logfile="$filebase.log"
jsonfile="$filebase.json"
JSCTEST_timeout=1200 $WPET_WPE_BUILD/Tools/Scripts/run-javascriptcore-tests \
    --no-build --no-fail-fast --json-output=$jsonfile --release \
    --memory-limited --jsc-only \
    --remote=$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST \
    --env-vars TZ='America/Los_Angeles' \
    $@ \
	|& tee $logfile

