#!/bin/bash

## Readme (General Tool Installation important)
## https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html

## Patch the Kernel Driver, the DTS and the linux config for LAN865X support
## zip -r lan865x_driver.zip mscc-brsdk-source-2024.09/output/mybuild/build/linux-custom/drivers/net/ethernet/microchip/
unzip lan865x_driver.zip
## zip lan865x_dts.zip mscc-brsdk-source-2024.09/output/mybuild/build/linux-custom/arch/arm/boot/dts/microchip/lan966x-pcb8291.dts
unzip lan865x_dts.zip
##
tar xfv linux-custom-patch.tar.gz
##
tar xfv linux-kernel-config.tar.gz
##
tar xfv lan865x_file_overlay.tar.gz
##
tar xfv lan865x_InitScript.tar.gz

cd ./mscc-brsdk-source-2024.09/output/mybuild
## do it again
## when the device tree source is changed, the dtb file must be deleted to be build new
rm build/linux-custom/arch/arm/boot/dts/microchip/lan966x-pcb8291.dtb
## only build linux kernel and dtb new 
make linux-rebuild
## make complete image
make
