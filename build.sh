#!/bin/bash

if [ $EUID -eq 0 ]; then
    echo "It's a *bad* idea to build as root! Not allowing it."
    exit 1
fi


if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

export LANG=C

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
set -o pipefail
rm -f "$WPET_BASE/last.build.log"
echo make O="$WPET_OUTPUT_NAME" $@ all
make O="$WPET_OUTPUT_NAME" $@ all |& tee "$WPET_BASE/last.build.log" -a "$WPET_OUTPUT_NAME.build.log" || exit 1
set +o pipefail
popd

if [ x"$DEPLOY" == x"nfs" ]; then
    sudo $WPET_TOOLS/deploy.sh --nfs
elif [ x"$DEPLOY" == x"sdcard" ]; then
    sudo $WPET_TOOLS/deploy.sh --sdcard
elif [ x"$DEPLOY" == x"ssh" ]; then
    $WPET_TOOLS/deploy.sh --ssh
fi
