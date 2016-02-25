#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

echo "Deploying build in $WPET_OUTPUT to $WPET_NFS and $WPET_TFTPBOOT"

sudo rm -rf "$WPET_NFS"/*
sudo tar xf "$WPET_OUTPUT/images/rootfs.tar" -C "$WPET_NFS"
cp "$WPET_OUTPUT/images/vmlinux" "$WPET_TFTPBOOT"
