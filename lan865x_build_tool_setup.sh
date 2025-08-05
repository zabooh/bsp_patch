#!/bin/bash


# Readme (General Tool Installation important)
# https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html


# Pro Conditions

sudo  apt-get install -y \
    asciidoc \
    astyle \
    autoconf \
    bc \
    bison \
    build-essential \
    ccache \
    cmake \
    cmake-curses-gui \
    cpio \
    dblatex \
    default-jre \
    doxygen \
    file \
    flex \
    gdisk \
    genext2fs \
    gettext-base \
    git \
    graphviz \
    gzip \
    help2man \
    iproute2 \
    iputils-ping \
    libacl1-dev \
    libelf-dev \
    libglade2-0 \
    libgtk2.0-0 \
    libmpc-dev \
    libncurses5 \
    libncurses5-dev \
    libncursesw5-dev \
    libssl-dev \
    libtool \
    locales \
    m4 \
    mtd-utils \
    parted \
    patchelf \
    python3 \
    python3-pip \
    rsync \
    ruby-full \
    ruby-parslet \
    squashfs-tools \
    sudo \
    texinfo \
    tree \
    u-boot-tools \
    udev \
    util-linux \
    vim \
    w3m \
    wget \
    xz-utils \

# Additional Ruby packages
$ sudo gem install nokogiri asciidoctor

# Enable use of `python` command instead of `python3`
$ sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 100

# Additional Python packages
$ sudo python -m pip install matplotlib


# Get Toolchain for ARM
wget https://github.com/Kitware/CMake/releases/download/v3.5.2/cmake-3.5.2-Linux-x86_64.tar.gz
tar -xzf cmake-3.5.2-Linux-x86_64.tar.gz
export PATH=/home/martin/lan9662/bsp_sources/cmake-3.5.2-Linux-x86_64/bin:$PATH


CMAKE_DIR="cmake-3.5.2-Linux-x86_64"
CMAKE_ARCHIV="$CMAKE_DIR.tar.gz"
CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v3.5.2/$CMAKE_ARCHIV"

if [ ! -d "$CMAKE_DIR" ]; then
    echo "Directory $CMAKE_DIR does not exist. Download..."
    wget "$CMAKE_URL"
    tar -xzf "$CMAKE_ARCHIV"
fi

# In das Verzeichnis wechseln
cd "$CMAKE_DIR" || { echo "Directory $CMAKE_DIR not found!"; exit 1; }

# Absoluten Pfad des aktuellen Verzeichnisses holen
CMAKE_PATH="$(pwd)"

# Das bin-Verzeichnis dem PATH-Export hinzufügen (üblich bei CMake)
export PATH="$CMAKE_PATH/bin:$PATH"
echo "CMake added to \$PATH : $CMAKE_PATH/bin"

# Eine Verzeichnisebene zurück
cd ..


# Get LAN9662 Board Support Package
wget http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/bsp/mscc-brsdk-source-2024.09.tar.gz
tar xf mscc-brsdk-source-2024.09.tar.gz

# Build Firmware first time
make BR2_EXTERNAL=./external O=./output/mybuild arm_standalone_defconfig
cd ./output/mybuild
# make menuconfig
make 

# After this step the Linux Kernel Sources are download and installed in
#    lan9662/bsp_sources/mscc-brsdk-source-2024.09/output/mybuild/build/linux-custom

# Patch the Kernel Driver, the DTS and the linux config for LAN865X support
cd ../../
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


cd ./output/mybuild
make

exit


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




