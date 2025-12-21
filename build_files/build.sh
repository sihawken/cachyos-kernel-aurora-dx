#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

# create a shims to bypass kernel install triggering dracut/rpm-ostree
# seems to be minimal impact, but allows progress on build
cd /usr/lib/kernel/install.d \
&& mv 05-rpmostree.install 05-rpmostree.install.bak \
&& mv 50-dracut.install 50-dracut.install.bak \
&& printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install \
&& printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install \
&& chmod +x  05-rpmostree.install 50-dracut.install

## Install CachyOS kernel
dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra 
#TEST rm -rf /lib/modules/* # Remove kernel files that remain
dnf5 -y install kernel-cachyos kernel-cachyos-devel-matched --allowerasing

dnf5 -y copr enable bieszczaders/kernel-cachyos-addons

## Required to install CachyOS settings
rm -rf /usr/lib/systemd/coredump.conf

## Install KSMD and CachyOS-Settings
dnf5 -y install libcap-ng libcap-ng-devel procps-ng procps-ng-devel
#TEST dnf5 -y install cachyos-settings cachyos-ksm-settings --allowerasing

## Enable KSMD
tee "/usr/lib/systemd/system/ksmd.service" > /dev/null <<EOF
[Unit]
Description=Activates Kernel Samepage Merging
ConditionPathExists=/sys/kernel/mm/ksm

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/ksmctl -e
ExecStop=/usr/bin/ksmctl -d

[Install]
WantedBy=multi-user.target
EOF

ln -s /usr/lib/systemd/system/ksmd.service /etc/systemd/system/multi-user.target.wants/ksmd.service

# Install bore configurations
dnf5 -y install bore-sysctl

## Install the Kwin better blur packages
# dnf5 -y copr enable infinality/kwin-effects-better-blur-dx
# dnf5 -y install kwin-effects-better-blur-dx

# restore kernel install
mv -f 05-rpmostree.install.bak 05-rpmostree.install \
&& mv -f 50-dracut.install.bak 50-dracut.install
cd -

# Regen initramfs
releasever=$(/usr/bin/rpm -E %fedora)
basearch=$(/usr/bin/arch)
KERNEL_VERSION=$(dnf list kernel-cachyos -q | awk '/kernel-cachyos/ {print $2}' | head -n 1 | cut -d'-' -f1)-cachyos1.fc${releasever}.${basearch}
# Ensure Initramfs is generated
depmod -a ${KERNEL_VERSION}
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"

## CLEAN UP
# Clean up dnf cache to reduce image size
dnf5 -y clean all