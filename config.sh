#!/bin/bash

#### Options you are likely to change often ####
# output dir in buildroot
WPET_OUTPUT_NAME=output.dawn.hardfp
WPET_PLATFORM=mipsel-linux

WPET_REMOTE_HOST=192.168.0.7
WPET_REMOTE_SSH_PORT=22
WPET_REMOTE_GDB_PORT=2345

# FIXME: get that from $WPET_OUTPUT/.config
WPET_GCC_VERSION=4.9.3


#### Options to set once ####
# where you have everything checked out
WPET_BASE=/home/guijemont/dev/metrological

# when using NFS + TFTPBOOT for your device, this is where stuff should be
# deployed:
WPET_NFS=/srv/dawn
WPET_TFTPBOOT=/tftpboot

#### Stuff you shouldn't need to change ####
# if you have everything under the same directory #

WPET_BUILDROOT="$WPET_BASE/buildroot-wpe"
# This is where this file shoud be!
WPET_TOOLS="$WPET_BASE/wpe-tools"
WPET_OUTPUT="$WPET_BUILDROOT/$WPET_OUTPUT_NAME"
WPET_WPE_SOURCE="$WPET_BASE/WebKitForWayland"

WPET_CONFIG_PARSED=true
