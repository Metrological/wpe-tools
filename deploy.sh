#!/bin/bash

# check for root
if [ $EUID -ne 0 ]; then
    echo "This script needs to be run with root privilege"
    exit 1
fi

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

# These few lines reorder $@ so that options come first.
TEMP=`getopt -o nsr:b:h --long nfs,sdcard,root:,boot:,help -- "$@"`
if [ $? != 0 ] ; then echo "Problem parsing options" >&2 ; exit 1 ; fi
eval set -- "$TEMP"


DEPLOY_METHOD=
BOOT_DEVICE=
ROOT_DEVICE=

while true ; do
    case "$1" in
        -n|--nfs) DEPLOY_METHOD=nfs ; shift ;;
        -s|--sdcard) DEPLOY_METHOD=sdcard ; shift ;;
        -b|--boot) BOOT_DEVICE=$2 ; shift 2 ;;
        -r|--root) ROOT_DEVICE=$2 ; shift 2 ;;
        -h|--help) echo "syntax: $0 [-n|--nfs] [-s|--sdcard] [-h]" ; exit 0;;
        --) shift ; break ;;
        *) echo "unknown option: $1" ; exit 1 ;;
    esac
done

function set_devices(){
    if [ x"$ROOT_DEVICE" == x"" ]; then
        ROOT_DEVICE=`blkid -c /dev/null -L wpetrootfs`
    fi

    if [ x"$BOOT_DEVICE" == x"" ]; then
        BOOT_DEVICE=`blkid -c /dev/null -L wpetboot`
    fi


    if [ ! -b "$BOOT_DEVICE" ]; then
        echo "invalid boot device $BOOT_DEVICE"
        exit 1
    fi

    if [ ! -b "$ROOT_DEVICE" ]; then
        echo "invalid root device $ROOT_DEVICE"
        exit 1
    fi
}

function check_mount_dirs(){
    if [ ! -d "$WPET_BOOT_MOUNT" ]; then
        echo "error: $WPET_BOOT_MOUNT does not exist"
        exit 1
    fi
    if [ ! -d "$WPET_ROOT_MOUNT" ]; then
        echo "error: $WPET_ROOT_MOUNT does not exist"
        exit 1
    fi
}

function check_output(){
    if [ ! -d "$WPET_OUTPUT/images" ]; then
        echo "Cannot find $WPET_OUTPUT/images"
        exit 1
    fi
}

if [ x$DEPLOY_METHOD == x"nfs" ]; then
    echo "Deploying build in $WPET_OUTPUT to $WPET_NFS and $WPET_TFTPBOOT"

    rm -rf "$WPET_NFS"/*
    tar xf "$WPET_OUTPUT/images/rootfs.tar" -C "$WPET_NFS"
    cp "$WPET_OUTPUT/images/vmlinux" "$WPET_TFTPBOOT"

elif [ x$DEPLOY_METHOD == x"sdcard" ]; then
    set_devices
    check_mount_dirs
    check_output

    echo "formatting boot partition $BOOT_DEVICE"
    mkfs.vfat -F 32 -n wpetboot "$BOOT_DEVICE"
    echo "formatting root partition $ROOT_DEVICE"
    mkfs.ext4 -L wpetrootfs "$ROOT_DEVICE"

    echo "copying boot files"
    mount "$BOOT_DEVICE" "$WPET_BOOT_MOUNT"
    cp "$WPET_OUTPUT/images/rpi-firmware/"* "$WPET_BOOT_MOUNT"
    cp "$WPET_OUTPUT/images/zImage" "$WPET_BOOT_MOUNT"
    umount "$WPET_BOOT_MOUNT"

    echo "copying root files"
    mount "$ROOT_DEVICE" "$WPET_ROOT_MOUNT"
    tar -xvpsf "$WPET_OUTPUT/images/rootfs.tar" -C "$WPET_ROOT_MOUNT"
    umount "$WPET_ROOT_MOUNT"

    echo "syncing"
    sync

    echo "all done!"

else
    echo "No deploy method specified! You need to choose between nfs (-n/--nfs) and sdcard (-s/--sdcard)"
    exit 1
fi

