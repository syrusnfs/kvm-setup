#!/bin/bash
# =====================================================================
#  KVM / QEMU Host Setup & Optimization Script
# =====================================================================
#  Target OS : Debian / Ubuntu / Kali Linux / Parrot OS
#  Purpose   : Install and optimize KVM + virt-manager
#  Author    : Syrus
#  Version   : 1.2 | 2026
#  License   : MIT
# =====================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[+]${RESET} $1"; }
success() { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }

show_banner() {
  clear
  echo -e "${CYAN}=====================================================================${RESET}"
  echo -e "${MAGENTA}  _  ____     ____  __     ___  _____ __  __ _   _ ${RESET}"
  echo -e "${MAGENTA} | |/ /\ \   / /  \/  |   / _ \| ____|  \/  | | | |${RESET}"
  echo -e "${MAGENTA} | ' /  \ \ / /| |\/| |  | | | |  _| | |\/| | | | |${RESET}"
  echo -e "${MAGENTA} | . \   \ V / | |  | |  | |_| | |___| |  | | |_| |${RESET}"
  echo -e "${MAGENTA} |_|\_\   \_/  |_|  |_|   \__\_\_____|_|  |_|\___/ ${RESET}"
  echo -e "${GREEN} VM Automation and Optimization Script | By Syrus    ${RESET}"
  echo -e "${CYAN}=====================================================================${RESET}"
  echo
}

detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID}"
    DISTRO_NAME="${NAME}"
  else
    DISTRO_ID="unknown"
    DISTRO_NAME="Unknown"
  fi
  
  case "$DISTRO_ID" in
    debian|ubuntu|kali|parrot)
      info "Detected distribution: $DISTRO_NAME"
      ;;
    *)
      warn "Distribution '$DISTRO_NAME' may not be fully supported."
      warn "This script is designed for Debian/Ubuntu/Kali/Parrot."
      read -p "Continue anyway? [y/N]: " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi
      ;;
  esac
}

check_root() {
  info "Checking for root privileges..."
  if [ "$EUID" -ne 0 ]; then
    warn "Relaunching with sudo..."
    exec sudo "$0" "$@"
  fi
}

install_kvm() {
  USER_NAME=${SUDO_USER:-$(logname)}
  info "Target user: $USER_NAME"
  
  info "Checking virtualization support (VT-x / SVM)..."
  if ! grep -E -q '(vmx|svm)' /proc/cpuinfo; then
    error "Virtualization not detected. Enable VT-x/SVM in your BIOS."
  fi
  success "Virtualization supported"
  

  info "Updating system packages..."
  apt update
  
  info "Installing KVM/QEMU stack + virt-manager + optimizations..."
  apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager \
    bridge-utils \
    cpu-checker \
    virtinst \
    spice-client-gtk \
    gir1.2-spiceclientgtk-3.0 \
    tuned \
    irqbalance
  
  info "Enabling and starting libvirtd..."
  systemctl enable --now libvirtd
  
  info "Adding user to kvm and libvirt groups..."
  usermod -aG kvm,libvirt "$USER_NAME"
  
  info "Configuring libvirt socket permissions..."
  sed -i 's/^#unix_sock_group = .*/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
  sed -i 's/^#unix_sock_rw_perms = .*/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf
  systemctl restart libvirtd
  
  info "Enabling CPU performance profile..."
  systemctl enable --now tuned
  tuned-adm profile throughput-performance || true
  
  info "Adjusting swappiness and hugepages..."
  cat <<EOF > /etc/sysctl.d/99-kvm.conf
vm.swappiness=10
vm.nr_hugepages=1024
EOF
  sysctl -p /etc/sysctl.d/99-kvm.conf
  
  info "Enabling irqbalance..."
  systemctl enable --now irqbalance

  info "Testing KVM acceleration..."
  if kvm-ok 2>/dev/null | grep -q "KVM acceleration can be used"; then
    success "KVM active and functional"
  else
    warn "KVM installed, but acceleration not confirmed (check BIOS)"
  fi
}

install_cockpit() {
  info "Installing Cockpit for web-based VM management..."
  apt install -y cockpit cockpit-machines
  
  info "Enabling and starting Cockpit..."
  systemctl enable --now cockpit.socket
  
  success "Cockpit installed successfully!"
}

