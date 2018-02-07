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

readonly REQUIRED_PACKAGES=(
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
    libtool-bin
    pkg-config
    cython
    openssl
    doxygen
    tmux
    apt-transport-https
    fonts-inconsolata
    ncdu
    rustc
    cargo
    # Libraries
    zlib1g-dev
    python-dev
    python3-dev
    libexpat1-dev
    libmpc-dev
    libgmp-dev
    libusb-dev
    libusb-1.0-0
    libusb-1.0-0-dev
    libzip-dev
    libssl-dev
    libfuse2
    libfuse-dev
    libudev1
    libudev-dev
)

# Some packages in the repos contain known bugs. E.g., libimobiledevice doesn't
# work with iOS 10. It's been fixed in GitHub but hasn't percolated down 
# into repos yet.
readonly STALE_PACKAGES=(
    libplist3
    libusbmuxd4
    libimobiledevice6
)

# N.B: due to depedencies these pakages must be built in this order
readonly IMOBILE_PACKAGES=(
    libplist
    libusbmuxd
    libimobiledevice
    usbmuxd
)

readonly CUR_DIR=`pwd`
readonly INSTALL_DIR="/usr"
readonly BUILD_DIR="$CUR_DIR/imobiledevice"

###############################################################################

# Installation steps
do_update_and_upgrade=y
do_remove_stale_packages=n
do_install_packages_from_repos=y
do_install_google_chrome=y
do_install_nodejs=y
do_install_imobiledevice=n
do_setup_vim=y

###############################################################################

msg() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)]: $@" >&2
}

###############################################################################

update_and_upgrade() {
    msg "Updating apt"
    apt-get update && apt-get --yes --force-yes upgrade
}

###############################################################################

install_packages_from_repos() {
    msg "Generating package install list"
    local reqinstalled=true
    local missing=()
    for i in "${REQUIRED_PACKAGES[@]}"
    do
        reqinstalled=$(apt-cache policy $i | grep "Installed: (none)")
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

install_packages() {
    msg "Installing missing packages from repos"
    apt-get --yes --force-yes install $@
}

###############################################################################

remove_packages() {
    msg "Removing packages"
    apt-get --yes --force-yes autoremove $@
}

###############################################################################

install_imobiledevice() {
    msg "Building and installing libimobiledevice"

    # Check for the build directory and create it if absent
    if [ ! -d "$BUILD_DIR" ]; then
        msg "Creating imobiledevice build directory: $BUILD_DIR"
        mkdir -p $BUILD_DIR
    fi
    cd $BUILD_DIR

    # Build and install each component in the libimobiledevice suite
    for i in "${IMOBILE_PACKAGES[@]}"
    do
        build_package $i
        install_package $i
    done
    cd $CUR_DIR
}

###############################################################################

build_package() {
    msg "Building $1"
    git clone https://github.com/libimobiledevice/$1.git
    cd $1
    ./autogen.sh --prefix=$INSTALL_DIR --enable-debug-code
    if [ ! -f Makefile.in ]; then
        # Ugly hack: I don't know why, but autogen.sh sometimes fails the
        # first time its run but sicessfully subsequent times. Requires
        # investigation.
        ./autogen.sh --prefix=$INSTALL_DIR --enable-debug-code
    fi
    make
    cd $BUILD_DIR
}

###############################################################################

install_package() {
    msg "Installing package: $1"
    cd $1
    make install
    cd $BUILD_DIR
}

###############################################################################

install_google_chrome() {
    msg "Installing Google Chrome browser"
    grep chrome /etc/apt/sources.list.d/google-chrome.list >&/dev/null || (
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add
        echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
        apt-get update
        apt-get install -y --no-install-recommends google-chrome-stable
    )
}

###############################################################################

install_nodejs() {
    msg "Installing NodeJS"
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    apt-get install -y nodejs
}

###############################################################################

setup_vim() {
    msg "Setting up Vim"
    sudo npm -g install jshint
    wget --directory-prefix=$HOME https://raw.githubusercontent.com/dgrubb/vim-config/master/.vimrc
    if [ ! -d "~/.vim/colors" ]; then
        mkdir -p ~/.vim/colors
    fi
    wget --directory-prefix=$HOME/.vim/colors https://raw.githubusercontent.com/Lokaltog/vim-distinguished/develop/colors/distinguished.vim
    git clone https://github.com/VundleVim/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim
    vim +PluginInstall +qall
    cd ~/.vim/bundle/YouCompleteMe
    ./install.py --tern-completer --clang-completer

    # Add Rust parsing to ctags to allow for integration with TagBar
    echo "--langdef=Rust" >> ~/.ctags
    echo "--langmap=Rust:.rs" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*(#\[[^\]]\][ \t]*)*(pub[ \t]+)?(extern[ \t]+)?(\"[^\"]+\"[ \t]+)?(unsafe[ \t]+)?fn[ \t]+([a-zA-Z0-9_]+)/\6/f,functions,function definitions/" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*(pub[ \t]+)?type[ \t]+([a-zA-Z0-9_]+)/\2/T,types,type definitions/" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*(pub[ \t]+)?enum[ \t]+([a-zA-Z0-9_]+)/\2/g,enum,enumeration names/" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*(pub[ \t]+)?struct[ \t]+([a-zA-Z0-9_]+)/\2/s,structure names/" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*(pub[ \t]+)?mod[ \t]+([a-zA-Z0-9_]+)/\2/m,modules,module names/" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*(pub[ \t]+)?(static|const)[ \t]+(mut[ \t]+)?([a-zA-Z0-9_]+)/\4/c,consts,static constants/" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*(pub[ \t]+)?(unsafe[ \t]+)?trait[ \t]+([a-zA-Z0-9_]+)/\3/t,traits,traits/" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*(pub[ \t]+)?(unsafe[ \t]+)?impl([ \t\n]*<[^>]*>)?[ \t]+(([a-zA-Z0-9_:]+)[ \t]*(<[^>]*>)?[ \t]+(for)[ \t]+)?([a-zA-Z0-9_]+)/\5 \7 \8/i,impls,trait implementations/" > ~/.ctags
    echo "--regex-Rust=/^[ \t]*macro_rules![ \t]+([a-zA-Z0-9_]+)/\1/d,macros,macro definitions/" > ~/.ctags
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
    remove_stale_packages
fi

if [ $do_install_packages_from_repos = "y" ]; then
    install_packages_from_repos
fi

if [ $do_install_google_chrome = "y" ]; then
    install_google_chrome
fi

if [ $do_install_nodejs = "y" ]; then
    install_nodejs
fi

if [ $do_install_imobiledevice = "y" ]; then
    install_imobiledevice
fi

if [ $do_setup_vim = "y" ]; then
    setup_vim
fi
