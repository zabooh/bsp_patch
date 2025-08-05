

###################################################################################################
### ATTENTION THIS IS AN CONSTRUNCTION AREA #######################################################
###################################################################################################



###################################################################################################
# from tftp installation of an tftp server under wsl2
# does not work without problems because udp port forwarding is currently not 
# supported in windows for wsl2  
# alternatively would be bridging the interfaces, but then you loose the NAT service
# and it complicated to install.
#
# easiest TFTP Server setup would be under Windows with
#   pip install py3tftp
#   py3tftp --host 0.0.0.0 -p 6969
#
# 
##########################################
# under windows install py3tftp 
#    pip install py3tftp
# allow UDP port 69 in the Firewall (as admin) 
#    New-NetFirewallRule -DisplayName "TFTP-UDP-69-Temp" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 69
# start py3tftp at port 69 (default for py3tftp is 9069 but tftfp standard is 69, then you dont have to change it on lan9662 board)
#    py3tftp --host 0.0.0.0 --port 69
# test with default windows tftp client
#    tftp -i 127.0.0.1 GET tftp.bat
##########################################


### http://kar-vm-gitlab/galileo/lan865x-linux-driver/-/blob/Galileo_RevB1_RTP_0v4/src/oa_tc6.c



# from here change to lan9662 board
# see also at
# https://microchip-ung.github.io/bsp-doc/bsp/2025.06-1/supported-hw/lan966x-boot.html#_from_emmc


env set 'ipaddr 192.168.0.10'
env set 'netmask 255.255.255.0'
env set 'serverip 192.168.0.1'
saveenv



mmc_boot0_dlup=run mmc_dl; run mmc_boot0_upd
mmc_dl=dhcp ${loadaddr} ${mmc_fw}; unzip ${loadaddr} ${mmc_unzip_loadaddr}
mmc_boot0_upd=run div_512; mmc write ${mmc_unzip_loadaddr} ${mmc_offset_boot0} ${filesize_512}
mmc_fw=brsdk_standalone_arm.ext4.gz