remove_all() {
  warn "This will remove all KVM/QEMU components from your system!"
  warn "All virtual machines and their data may be affected."
  echo
  read -p "Are you sure you want to continue? [y/N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Removal cancelled."
    exit 0
  fi
  
  info "Stopping libvirtd service..."
  systemctl stop libvirtd 2>/dev/null || true
  systemctl disable libvirtd 2>/dev/null || true
  
  info "Stopping tuned service..."
  systemctl stop tuned 2>/dev/null || true
  systemctl disable tuned 2>/dev/null || true
  
  info "Stopping irqbalance service..."
  systemctl stop irqbalance 2>/dev/null || true
  systemctl disable irqbalance 2>/dev/null || true
  
  if dpkg -l | grep -q cockpit; then
    info "Stopping and removing Cockpit..."
    systemctl stop cockpit.socket 2>/dev/null || true
    systemctl disable cockpit.socket 2>/dev/null || true
    apt purge -y cockpit cockpit-machines 2>/dev/null || true
  fi
  
  info "Removing KVM/QEMU packages..."
  apt purge -y \
    qemu-kvm \
    qemu-system-x86 \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager \
    bridge-utils \
    cpu-checker \
    virtinst \
    spice-client-gtk \
    gir1.2-spiceclientgtk-3.0 \
    tuned \
    irqbalance \
    2>/dev/null || true
  
  info "Removing unused dependencies..."
  apt autoremove -y
  
  info "Removing KVM configuration files..."
  rm -f /etc/sysctl.d/99-kvm.conf 2>/dev/null || true
  
  info "Removing user from virtualization groups..."
  USER_NAME=${SUDO_USER:-$(logname)}
  if [ -n "$USER_NAME" ]; then
    gpasswd -d "$USER_NAME" kvm 2>/dev/null || true
    gpasswd -d "$USER_NAME" libvirt 2>/dev/null || true
  fi
  
  echo
  echo -e "${CYAN}=====================================================================${RESET}"
  echo -e "${GREEN} KVM/QEMU REMOVAL COMPLETED SUCCESSFULLY${RESET}"
  echo -e "${CYAN}=====================================================================${RESET}"
  echo
  echo -e "${YELLOW}NOTE:${RESET}"
  echo " - Virtual machine data in /var/lib/libvirt was NOT removed."
  echo " - To completely remove VM data, manually delete /var/lib/libvirt"
  echo " - A system reboot is recommended."
  echo
  echo -e "${CYAN}=====================================================================${RESET}"
}

show_success() {
  local with_cockpit=$1
  
  echo
  echo -e "${CYAN}=====================================================================${RESET}"
  echo -e "${GREEN} HOST INSTALLATION AND OPTIMIZATION COMPLETED SUCCESSFULLY${RESET}"
  echo -e "${CYAN}=====================================================================${RESET}"
  echo
  echo -e "${YELLOW}NEXT STEPS (IMPORTANT):${RESET}"
  echo
  echo " 1) Logout or reboot"
  echo " 2) Run: virt-manager"
  echo
  if [ "$with_cockpit" = true ]; then
    echo -e "${YELLOW}COCKPIT WEB INTERFACE:${RESET}"
    echo "   Access at: https://localhost:9090"
    echo "   Login with your system credentials"
    echo
  fi
  echo " RECOMMENDED VM CONFIGURATION:"
  echo "   - CPU: host-passthrough"
  echo "   - RAM: fixed memory"
  echo "   - Disk: VirtIO + cache writeback"
  echo "   - Network: VirtIO (NAT or Macvtap)"
  echo "   - Video: Virtio + SPICE + 3D"
  echo
  echo " INSIDE THE VM:"
  echo "   sudo apt install spice-vdagent qemu-guest-agent"
  echo "   sudo systemctl enable --now spice-vdagent qemu-guest-agent"
  echo
  echo " QEMU-GUEST-AGENT (IN VIRT-MANAGER):"
  echo "   1) Shut down the VM"
  echo "   2) Details -> Add Hardware -> Channel"
  echo "   3) Name: org.qemu.guest_agent.0"
  echo "   4) Type: unix"
  echo "   5) Save and start the VM"
  echo
  echo -e "${CYAN}=====================================================================${RESET}"
}

show_menu() {
  echo -e "${YELLOW}Select an option:${RESET}"
  echo
  echo -e "  ${GREEN}1)${RESET} Install KVM/QEMU only"
  echo -e "  ${GREEN}2)${RESET} Install KVM/QEMU + Cockpit (web management)"
  echo -e "  ${GREEN}3)${RESET} Remove all KVM/QEMU components"
  echo
  echo -e "  ${RED}0)${RESET} Exit"
  echo
  read -p "Enter your choice [0-3]: " choice
  echo
}

main() {
  show_banner
  check_root "$@"
  detect_distro
  show_menu
  
  case $choice in
    1)
      info "Starting KVM/QEMU installation..."
      install_kvm
      show_success false
      ;;
    2)
      info "Starting KVM/QEMU + Cockpit installation..."
      install_kvm
      install_cockpit
      show_success true
      ;;
    3)
      info "Starting removal process..."
      remove_all
      ;;
    0)
      info "Exiting..."
      exit 0
      ;;
    *)
      error "Invalid option. Please run the script again."
      ;;
  esac
}

main "$@"
