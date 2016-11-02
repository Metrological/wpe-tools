#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

# These few lines reorder $@ so that options come first.
TEMP=`getopt -o d:h --long deploy:,help -- "$@"`
if [ $? != 0 ] ; then echo "Problem parsing options" >&2 ; exit 1 ; fi
eval set -- "$TEMP"


DEPLOY=false
while true ; do
    case "$1" in
        -d|--deploy) DEPLOY=$2 ; shift 2 ;;
        -h|--help) echo "syntax: $0 [-d <nfs|sdcard|ssh>] [-h] [make options]" ; exit 0;;
        --) shift ; break ;;
        *) echo "unknown option: $1" ; exit 1 ;;
    esac
done

pushd "$WPET_BUILDROOT"
make O="$WPET_OUTPUT_NAME" $@ all |& tee -a "$WPET_OUTPUT_NAME.build.log" || exit
popd

if [ x"$DEPLOY" == x"nfs" ]; then
    sudo $WPET_TOOLS/deploy.sh --nfs
elif [ x"$DEPLOY" == x"sdcard" ]; then
    sudo $WPET_TOOLS/deploy.sh --sdcard
elif [ x"$DEPLOY" == x"ssh" ]; then
    $WPET_TOOLS/deploy.sh --ssh
fi
