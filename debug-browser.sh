#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

# These few lines reorder $@ so that options come first.
TEMP=`getopt -o ja:h --long jsc,attach,help -- "$@"`
if [ $? != 0 ] ; then echo "Problem parsing options" >&2 ; exit 1 ; fi
eval set -- "$TEMP"

WPET_DEBUG_PROGRAM=WPELauncher
WPET_DEBUG_ATTACH=WPEWebProcess

DEPLOY=false
while true ; do
    case "$1" in
        -j|--jsc) WPET_DEBUG_PROGRAM=jsc; WPET_DEBUG_ATTACH=; shift;;
        -a|--attach) WPET_DEBUG_ATTACH=$2; shift 2;;
        -h|--help) echo "syntax: $0 [-j|--jsc] [-a|--attach <prog_name>] [-h|--help]" ; exit 0;; # FIXME
        --) shift ; break ;;
    esac
done

export WPET_DEBUG_PROGRAM
export WPET_DEBUG_PROGRAM_PATH=/usr/bin/$WPET_DEBUG_PROGRAM

echo ">>> starting program on remote host"

if [ x"$WPET_DEBUG_ATTACH" != x"" ]; then
    ssh -p $WPET_REMOTE_SSH_PORT "$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST" "run_wpe(){  $WPET_DEBUG_PROGRAM_PATH $@ "' & sleep 2; gdbserver --attach 0.0.0.0:2345 `pidof '$WPET_DEBUG_ATTACH'` ; }; run_wpe' > run-wpe.log 2>&1 &

    echo ">>> waiting 2 seconds"
    sleep 2
else
    ssh -p $WPET_REMOTE_SSH_PORT "$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST" "run_wpe(){ gdbserver 0.0.0.0:2345 $WPET_DEBUG_PROGRAM_PATH $@ ; }; run_wpe" > run-wpe.log 2>&1 &


fi

echo ">>> starting gdb"
PYTHONPATH=$PYTHONPATH:$WPET_OUTPUT/host/usr/share/gcc-$WPET_GCC_VERSION/python/ $WPET_OUTPUT/host/usr/bin/$WPET_PLATFORM-gdb --command=webkit_debug.py
