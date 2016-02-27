#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

echo ">>> starting program on remote host"
ssh -p $WPET_REMOTE_SSH_PORT "$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST" 'run_wpe(){  /usr/bin/WPELauncher & sleep 1; gdbserver --attach 0.0.0.0:2345 `pidof WPEWebProcess` ; }; run_wpe' > run-wpe.log 2>&1 &

echo ">>> waiting 1 second"
sleep 1

echo ">>> starting gdb"
PYTHONPATH=$PYTHONPATH:$WPET_OUTPUT/host/usr/share/gcc-$WPET_GCC_VERSION/python/ $WPET_OUTPUT/host/usr/bin/$WPET_PLATFORM-gdb --command=webkit_debug.py
