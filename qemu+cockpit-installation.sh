#!/usr/bin/env zsh
autoload -U colors && colors

set -e

echo -e "$fg_bold[blue]"
echo "========================================"
echo "  FULL QEMU/KVM + SPICE + Cockpit Setup"
echo "========================================"
echo -e "$reset_color"

# Root check
if [ "$EUID" -ne 0 ]; then
    echo "Run as root (sudo)"
    exit 1
fi

echo "[1/6] Updating system..."
apt update && apt upgrade -y

echo "[2/6] Installing core virtualization stack..."
apt install -y \
    qemu-kvm \
    qemu-system \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    virtinst \
    cpu-checker

echo "[3/6] Installing Cockpit + VM management..."
apt install -y \
    cockpit \
    cockpit-machines

echo "[4/6] Installing SPICE + drag-drop + clipboard tools..."
apt install -y \
    spice-vdagent \
    spice-client-gtk \
    virt-viewer \
    qemu-utils

echo "[5/6] Enabling services..."
systemctl enable --now libvirtd
systemctl enable --now cockpit.socket

echo "[6/6] Adding user to virtualization groups..."
USER_NAME=${SUDO_USER:-$USER}

usermod -aG libvirt "$USER_NAME"
usermod -aG kvm "$USER_NAME"


echo -e "$bg[blue]$fg_bold[white]"
echo "========================================"
echo " INSTALLATION COMPLETE"
echo "========================================"
echo ""
echo "✔ Cockpit UI: https://localhost:9090"
echo "✔ Virt-Manager (GUI app)"
echo ""
echo " IMPORTANT (VERY IMPORTANT):"
echo "1. Reboot system OR logout/login"
echo "2. Enable SPICE in VM display settings"
echo "3. Install 'spice-vdagent' inside guest OS"
echo ""
echo " FEATURES ENABLED:"
echo "- Drag & Drop (SPICE)"
echo "- Clipboard sharing"
echo "- Better network virtualization"
echo "- VirtIO performance drivers"
echo -e "$reset_color"
