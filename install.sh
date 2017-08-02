#!/bin/bash

###############################################################################
#
# install-packages.sh
#
# Installs (and removes) packages I frequently use to make new installations
# quicker. In addition to installing a list of packages from apt repos this
# script also adds NodeJS and Google Chrome.
#
# Usage: sudo ./install-packages.sh
#
###############################################################################

readonly REQUIRE_PACKAGES=(
    # Development tools
    build-essential
    cmake
    gcc-arm-none-eabi
    g++
    exuberant-ctags
    autoconf
    automake
    make
    # Applications
    vim
    nmap
    nethogs
    aircrack-ng
    git
    subversion
    openssh-server
    gparted
    android-tools-adb
    android-tools-fastboot
    pithos
    gimp
    vlc
    terminator
    handbrake
    curl
    gawk
    bison
    flex
    texinfo
    libtool
    pkg-config
    # Libraries
    zlib1g-dev
    python-dev
    python3-dev
    libexpat1-dev
    libmpc-dev
    libgmp-dev
    libusb-1.0-0-dev
)

# Some packages in the repos contain known bugs. E.g., libimobiledevice doesn't
# work with iOS 10. It's been fixed in GitHub but hasn't percolated down 
# into repos yet.
readonly STALE_PACKAGES=(
    libimobiledevice6
)

###############################################################################

# Installation steps
do_update_and_upgrade=y
do_remove_stale_packages=y
do_install_packages_from_repos=y
do_install_google_chrome=y
do_install_nodejs=y
do_install_imobiledevice=y

###############################################################################

msg() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)]: $@" >&2
}

###############################################################################

update_and_upgrade() {
    msg "Updating apt"
    apt-get update && apt-get upgrade
}

###############################################################################

install_packages_from_repos() {
    msg "Generating package install list"
    local reqinstalled=true
    local missing=()
    for i in "${REQUIRED_PACKAGES[@]}"
    do
        reqinstalled=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
        if [ "" != "$reqinstalled" ]; then
            missing+=($i)
        fi
    done
    if [ ! ${#missing[@]} -eq 0 ]; then
        install_packages ${missing[@]}
    fi
}

###############################################################################

remove_stale_packages() {
    # Check whether the undesirable packages are even installed. Generate a new
    # list only including which pakcgaes are actually present and remove them.
    msg "Checking for packages to remove"
    local reqinstalled=true
    local stale=()
    for i in "${STALE_PACKAGES[@]}"
    do
        reqinstalled=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
        if [ "" != "$reqinstalled" ]; then
            stale+=($i)
        fi
    done
    if [ ! ${#stale[@]} -eq 0 ]; then
        remove_packages ${stale[@]}
    fi
}

###############################################################################

remove_packages() {
    msg "Removing packages"
    apt-get --yes --force-yes autoremove $@
}

###############################################################################
# Start execution
###############################################################################

# Provide an opportunity to canel
msg "Install packages"
read -p "Press ENTER to continue (c to cancel) ..." entry
if [ ! -z $entry ]; then
    if [ $entry = "c" ]; then
        msg "Installation cancelled."
        exit 0
    fi
fi

if [ $do_update_and_upgrade = "y" ]; then
    update_and_upgrade
fi

if [ $do_remove_stale_packages = "y" ]; then
    rmeove_stale_repos
fi

if [ $do_install_packages_from_repos = "y" ]; then
    install_packages_from_repos
fi

