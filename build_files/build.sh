#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## Install CachyOS kernel
dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y install kernel-cachyos kernel-cachyos-devel-matched --allowerasing

## Install CachyOS addon packages
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons
dnf5 -y install libcap-ng libcap-ng-devel procps-ng procps-ng-devel
dnf5 -y install uksmd

## Install the Kwin better blur packages
dnf5 -y copr enable infinality/kwin-effects-better-blur-dx
dnf5 -y install kwin-effects-better-blur-dx
dnf5 -y install kwin-effects-better-blur-dx-x11

# Regen initramfs
KERNEL_VERSION=$(dnf list kernel-cachyos -q | awk '/kernel-cachyos/ {print $2}' | head -n 1 | cut -d'-' -f1)-cachyos
# Ensure Initramfs is generated
depmod -a ${KERNEL_VERSION}
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"