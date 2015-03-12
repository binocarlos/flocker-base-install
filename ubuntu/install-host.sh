#!/usr/bin/env bash

# this version is for installing flocker as a python app on the host (not in docker)

export DEBIAN_FRONTEND=noninteractive

export SPL_REPO=${SPL_REPO:=https://github.com/zfsonlinux/spl}
export SPL_COMMIT=${SPL_COMMIT:=47af4b76ffe72457166e4abfcfe23848ac51811a}

export ZFS_REPO=${ZFS_REPO:=https://github.com/zfsonlinux/zfs}
export ZFS_COMMIT=${ZFS_COMMIT:=d958324f97f4668a2a6e4a6ce3e5ca09b71b31d9}

export MACHINIST_VERSION=${MACHINIST_VERSION:=0.2.0}

export FLOCKER_REPO=${FLOCKER_REPO:=https://github.com/clusterhq/flocker}
export FLOCKER_COMMIT=${FLOCKER_COMMIT:=bcc7bb4280629a67b97da7750ca6e513767aad21}

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

# install base deps for flocker - not needed when containerized
flocker-base-install-flocker-deps() {
  apt-get update
  apt-get -y install \
    python-setuptools \
    python-dev
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

# Compile and install spl
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

# download and install machinist - not needed when containerized
flocker-base-install-machinist() {
  echo "Installing Machinist - $MACHINIST_VERSION"
  cd ~/
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

# system config for flocker
flocker-base-install-sysconfig() {
  # make the kernel not panic
  sed -i'backup' s/USE_KDUMP=0/USE_KDUMP=1/g /etc/default/kdump-tools
}

# walk through each stage to do a complete flocker install
flocker-base-install() {
  flocker-base-install-zfs-deps
  flocker-base-install-spl
  flocker-base-install-zfs
  flocker-base-install-flocker-deps
  flocker-base-install-machinist
  flocker-base-install-flocker
  flocker-base-install-sysconfig
}