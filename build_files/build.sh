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
dnf5 -y install kernel-cachyos kernel-cachyos-devel-matched --allowerasing

## Install CachyOS addon packages
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons
dnf5 -y install libcap-ng libcap-ng-devel procps-ng procps-ng-devel
dnf5 -y install uksmd

tee "/usr/lib/systemd/system/uksmd.service" > /dev/null <<EOF
[Unit]
Description=Userspace KSM helper daemon
Documentation=https://codeberg.org/pf-kernel/uksmd
ConditionPathExists=/sys/kernel/process_ksm/process_ksm_enable
ConditionPathExists=/sys/kernel/process_ksm/process_ksm_disable
ConditionPathExists=/sys/kernel/process_ksm/process_ksm_status

[Service]
Type=notify
DynamicUser=true
User=uksmd
Group=uksmd
CapabilityBoundingSet=CAP_SYS_PTRACE CAP_DAC_OVERRIDE CAP_SYS_NICE
AmbientCapabilities=CAP_SYS_PTRACE CAP_DAC_OVERRIDE CAP_SYS_NICE
PrivateNetwork=yes
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=true
PrivateDevices=true
NoNewPrivileges=true
PrivateTmp=true
ProtectClock=true
ProtectControlGroups=true
ProtectHome=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ReadWritePaths=/sys/kernel/mm/ksm/run
ProtectSystem=strict
RestrictSUIDSGID=true
SystemCallArchitectures=native
RestrictRealtime=true
LockPersonality=true
MemoryDenyWriteExecute=true
RemoveIPC=true
TasksMax=1
UMask=0066
ProtectHostname=true
IPAddressDeny=any
SystemCallFilter=~@clock @debug @module @mount @raw-io @reboot @swap @privileged @resources @cpu-emulation @obsolete
SystemCallFilter=setpriority set_mempolicy
WatchdogSec=30
Restart=on-failure
ExecStart=/usr/bin/uksmd

[Install]
WantedBy=multi-user.target
EOF

ln -s /usr/lib/systemd/system/uksmd.service /etc/systemd/system/multi-user.target.wants/uksmd.service

rm -rf /usr/lib/systemd/coredump.conf
dnf5 -y install cachyos-settings --allowerasing

## Install the Kwin better blur packages
dnf5 -y copr enable infinality/kwin-effects-better-blur-dx
dnf5 -y install kwin-effects-better-blur-dx
dnf5 -y install kwin-effects-better-blur-dx-x11

# restore kernel install
mv -f 05-rpmostree.install.bak 05-rpmostree.install \
&& mv -f 50-dracut.install.bak 50-dracut.install
cd -

# Regen initramfs
releasever=$(/usr/bin/rpm -E %fedora)
basearch=$(/usr/bin/arch)
KERNEL_VERSION=$(dnf list kernel-cachyos -q | awk '/kernel-cachyos/ {print $2}' | head -n 1 | cut -d'-' -f1)-cachyos1
# Ensure Initramfs is generated
depmod -a ${KERNEL_VERSION}.fc${releasever}.${basearch}
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"

## CLEAN UP
# Clean up dnf cache to reduce image size
dnf5 -y clean all