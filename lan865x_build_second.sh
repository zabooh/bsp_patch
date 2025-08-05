#!/bin/bash


# Readme (General Tool Installation important)
# https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html


# After this step the Linux Kernel Sources are download and installed in
#    lan9662/bsp_sources/mscc-brsdk-source-2024.09/output/mybuild/build/linux-custom

# Patch the Kernel Driver, the DTS and the linux config for LAN865X support
cd ../../../
tar xfv lan865x_driver.202507291238.tar.gz
tar xfv lan865x_dts.202507291238.tar.gz
tar xfv lan865x_linux_custom.202507291238.tar.gz

#### Or select by yourself 
#cd mscc-brsdk-source-2024.09/output/mybuild
# make BR2_EXTERNAL=./external O=output/mybuild/ linux-menuconfig
## search for lan865x driver with "/lan865x"
## select the first hit with "1"
## click twice on space to get the * between <> 
##  <*>   Microchip LAN865x Ethernet driver
## save and exit
#make 


cd ./mscc-brsdk-source-2024.09/output/mybuild
# do it again
make


