
###################################################################################################
### ATTENTION THIS IS AN CONSTRUNCTION AREA #######################################################
###################################################################################################

## Pay attention: There are several obstacles when used on different Linux Installations regarding tool versions.
## Informantion derived from: 
## https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html
## cmake version must be lower than 4.x.x

## the following scripts are more to copy from and paste line by line into the command line  
## in theory they could be called, but when things go wrong because of installation issues, you
## not know what has went wrong. 
## this scripts are more ment as a How-To

## information is derived from the following links

   https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html

   https://microchip.my.site.com/s/article/Step-by-step-guide-in-building-a-standalone-image-for-LAN966x-and-programming-it-to-EVB-LAN9662


  
###### ON BUILD MACHINE BEGIN ###########################################
## this setups the needed tools:
   lan865x_build_tool_setup.sh

## this explains how to rebuild the default firmware for the lan9662 PCB8291 board
   lan865x_build_first.sh

## and here is expplained how to patch the sources for the LAN9851 Click Board 
   lan865x_build_second.sh
###### ON BUILD MACHINE END #############################################



###### ON WINDOWS BEGIN #################################################
## The LAN9662 Board can get via TFTP a new Firmware
## easiest TFTP Server setup would be under Windows with
   pip install py3tftp
   py3tftp --host 0.0.0.0 -p 6969

## allow UDP port 69 in the Firewall (in PowerShell as admin)
   New-NetFirewallRule -DisplayName "TFTP-UDP-69-Temp" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 69

## start py3tftp at port 69 (default for py3tftp is 9069 but tftfp standard is 69, then you dont have to change it on lan9662 board)
   py3tftp --host 0.0.0.0 --port 69

## ensure that brsdk_standalone_arm.ext4.gz is in the same directory where py3tftp is started
##   brsdk_standalone_arm.ext4.gz 
###### ON WINDOWS END ######################################################



###### ON LAN9662 BOARD BEGIN ##############################################
## During startup of the Board, press Enter to enter UBoot mode
## Download and programm in UBOOT
## Using AutoIP Addressing with direct cabling between Windows and LAN9662 EvalKit
## UBOOT:

   setenv ipaddr 169.254.35.123
   setenv netmask 255.255.0.0
   tftp 169.254.35.184:brsdk_standalone_arm.ext4.gz
   unzip ${loadaddr} ${mmc_unzip_loadaddr}
   run mmc_format
   run mmc_boot0_upd; run mmc_boot1_upd
   boot

## during Runtime of Linux
## setup the LAN8651

   ethtool --set-plca-cfg eth2 enable on node-id 0 node-cnt 8
   ethtool --get-plca-cfg eth2
##   PLCA settings for eth2:
##        Enabled: Yes
##        local node ID: 0 (coordinator)
##        Node count: 8
##        TO timer: 32 BT
##        Burst count: 0 (disabled)
##        Burst timer: 128 BT
                
   ip addr add dev eth2 192.168.10.11/24
   ip link set eth2 up
   ifconfig


## for example sending a file from LAN9662 to TFTP server
#   tftp -p -l dev_tree.txt -r dev_tree.txt 169.254.35.184
## Or ping a Host. Ensure to use the correct interface
#   ping -I eth0 169.254.35.184

###################################################
##
## File Overlay
## 
## make menuconfig
##  System configuration  --->
##     (board/mscc/common/rootfs_overlay) Root filesystem overlay directories 
##   
##    the Script S99myconfig.sh is automatically executed during startup and the 
##    right place for own configuration setup
##
##    mscc-brsdk-source-2024.09/board/mscc/common/rootfs_overlay
##
##    ├── etc  
##    │   ├── init.d
##    │   │   └── S99myconfig.sh
##    │   ├── mscc
##    │   │   └── service
##    │   │       └── debug_shell.service
##    │   └── sysctl.d
##    │       └── 99-sysctl.conf
##    └── usr
##        └── bin
##            ├── dump-env.sh
##            └── production-prepare.sh
##
##
##  
##  S99myconfig.sh
##   #!/bin/sh
##   echo "Start Custom-Configuration..." > /tmp/bootlog.txt
##   # Sample Configuration
##   
##   ethtool --set-plca-cfg eth2 enable on node-id 0 node-cnt 8
##   ip addr add dev eth2 169.254.35.112/16
##   ip link set eth2 up
##   
##   ip addr add dev eth0 169.254.35.110/16
##   ip link set eth0 up
##   



	

