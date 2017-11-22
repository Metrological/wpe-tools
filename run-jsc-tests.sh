#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi
echo foo
JSCTEST_timeout=1200 $WPET_WPE_BUILD/Tools/Scripts/run-javascriptcore-tests \
    --no-build --no-fail-fast --json-output=jsc_results.json --release \
    --memory-limited --jsc-only \
    --remote=$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST \
	--env-vars TZ='PST8PD' \
    $@ \
	|& tee jsc-tests.log

