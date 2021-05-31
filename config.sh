#!/bin/bash

#### Options you are likely to change often ####

#export WPET_OUTPUT_NAME=output.ci20
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=10.42.0.15
#export WPET_BUILDROOT_KIND="buildroot-jsc"
#export WPET_PORT="jsconly"

#export WPET_OUTPUT_NAME=ci20-buildbot
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=10.42.0.15
#export WPET_BUILDROOT_KIND="buildroot-jsc"
#export WPET_PORT="jsconly"

#export WPET_OUTPUT_NAME=rpi2-buildbot
#export WPET_PLATFORM=arm-linux
#export WPET_REMOTE_HOST=10.42.0.146
#export WPET_BUILDROOT_KIND="buildroot-jsc"
#export WPET_PORT="jsconly"

export WPET_OUTPUT_NAME=rpi3-buildbot
export WPET_PLATFORM=arm-linux
export WPET_REMOTE_HOST=10.42.0.16
export WPET_BUILDROOT_KIND="buildroot-jsc"
export WPET_PORT="jsconly"
export WPET_RPI_SERIAL=d34398fb

#export WPET_OUTPUT_NAME=rpi3-wpe
#export WPET_PLATFORM=arm-linux
#export WPET_REMOTE_HOST=10.42.0.16
#export WPET_BUILDROOT_KIND="buildroot-jsc"
#export WPET_PORT="wpe"
#export WPET_RPI_SERIAL=d34398fb

#export WPET_OUTPUT_NAME=rpi3
#export WPET_PLATFORM=arm-linux
#export WPET_REMOTE_HOST=10.42.0.16
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"
#export WPET_RPI_SERIAL=d34398fb

#export WPET_OUTPUT_NAME=rpi2
#export WPET_PLATFORM=arm-linux
#export WPET_REMOTE_HOST=10.42.0.146
#export WPET_BUILDROOT_KIND="buildroot-jsc"
#export WPET_PORT="jsconly"

#export WPET_OUTPUT_NAME=bcm7429
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=10.42.0.221
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"

#export WPET_OUTPUT_NAME=output.dawn.gcc5
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=10.42.0.198
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"

#export WPET_OUTPUT_NAME=rpi2-softfp
#export WPET_PLATFORM=arm-linux
#export WPET_REMOTE_HOST=192.168.0.11
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"

#export WPET_OUTPUT_NAME=output.dawn.hardfp
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=192.168.0.7
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"


#export WPET_OUTPUT_NAME=output.dawn.softrender
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=192.168.0.7
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"


#export WPET_OUTPUT_NAME=output.dawn.hardfp.unwind
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=192.168.0.7
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"
#
#export WPET_OUTPUT_NAME=output.rpi1
#export WPET_PLATFORM=arm-linux
#export WPET_REMOTE_HOST=192.168.0.102
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"

#export WPET_OUTPUT_NAME=output.dawn
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=192.168.0.7
#export WPET_BUILDROOT_KIND="buildroot"
#export WPET_PORT="qtwebkit"

#export WPET_OUTPUT_NAME=output
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=192.168.0.7
#export WPET_BUILDROOT_KIND="buildroot"
#export WPET_PORT="qtwebkit"

#export WPET_OUTPUT_NAME=output.dawn.gcc4.8
#export WPET_PLATFORM=mipsel-linux
#export WPET_REMOTE_HOST=192.168.0.7
#export WPET_BUILDROOT_KIND="buildroot-wpe"
#export WPET_PORT="wpe"


export WPET_WPE_SOURCE="${HOME}/dev/WebKit"
export WPET_REMOTE_SSH_USER=root
export WPET_REMOTE_SSH_PORT=22
export WPET_REMOTE_GDB_PORT=2345
export WPET_ARCHITECTURE=${WPET_PLATFORM%%-*}
export WPET_QEMU=qemu-${WPET_ARCHITECTURE}-static

# these mount directories need to exist!
export WPET_BOOT_MOUNT=/media/boot
export WPET_ROOT_MOUNT=/media/rootfs


#### Options to set once ####
# where you have everything checked out
export WPET_BASE=/home/guijemont/dev/metrological

# when using NFS + TFTPBOOT for your device, this is where stuff should be
# deployed:
export WPET_NFS=/srv/$WPET_OUTPUT_NAME
export WPET_TFTPBOOT=/tftpboot

#### Stuff you shouldn't need to change ####
# if you have everything under the same directory #

export WPET_BUILDROOT="$WPET_BASE/$WPET_BUILDROOT_KIND"
# This is where this file shoud be!
export WPET_TOOLS="$WPET_BASE/wpe-tools"
export WPET_OUTPUT="$WPET_BUILDROOT/$WPET_OUTPUT_NAME"
export WPET_GCC_VERSION=$(awk -F= '/BR2_GCC_VERSION=/ { gsub(/"/, "", $2); print $2 }' ${WPET_OUTPUT}/.config)

if [ x$WPET_PORT  == x"wpe" ]; then
  # This expects that you have a local.mk to use a custom location (e.g. local
  # branch) for wpe.
  export WPET_WPE_BUILD="$WPET_OUTPUT/build/wpewebkit-custom"
elif [ x$WPET_PORT == x"jsconly" ]; then
  # This expects that you have a local.mk to use a custom location (e.g. local
  # branch) for wpe.
  export WPET_WPE_BUILD="$WPET_OUTPUT/build/jsconly-custom"
else
  # This expects that you have a local.mk to use a custom location (e.g. local
  # branch) for wpe.
  export WPET_WPE_BUILD="$WPET_OUTPUT/build/qt5webkit-custom"
fi


export WPET_CONFIG_PARSED=true
