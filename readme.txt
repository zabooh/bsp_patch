

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


## Using Python TFTP server on Windows
## Allowing UDP Port 69 for TFTP on Windows. Do it with Admin Shell
New-NetFirewallRule -DisplayName "TFTP-UDP-69-Temp" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 69

## install TFTP 
pip install py3tftp

## Using py3tftp

## ensure that brsdk_standalone_arm.ext4.gz is in the same directory
## where py3tftp is started
py3tftp --host 0.0.0.0 --port 69

## setting network
ifconfig eth0 169.254.35.123 netmask 255.255.0.0
ifconfig eth0 up
ping 169.254.35.184


## sending file from LAN9662
tftp -p -l dev_tree.txt -r dev_tree.txt 169.254.35.184


##########################################
#
## Download and programm in UBOOT
## Using AutoIP Addressing with direct cabling between Windows and LAN9662 EvalKit


setenv ipaddr 169.254.35.123
setenv netmask 255.255.0.0


tftp 169.254.35.184:brsdk_standalone_arm.ext4.gz
unzip ${loadaddr} ${mmc_unzip_loadaddr}
run mmc_format
run mmc_boot0_upd; run mmc_boot1_upd
boot


##########################################
# Runtime

ethtool --set-plca-cfg eth2 enable on node-id 0 node-cnt 8

ethtool --get-plca-cfg eth2
PLCA settings for eth2:
        Enabled: Yes
        local node ID: 0 (coordinator)
        Node count: 8
        TO timer: 32 BT
        Burst count: 0 (disabled)
        Burst timer: 128 BT
        
        

ip addr add dev eth2 192.168.10.11/24
ip link set eth2 up
ifconfig







