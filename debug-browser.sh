#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

# These few lines reorder $@ so that options come first.
TEMP=`getopt -o ja:ntcl:Qh --long jsc,attach:,no-launch,tui,continue,launcher:,qemu,help -- "$@"`
if [ $? != 0 ] ; then echo "Problem parsing options" >&2 ; exit 1 ; fi
eval set -- "$TEMP"

WPET_DEBUG_PROGRAM=/usr/bin/WPELauncher
WPET_DEBUG_ATTACH=WPEWebProcess

GDB_OPTS="-q --command=webkit_debug-$WPET_PORT.py"

DEPLOY=false
while true ; do
    case "$1" in
        -j|--jsc) WPET_DEBUG_PROGRAM=/usr/bin/jsc; WPET_DEBUG_ATTACH=; shift;;
        -a|--attach) WPET_DEBUG_ATTACH=$2; shift 2;;
        -n|--no-launch) WPET_DEBUG_PROGRAM=/bin/true; shift;; 
        -t|--tui) GDB_OPTS+=" --tui"; shift;;
        -c|--continue) export WPET_DEBUG_CONTINUE_ON_ATTACH=1; shift;;
        -l|--launcher) WPET_DEBUG_PROGRAM=$2; WPET_DEBUG_ATTACH=; shift 2;;
        -Q|--qemu) WPET_USE_QEMU=1; WPET_DEBUG_ATTACH=; shift;;
        -h|--help) echo "syntax: $0 [-j|--jsc] [-a|--attach <prog_name>] [-n|--no-launch] [-t|--tui] [-c|--continue] [l|--launcher <launcher>] [-Q|--qemu] [-h|--help]" ; exit 0;; # FIXME
        --) shift ; break ;;
    esac
done

export WPET_DEBUG_PROGRAM

if [ x"$WPET_USE_QEMU" == x"" ]; then
    echo ">>> starting program on remote host"
fi

if [ x"$WPET_DEBUG_ATTACH" != x"" ]; then
    ssh -p $WPET_REMOTE_SSH_PORT "$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST" "run_wpe(){ $WPET_DEBUG_PROGRAM $@ "' & sleep 5; LD_BIND_NOW=1 gdbserver --attach 0.0.0.0:2345 `pidof '"$WPET_DEBUG_ATTACH"'`; }; run_wpe' > run-wpe.log 2>&1 &

elif [ x"$WPET_USE_QEMU" != x"" ]; then
    echo " >>> starting jsc with ${WPET_QEMU}..."
    echo $WPET_QEMU -L ${WPET_OUTPUT}/staging -g 2345 -seed 0 ${WPET_OUTPUT}/staging/${WPET_DEBUG_PROGRAM} $@
    $WPET_QEMU -L ${WPET_OUTPUT}/staging -g 2345 ${WPET_OUTPUT}/staging/${WPET_DEBUG_PROGRAM} $@ > run-wpe.log 2>&1 &
    export WPET_REMOTE_HOST=127.0.0.1
else
    ssh -p $WPET_REMOTE_SSH_PORT "$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST" "run_wpe(){ gdbserver 0.0.0.0:2345 $WPET_DEBUG_PROGRAM $@ ; }; run_wpe" > run-wpe.log 2>&1 &


fi

if [ x"$WPET_USE_QEMU" = x"" ]; then
    echo ">>> waiting for gdbserver..."
    tail -f run-wpe.log | while read LOGLINE
        do
            [[ "${LOGLINE}" == *"Listening on port"* ]] && pkill -P $$ tail
        done
fi


echo ">>> starting gdb"
PYTHONPATH=$PYTHONPATH:$WPET_OUTPUT/host/usr/share/gcc-$WPET_GCC_VERSION/python/ $WPET_OUTPUT/host/usr/bin/$WPET_PLATFORM-gdb $GDB_OPTS 
