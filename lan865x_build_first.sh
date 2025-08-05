#!/bin/bash


## Readme (General Tool Installation important)
## https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html

## download and install the ARM compiler toolchain
wget http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/toolchain/mscc-toolchain-bin-2024.02-105.tar.gz
sudo mkdir -p /opt/mscc
sudo tar xf mscc-toolchain-bin-2024.02-105.tar.gz -C /opt/mscc
/opt/mscc/mscc-toolchain-bin-2024.02-105/arm-cortex_a8-linux-gnueabihf/usr/bin/arm-cortex_a8-linux-gnueabihf-gcc --version

## Buildroot expects a cmake version less than 4.x.x, which is already preinstalled on most newer Linux
## download and install a v3.5.2 and put it in the PATH so that this is first one found
wget https://github.com/Kitware/CMake/releases/download/v3.5.2/cmake-3.5.2-Linux-x86_64.tar.gz
tar -xzf cmake-3.5.2-Linux-x86_64.tar.gz
cd cmake-3.5.2-Linux-x86_64
CMAKE_PATH="$(pwd)"
export PATH="$CMAKE_PATH/bin:$PATH"
## or add the absolute path directly to PATH
## Attention, the following line is only temporary
# export PATH=/home/martin/lan9662/bsp_sources/bsp_patch/cmake-3.5.2-Linux-x86_64/bin:$PATH
## the one step back
cd ..

## Get LAN9662 Board Support Package
wget http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/bsp/mscc-brsdk-source-2024.09.tar.gz
tar xf mscc-brsdk-source-2024.09.tar.gz

## Build Firmware first time
cd mscc-brsdk-source-2024.09
make BR2_EXTERNAL=./external O=./output/mybuild arm_standalone_defconfig
cd ./output/mybuild
# make menuconfig
make 

## After this step the Linux Kernel Sources are download and installed in
##    mscc-brsdk-source-2024.09/output/mybuild/build/linux-custom

## back to root of git clone
cd ../../../

