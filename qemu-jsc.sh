#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

export LANG=C

declare -a QEMU_ARGS
while true; do
    case "$1" in
        --) shift; break;;
        "") break;;
        *) QEMU_ARGS+=("$1"); shift;;
    esac
done

echo ${WPET_QEMU} -L ${WPET_OUTPUT}/staging ${QEMU_ARGS[@]} -- ${WPET_OUTPUT}/staging/usr/bin/jsc $@
${WPET_QEMU} -L ${WPET_OUTPUT}/staging ${QEMU_ARGS[@]} -- ${WPET_OUTPUT}/staging/usr/bin/jsc $@
