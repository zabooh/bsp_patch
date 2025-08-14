#!/bin/bash

## Readme (General Tool Installation important)

## This script is meant more as a How-To then to be executed
## Pay attention: There are several obstacles when used on different Linux Installations regarding tool versions.
## Informantion derived from: 
## https://microchip-ung.github.io/bsp-doc/bsp/2025.03/getting-started.html
## Buildroot needs Ruby. On Ubtuntu 
## Setup Pre Conditions

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

## Additional Ruby packages
sudo gem install nokogiri asciidoctor

## Enable use of `python` command instead of `python3`
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 100

## Additional Python packages
## sudo python -m pip install matplotlib
sudo apt install python3-matplotlib

## It can happe on Ubuntu 24.04 that ruby and some libraries has to be installed differently  
## If Ruby is not yet installed on Ubuntu 24.04, many users first install various development tools and libraries with the following command:
# sudo apt install build-essential patch ruby-dev zlib1g-dev liblzma-dev libxml2-dev libxslt-dev
## Only afterwards can Ruby itself and important libraries be installed without issues.
# sudo gem install nokogiri -v 1.15.5
# sudo gem install parslet


