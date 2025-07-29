#!/bin/bash


# Readme (General Tool Installation important)
# https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html

# Create workspace
mkdir lan9662
cd lan9662 
mkdir bsp_sources
cd bsp_sources

# Get Toolchain for ARM
wget https://github.com/Kitware/CMake/releases/download/v3.5.2/cmake-3.5.2-Linux-x86_64.tar.gz
tar -xzf cmake-3.5.2-Linux-x86_64.tar.gz
export PATH=/home/martin/lan9662/bsp_sources/cmake-3.5.2-Linux-x86_64/bin:$PATH

# Get LAN9662 Board Support Package
wget http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/bsp/mscc-brsdk-source-2024.09.tar.gz
tar xf mscc-brsdk-source-2024.09.tar.gz

# Build Firmware first time
cd mscc-brsdk-source-2024.09
make BR2_EXTERNAL=./external O=output/mybuild/ linux-menuconfig
cd ./output/mybuild
make menuconfig
make 

# After this step the Linux Kernel Sources are download and installed in
#    lan9662/bsp_sources/mscc-brsdk-source-2024.09/output/mybuild/build/linux-custom

# Patch the Kernel Driver, the DTS and the linux config for LAN865X support
cd ..
tar xfv lan865x_driver.202507291238.tar.gz
tar xfv lan865x_dts.202507291238.tar.gz
tar xfv lan865x_linux_custom.202507291238.tar.gz

#### Or select by yourself 
#cd mscc-brsdk-source-2024.09/output/mybuild
#make linux-menuconfig
## search for lan865x driver with "/lan865x"
## select the first hit with "1"
## click twice on space to get the * between <> 
##  <*>   Microchip LAN865x Ethernet driver
## save and exit
#make 

