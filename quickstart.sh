#!/bin/bash


function isRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi
}

function checkXen () {
    local apt_updated=0
    if ! dpkg -s "xen-tools" &>/dev/null; then
        echo "xen tools do not installed, so will be installed."
        echo "installing packages"
        sudo apt update &>/dev/null
        apt_updated=1
        sudo apt install -y xen-tools >/dev/null
    fi
    if ! dpkg -s "xen-hypervisor-4.17-amd64" &>/dev/null; then
        echo "xen hypervisor do not installed, so will be installed."
        echo "installing packages"
        if [[ apt_updated != 1 ]]; then
            sudo apt update &>/dev/null
        fi
        sudo apt install -y xen-hypervisor > /dev/null
    fi
 }

# xen-tools requires the classic .list file 
function fixClassicAptList() {
    if [[ "$1" == "--Undo" ]]; then
        sudo mv /etc/apt/sources.list \
        /etc/apt/sources.list.disabled
        sudo apt update
        return 1
    fi
    sudo tee /etc/apt/sources.list >/dev/null <<EOF
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF
    sudo apt update
    # to Undo run with --Undo
}

function createImages() {
    local hostname=$1
    local ip=10.44.44.$2
    local mac=00:16:3e:44:44:$2

    xen-create-image \
    --hostname=$hostname --memory=2gb --vcpus=2 \
    --dir=/var/lib/xen/images --ip=$ip --mac=$mac \
    --pygrub --dist=bullseye --noswap --noaccounts \
    --noboot --nocopyhosts --extension=.pv \
    --fs=ext4 --genpass=0 --passwd --nohosts \
    --bridge=xenlan44 --gateway=10.44.44.1 --netmask=255.255.255.0
    }
function createSomeImages() {
    createImages "master01" 11
    createImages "master02" 12
    createImages "master03" 13
    createImages "worker01" 14
    createImages "worker02" 15
}

isRoot
checkXen
createSomeImages 