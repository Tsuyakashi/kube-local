#!/bin/bash

KUBE_PASSWORD="root123"

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
    sudo mv /etc/apt/sources.list.d/ubuntu.sources \
        /etc/apt/sources.list.d/ubuntu.sources.disabled
    sudo apt update
    # to Undo run with --Undo
}

function createImages() {
    local hostname=$1
    local ip=10.44.44.$2
    local mac=00:16:3e:44:44:$2

    if ! -f /etc/xen/$hostname.pv; then
        xen-create-image \
        --hostname=$hostname --memory=2gb --vcpus=2 \
        --dir=/var/lib/xen/images --ip=$ip --mac=$mac \
        --pygrub --dist=bullseye --noswap --noaccounts \
        --noboot --nocopyhosts --extension=.pv \
        --fs=ext4 --genpass=0 --password=$KUBE_PASSWORD --nohosts \
        --bridge=xenlan44 --gateway=10.44.44.1 --netmask=255.255.255.0
    fi
}

function createSomeImages() {
    createImages "master01" 11
    createImages "master02" 12
    createImages "master03" 13
    createImages "worker01" 14
    createImages "worker02" 15
}

function addLocaltime() {
    local hostname=$1

    echo "localtime = 1" | sudo tee /etc/xen/$hostname.pv >/dev/null
}

function addSomeLocaltime() {
    addLocaltime "master01" 
    addLocaltime "master02" 
    addLocaltime "master03" 
    addLocaltime "worker01" 
    addLocaltime "worker02" 
}

function getUbuntuVm(){
    # add git exist check
    [ ! -d kvm-on-machine ] && git clone https://github.com/Tsuyakashi/kvm-on-machine.git
    cd kvm-on-machine
    chmod +x ./quickstart.sh
    sudo ./quickstart.sh --ubuntu --full

    cd ..
}


VM_NAME=ubuntu-noble

function connectWithSSH() {
    if ! virsh domifaddr $VM_NAME | grep "ipv4" &>/dev/null; then
        echo "vm did not start"
        exit
    fi 
    VM_IP=$(virsh domifaddr $VM_NAME | awk '/ipv4/ { split($4, a, "/"); print a[1] }')
    chmod 600 kvm-on-machine/keys/rsa.key
    scp -i kvm-on-machine/keys/rsa.key \
        -o StrictHostKeyChecking=accept-new \
        ./quickstart.sh \
        ubuntu@$VM_IP:~/ 
    ssh -t -i kvm-on-machine/keys/rsa.key \
        -o StrictHostKeyChecking=accept-new \
        ubuntu@$VM_IP \
        "IS_VM=1 sudo -E ./quickstart.sh" 
    
}

if [[ "$IS_VM" == "1" ]]; then
    isRoot
    fixClassicAptList
    checkXen
    createSomeImages
else
    isRoot

    if ! virsh list | grep "$VM_NAME" &>/dev/null; then
        getUbuntuVm
    fi
    
    connectWithSSH
fi