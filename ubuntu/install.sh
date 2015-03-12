#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

export SPL_REPO=${SPL_REPO:=https://github.com/zfsonlinux/spl}
export SPL_COMMIT=${SPL_COMMIT:=47af4b76ffe72457166e4abfcfe23848ac51811a}

export ZFS_REPO=${ZFS_REPO:=https://github.com/zfsonlinux/zfs}
export ZFS_COMMIT=${ZFS_COMMIT:=d958324f97f4668a2a6e4a6ce3e5ca09b71b31d9}

export ZFS_POOL_NAME=${ZFS_POOL_NAME:=flocker}

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# get the system ready for the installation
# this includes:
#
#   * apt-get update
#   * apt-get install deps
#
flocker-base-install-zfs-deps() {
  apt-get update
  apt-get -y install \
    build-essential \
    gawk \
    alien \
    fakeroot \
    linux-headers-$(uname -r) \
    zlib1g-dev \
    uuid-dev \
    libblkid-dev \
    libselinux-dev \
    parted \
    lsscsi \
    dh-autoreconf \
    linux-crashdump \
    git
}

# Compile and install spl
flocker-base-install-spl() {
  echo "Installing SPL - $SPL_REPO - $SPL_COMMIT"
  cd ~/
  git clone $SPL_REPO
  cd spl
  git checkout $SPL_COMMIT
  ./autogen.sh
  ./configure
  make
  make deb
  sudo dpkg -i *.deb
}

# Compile and install zfs
flocker-base-install-zfs() {
  echo "Installing ZFS - $ZFS_REPO - $ZFS_COMMIT"
  cd ~/
  git clone $ZFS_REPO
  cd zfs
  git checkout $ZFS_COMMIT
  ./autogen.sh
  ./configure
  make
  make deb
  sudo dpkg -i *.deb
}

# install docker
flocker-base-install-docker() {
  echo "Installing docker"
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
  echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get -y install lxc-docker
}

flocker-base-install-flocker-control() { 
  echo "Install flocker-control"
  docker pull lmarsden/flocker-control
}

flocker-base-install-flocker-zfs-agent() { 
  echo "Install flocker-zfs-agent"
  docker pull lmarsden/flocker-zfs-agent
}

# system config for flocker
flocker-base-install-sysconfig() {
  # make the kernel not panic
  sed -i'backup' s/USE_KDUMP=0/USE_KDUMP=1/g /etc/default/kdump-tools
}

# setup the ZFS pool once zfs has been installed
flocker-base-install-setup-zfs-pool() {
  if [[ -b /dev/xvdb ]]; then
      echo "Detected EBS environment, setting up real zpool..."
      umount /mnt # this is where xvdb is mounted by default
      zpool create $ZFS_POOL_NAME /dev/xvdb
  elif [[ ! -b /dev/sdb ]]; then
      echo "Setting up a toy zpool..."
      truncate -s 10G /$ZFS_POOL_NAME-datafile
      zpool create $ZFS_POOL_NAME /$ZFS_POOL_NAME-datafile
  fi
}

# walk through each stage to do a complete flocker install
flocker-base-install() {
  flocker-base-install-zfs-deps
  flocker-base-install-spl
  flocker-base-install-zfs
  flocker-base-install-docker
  flocker-base-install-sysconfig
  flocker-base-install-setup-zfs-pool
}