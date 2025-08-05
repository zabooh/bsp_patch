#!/bin/bash


# Readme (General Tool Installation important)
# https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html


# wget http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/toolchain/mscc-toolchain-bin-2024.02-105.tar.gz
# sudo mkdir -p /opt/mscc
# sudo tar xf mscc-toolchain-bin-2024.02-105.tar.gz -C /opt/mscc
# /opt/mscc/mscc-toolchain-bin-2024.02-105/arm-cortex_a8-linux-gnueabihf/usr/bin/arm-cortex_a8-linux-gnueabihf-gcc --version

wget https://github.com/Kitware/CMake/releases/download/v3.5.2/cmake-3.5.2-Linux-x86_64.tar.gz
tar -xzf cmake-3.5.2-Linux-x86_64.tar.gz
cd cmake-3.5.2-Linux-x86_64
CMAKE_PATH="$(pwd)"
export PATH="$CMAKE_PATH/bin:$PATH"

# export PATH=/home/martin/lan9662/bsp_sources/bsp_patch/cmake-3.5.2-Linux-x86_64/bin:$PATH


# Eine Verzeichnisebene zurück
cd ..

# Get LAN9662 Board Support Package
wget http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/bsp/mscc-brsdk-source-2024.09.tar.gz
tar xf mscc-brsdk-source-2024.09.tar.gz

# Build Firmware first time
cd mscc-brsdk-source-2024.09
make BR2_EXTERNAL=./external O=./output/mybuild arm_standalone_defconfig
cd ./output/mybuild
# make menuconfig
make 



