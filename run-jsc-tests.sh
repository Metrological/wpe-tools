#!/bin/bash

TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    source "$TOOLS_DIR/config.sh"
fi

if [ ! -d $WPET_WPE_BUILD/WebKitBuild/Release ]; then
    mkdir -p $WPET_WPE_BUILD/WebKitBuild
    ln -s $WPET_WPE_BUILD/build-Release $WPET_WPE_BUILD/WebKitBuild/Release 
fi

if [ ! -d $WPET_WPE_BUILD/LayoutTests ]; then
    echo "Copying LayoutTests..."
    cp -a $WPET_WPE_SOURCE/LayoutTests $WPET_WPE_BUILD/
    echo "done"
fi

TEMP=`getopt -o qh --long qemu,help -- "$@"`
if [ $? != 0 ] ; then echo "Problem parsing options" >&2 ; exit 1 ; fi
eval set -- "$TEMP"

USE_QEMU=no
while true ; do
    case "$1" in
        -q|--qemu) USE_QEMU=yes ; shift ;;
        -h|--help) echo "syntax: $0 [-q|--qemu] [-h] [make options]" ; exit 0;;
        --) shift ; break ;;
        *) echo "unknown option: $1" ; exit 1 ;;
    esac
done


now=`date +'%Y%m%d-%H%M%S'`
rev=`git -C ${WPET_WPE_SOURCE} rev-parse --short HEAD`
branch=`git -C ${WPET_WPE_SOURCE} rev-parse --abbrev-ref HEAD`
if [ x${USE_QEMU} == x"yes" ]; then
    kind="qemu"
else
    kind="remote"
fi

filebase="jsc-tests-${WPET_OUTPUT_NAME}-${kind}-${branch/\//__}-${rev}-${now}"
logfile="$filebase.log"
jsonfile="$filebase.json"
script_options="""
    --no-build --no-fail-fast --json-output=$jsonfile --release \
    --jsc-only \
    --env-vars TZ='America/Los_Angeles' \
    """
if [ x${USE_QEMU} == x"yes" ]; then
    export QEMU_LD_PREFIX=$WPET_OUTPUT/target
else
    script_options+="""
    --memory-limited
    --remote=$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST
    """
fi

JSCTEST_timeout=240 time $WPET_WPE_BUILD/Tools/Scripts/run-javascriptcore-tests \
    $script_options $@ \
	|& tee $logfile

$TOOLS_DIR/checklog.sh $logfile
