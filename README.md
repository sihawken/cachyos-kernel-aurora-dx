# CachyOS-Kernel-Bazzite-Dx

> [!WARNING]
> I built this image for me. You may use it yourself, of course, but I provide no support. I strongly suggest learning how to customize your own image using the [ublue image template](https://github.com/ublue-os/image-template). Documentation can be found [here.](https://blue-build.org/)

My system: Framework 13 Laptop (12th Gen Intel)

Base image: [Bazzite DX](https://bazzite.gg/)

Modifications:
- Replaced kernel with [CachyOS Kernel](https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/)
- [CachyOS ksmd](https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos-addons/)
- [kwin-effects-better-blur-dx](https://copr.fedorainfracloud.org/coprs/infinality/kwin-effects-better-blur-dx/)
- Removed steam in favour of flatpak steam

# Installation instructions:
Install any atomic fedora (Silverblue, Kinoite, Bazzite, Aurora, ... etc)

Run:
`rpm-ostree rebase ostree-image-signed:docker://ghcr.io/sihawken/cachyos-kernel-bazzite-dx`
