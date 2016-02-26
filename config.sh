#!/bin/bash

#### Options you are likely to change often ####
# output dir in buildroot
export WPET_OUTPUT_NAME=rpi2
export WPET_PLATFORM=arm-linux

export WPET_REMOTE_HOST=192.168.0.103
export WPET_REMOTE_SSH_USER=root
export WPET_REMOTE_SSH_PORT=22
export WPET_REMOTE_GDB_PORT=2345

# FIXME: get that from $WPET_OUTPUT/.config
export WPET_GCC_VERSION=4.9.3


#### Options to set once ####
# where you have everything checked out
export WPET_BASE=/home/guijemont/dev/metrological

# when using NFS + TFTPBOOT for your device, this is where stuff should be
# deployed:
export WPET_NFS=/srv/dawn
export WPET_TFTPBOOT=/tftpboot

#### Stuff you shouldn't need to change ####
# if you have everything under the same directory #

export WPET_BUILDROOT="$WPET_BASE/buildroot-wpe"
# This is where this file shoud be!
export WPET_TOOLS="$WPET_BASE/wpe-tools"
export WPET_OUTPUT="$WPET_BUILDROOT/$WPET_OUTPUT_NAME"
export WPET_WPE_SOURCE="$WPET_BASE/WebKitForWayland"

# This expects that you have a local.mk to use a custom location (e.g. local
# branch) for wpe.
export WPET_WPE_BUILD="$WPET_OUTPUT/build/wpe-custom"

export WPET_CONFIG_PARSED=true
