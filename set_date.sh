#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

echo "Setting time on remote device"
ssh $WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST date -s \"`date -u --rfc-3339=seconds`\"

