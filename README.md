# KVM - QEMU - COCKPIT Setup Script

![Bash](https://img.shields.io/badge/Bash-5.0+-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![KVM](https://img.shields.io/badge/KVM-Virtualization-FF6600?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

Automated script for installing and optimizing KVM/QEMU/Cockpit Project virtualization on Debian-based Linux distributions.

## Features

- Interactive menu-based installation
- CPU performance tuning, hugepages, and IRQ balancing
- Optional Cockpit web interface for VM management
- Clean uninstallation option
- Multi-distro support: Debian, Ubuntu, Kali, Parrot

## Requirements

- **CPU**: Intel VT-x or AMD-V enabled in BIOS
- **RAM**: 4GB minimum (8GB+ recommended)
- **OS**: Debian, Ubuntu, Kali Linux, or Parrot OS

## Installation

```bash
git clone https://github.com/syrusnfs/kvm-setup.git
cd kvm-setup
chmod +x kvm-setup.sh
sudo ./kvm-setup.sh

```

## Usage

Run the script and select from the menu:

```
1) Install KVM/QEMU only
2) Install KVM/QEMU + Cockpit (web management)
3) Remove all KVM/QEMU components
0) Exit
```

Cockpit web interface is available at `https://localhost:9090` after option 2.

## Performance Tweaks Applied

The script automatically applies these optimizations:

| Tweak | Value | Purpose |
|-------|-------|---------|
| Swappiness | `vm.swappiness=10` | Reduces swap usage for better VM performance |
| Hugepages | `vm.nr_hugepages=1024` | Pre-allocates large memory pages for VMs |
| CPU Profile | `throughput-performance` | Optimizes CPU for maximum throughput |
| IRQ Balance | `irqbalance` enabled | Distributes hardware interrupts across CPUs |

Configuration file created: `/etc/sysctl.d/99-kvm.conf`

## Packages Installed

- `qemu-kvm` - Core KVM virtualization
- `libvirt-daemon-system` - Virtualization API daemon
- `libvirt-clients` - Command-line tools
- `virt-manager` - GUI for managing VMs
- `bridge-utils` - Network bridging utilities
- `virtinst` - VM provisioning tools
- `spice-client-gtk` - SPICE display protocol
- `tuned` - System performance tuning
- `irqbalance` - IRQ distribution optimization
- `cockpit` + `cockpit-machines` - Web management (option 2 only)

## Recommended VM Settings

| Component | Setting |
|-----------|---------|
| CPU | host-passthrough |
| RAM | Fixed allocation |
| Disk | VirtIO + cache writeback |
| Network | VirtIO (NAT or Macvtap) |
| Video | Virtio + SPICE + 3D |

### Guest VM Setup

```bash
sudo apt install spice-vdagent qemu-guest-agent
sudo systemctl enable --now spice-vdagent qemu-guest-agent
```

## Troubleshooting

**Virtualization not detected**: Enable VT-x/AMD-V in BIOS settings.

**Permission denied**: Logout and login again, or run `newgrp libvirt`.

## Autor

**Syrus | 2026** 

## License

MIT License - see [LICENSE](LICENSE) for details.
