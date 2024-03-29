#!/bin/bash

if [ x"$WPET_CONFIG_PARSED" != x"true" ]; then
    # sources the config.sh from our directory
    TOOLS_DIR=$(dirname ${BASH_SOURCE[0]})
    source "$TOOLS_DIR/config.sh"
fi

# These few lines reorder $@ so that options come first.
TEMP=`getopt -o nsSr:b:h --long nfs,sdcard,sunspider,ssh,root:,boot:,help -- "$@"`
if [ $? != 0 ] ; then echo "Problem parsing options" >&2 ; exit 1 ; fi
eval set -- "$TEMP"


DEPLOY_METHOD=
BOOT_DEVICE=
ROOT_DEVICE=
DEPLOY_SUNSPIDER=no

while true ; do
    case "$1" in
        -n|--nfs) DEPLOY_METHOD=nfs ; shift ;;
        -s|--sdcard) DEPLOY_METHOD=sdcard ; shift ;;
        -S|--ssh) DEPLOY_METHOD=ssh; shift ;;
        --sunspider) DEPLOY_SUNSPIDER=yes ; shift ;;
        -b|--boot) BOOT_DEVICE=$2 ; shift 2 ;;
        -r|--root) ROOT_DEVICE=$2 ; shift 2 ;;
        -h|--help) echo "syntax: $0 [-n|--nfs] [-s|--sdcard] [-S|--ssh] [--sunspider] [-h]" ; exit 0;;
        --) shift ; break ;;
        *) echo "unknown option: $1" ; exit 1 ;;
    esac
done

function root_check() {
    if [ $EUID -ne 0 ]; then
        echo "Need root privilege for deploy method $DEPLOY_METHOD"
        exit 1
    fi
}


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

function umount_if_needed(){
    for dev in "$BOOT_DEVICE" "$ROOT_DEVICE"; do
        if findmnt -S "$dev" ; then
            echo "${dev} is mounted, umounting..."
            umount "${dev}"
        fi
    done
}

function check_output(){
    if [ ! -d "$WPET_OUTPUT/images" ]; then
        echo "Cannot find $WPET_OUTPUT/images"
        exit 1
    fi
}

function deploy_sunspider() {
    if [ x$DEPLOY_SUNSPIDER == x"yes" ]; then
        target="$1"
        sunspider_path="$WPET_WPE_SOURCE/PerformanceTests/SunSpider"
        mkdir -p "$target"
        cp -a "$sunspider_path" "$target"
    fi
}

echo "deploy method: $DEPLOY_METHOD"

if [ x$DEPLOY_METHOD == x"nfs" ]; then
    root_check
    echo "Deploying build in $WPET_OUTPUT to $WPET_NFS and $WPET_TFTPBOOT"

    mkdir -p "$WPET_NFS"
    rm -rf "$WPET_NFS"/*
    tar xf "$WPET_OUTPUT/images/rootfs.tar" -C "$WPET_NFS"
    if [ -n "$WPET_RPI_SERIAL" ]; then
      cp "$WPET_OUTPUT/images/rpi-firmware/bootcode.bin" "${WPET_TFTPBOOT}/"
      rm -rf "${WPET_TFTPBOOT}/${WPET_RPI_SERIAL}"
      mkdir -p "${WPET_TFTPBOOT}/${WPET_RPI_SERIAL}"
      cp -r "$WPET_OUTPUT/images/rpi-firmware/"* "${WPET_TFTPBOOT}/${WPET_RPI_SERIAL}/"
      cp "$WPET_OUTPUT"/images/*.dtb "${WPET_TFTPBOOT}/${WPET_RPI_SERIAL}/"
      cp "$WPET_OUTPUT/images/zImage" "${WPET_TFTPBOOT}/${WPET_RPI_SERIAL}/"
      echo "vt.global_cursor_default=0 root=/dev/nfs nfsroot=10.42.0.1:${WPET_NFS},vers=3 rw ip=dhcp rootwait console=tty1 console=ttyS0,115200" > ${WPET_TFTPBOOT}/${WPET_RPI_SERIAL}/cmdline.txt
    else
      cp "$WPET_OUTPUT/images/zImage" "$WPET_TFTPBOOT/zImage.$WPET_OUTPUT_NAME"
    fi
    deploy_sunspider "$WPET_NFS/tests"

elif [ x$DEPLOY_METHOD == x"sdcard" ]; then
    root_check
    set_devices
    check_mount_dirs
    umount_if_needed
    check_output

    echo "formatting boot partition $BOOT_DEVICE"
    mkfs.vfat -F 32 -n wpetboot "$BOOT_DEVICE"
    echo "formatting root partition $ROOT_DEVICE"
    mkfs.ext4 -L wpetrootfs "$ROOT_DEVICE"

    echo "copying boot files"
    mount "$BOOT_DEVICE" "$WPET_BOOT_MOUNT"
    cp -r "$WPET_OUTPUT/images/rpi-firmware/"* "$WPET_BOOT_MOUNT"
    cp "$WPET_OUTPUT"/images/*.dtb "$WPET_BOOT_MOUNT"
    cp "$WPET_OUTPUT/images/zImage" "$WPET_BOOT_MOUNT"
    sync
    umount "$WPET_BOOT_MOUNT"

    echo "copying root files"
    mount "$ROOT_DEVICE" "$WPET_ROOT_MOUNT"
    tar -xvpsf "$WPET_OUTPUT/images/rootfs.tar" -C "$WPET_ROOT_MOUNT"
    deploy_sunspider "$WPET_ROOT_MOUNT/tests"
    echo "syncing..."
    sync
    umount "$WPET_ROOT_MOUNT"

    echo "syncing again..."
    sync

    echo "All done! You can take the sdcard and insert it on the device."

elif [ x$DEPLOY_METHOD == x"ssh" ]; then
    $TOOLS_DIR/set_date.sh >/dev/null &
    target=$WPET_OUTPUT/target
    deploy_bins=(jsc testmasm testapi testdfg testair testb3 WPELauncher WPENetworkProcess WPEStorageProcess WPEWebProcess)
    deploy_libs=('libWTF*' 'libJavaScriptCore*' 'libWPE*' 'wpeframework/plugins/libWPEFrameworkWebKitBrowser.so')
    archive=$(mktemp -p "$PWD" deploy-XXXXX.tar.gz)
    pushd "$target" > /dev/null
    for x in ${deploy_libs[*]/#/usr/lib/} ${deploy_bins[*]/#/usr/bin/}; do
        test -e "$x" && echo "$x"
    done | xargs tar czf "$archive"
    echo "List of files to be sent:"
    tar tf "$archive"
    remote_archive=$(ssh -p $WPET_REMOTE_SSH_PORT $WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST mktemp --tmpdir deploy-XXXXX.tar.gz)
    echo "copying $archive to remote as $remote_archive"
    scp -P $WPET_REMOTE_SSH_PORT "$archive" "$WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST:$remote_archive"
    echo "untarring archive on remote target"
    ssh -p $WPET_REMOTE_SSH_PORT $WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST tar xzf "$remote_archive" -C /
    ssh -p $WPET_REMOTE_SSH_PORT $WPET_REMOTE_SSH_USER@$WPET_REMOTE_HOST rm -f "$remote_archive"
    popd > /dev/null
    rm "$archive"
    echo "all done!"

else
    echo "No deploy method specified! You need to choose between nfs (-n/--nfs) and sdcard (-s/--sdcard)"
    exit 1
fi

