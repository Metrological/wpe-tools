#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

# These few lines reorder $@ so that options come first.
TEMP=`getopt -o d --long deploy -- "$@"`
if [ $? != 0 ] ; then echo "Problem parsing options" >&2 ; exit 1 ; fi
eval set -- "$TEMP"


DEPLOY=false
while true ; do
    case "$1" in
        -d|--deploy) DEPLOY=true ; shift ;;
        --) shift ; break ;;
        *) echo "unknown option: $1" ; exit 1 ;;
    esac
done

pushd "$WPET_BUILDROOT"
make O="$WPET_OUTPUT_NAME" $@ all |& tee -a "$WPET_OUTPUT_NAME.build.log" || exit
popd

if [ x"$DEPLOY" == x"true" ]; then
    $WPET_TOOLS/deploy.sh
fi
