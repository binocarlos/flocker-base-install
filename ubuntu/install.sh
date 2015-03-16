#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

export FLOCKER_COMMIT=${FLOCKER_COMMIT:=bcc7bb4280629a67b97da7750ca6e513767aad21}
export FLOCKER_REPO=${FLOCKER_REPO:=https://github.com/clusterhq/flocker}

export MACHINIST_VERSION=${MACHINIST_VERSION:=0.2.0}

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
flocker-base-install-deps() {
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
  cd /srv
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
  cd /srv
  git clone $ZFS_REPO
  cd zfs
  git checkout $ZFS_COMMIT
  ./autogen.sh
  ./configure
  make
  make deb
  sudo dpkg -i *.deb
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

## THESE ARE ONLY FOR INSTALLING FLOCKER ON THE HOST

# download and install machinist - not needed when containerized
flocker-base-install-machinist() {
  echo "Installing Machinist - $MACHINIST_VERSION"
  cd /srv
  wget https://pypi.python.org/packages/source/m/machinist/machinist-$MACHINIST_VERSION.tar.gz
  tar zxfv machinist-$MACHINIST_VERSION.tar.gz
  cd machinist-$MACHINIST_VERSION
  python setup.py install
}

# clone and install flocker - not needed when containerized
flocker-base-install-flocker() { 
  echo "Installing Flocker - $FLOCKER_REPO - $FLOCKER_COMMIT"
  cd /opt
  git clone $FLOCKER_REPO
  cd flocker
  git checkout $FLOCKER_COMMIT
  python setup.py install
}

# walk through each stage to do a complete flocker install
flocker-base-install() {
  flocker-base-install-deps
  flocker-base-install-spl
  flocker-base-install-zfs
  flocker-base-install-sysconfig
  flocker-base-install-setup-zfs-pool
}