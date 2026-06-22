#!/usr/bin/env zsh
autoload -U colors && colors
set -e

# ------------------------------------------------------------------------------
#  FULL QEMU/KVM + SPICE + Cockpit Setup - Intelligent Installer / Uninstaller
#  Option 1: Install (detects package manager, reinstalls freshly if present)
#  Option 2: Uninstall (full purge + reset)
# ------------------------------------------------------------------------------

# Color definitions
RED="$fg_bold[red]"
GREEN="$fg_bold[green]"
YELLOW="$fg_bold[yellow]"
BLUE="$fg_bold[blue]"
CYAN="$fg_bold[cyan]"
RESET="$reset_color"
BOLD="$fg_bold[white]"
BG_BLUE="$bg[blue]"

# Helper: print colored message
print_msg() {
    local color="$1"
    local msg="$2"
    echo -e "${color}${msg}${RESET}"
}

# ------------------------------------------------------------------------------
# Root check (needed for both install & uninstall)
if [ "$EUID" -ne 0 ]; then
    print_msg "$RED" "ERROR: Please run as root (use sudo)."
    exit 1
fi

# ------------------------------------------------------------------------------
# Global variables for package manager detection
declare -a INSTALL_CMD
declare -a REINSTALL_CMD
PKG_MANAGER=""

detect_pkg_manager() {
    if command -v nala &>/dev/null; then
        PKG_MANAGER="nala"
        INSTALL_CMD=(nala install -y)
        REINSTALL_CMD=(nala install --fix-broken -y)
        print_msg "$GREEN" "✔ Using nala package manager"
    elif command -v aptitude &>/dev/null; then
        PKG_MANAGER="aptitude"
        INSTALL_CMD=(aptitude install -y)
        REINSTALL_CMD=(aptitude reinstall -y)
        print_msg "$GREEN" "✔ Using aptitude package manager"
    elif command -v apt &>/dev/null; then
        PKG_MANAGER="apt"
        INSTALL_CMD=(apt install -y)
        REINSTALL_CMD=(apt install --reinstall -y)
        print_msg "$GREEN" "✔ Using apt package manager"
    else
        print_msg "$RED" "ERROR: No supported package manager found (nala, aptitude, apt)."
        exit 1
    fi
}

# Helper: install or reinstall a list of packages
install_or_reinstall() {
    local pkg_list=("$@")
    local missing_pkgs=()
    local installed_pkgs=()

    for pkg in "${pkg_list[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            installed_pkgs+=("$pkg")
        else
            missing_pkgs+=("$pkg")
        fi
    done

    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        print_msg "$YELLOW" "→ Installing missing packages: ${missing_pkgs[*]}"
        if [[ "$PKG_MANAGER" == "aptitude" ]]; then
            aptitude install -y "${missing_pkgs[@]}"
        else
            "${INSTALL_CMD[@]}" "${missing_pkgs[@]}"
        fi
    fi

    if [[ ${#installed_pkgs[@]} -gt 0 ]]; then
        print_msg "$CYAN" "→ Reinstalling existing packages (freshly): ${installed_pkgs[*]}"
        case "$PKG_MANAGER" in
            nala|apt)
                "${REINSTALL_CMD[@]}" "${installed_pkgs[@]}"
                ;;
            aptitude)
                for pkg in "${installed_pkgs[@]}"; do
                    "${REINSTALL_CMD[@]}" "$pkg"
                done
                ;;
        esac
    fi
}

# ------------------------------------------------------------------------------
# Package lists
CORE_PKGS=(
    qemu-system libvirt-daemon-system libvirt-clients
    bridge-utils virt-manager virtinst cpu-checker virtiofsd
)
COCKPIT_PKGS=(
    cockpit cockpit-machines
)
SPICE_PKGS=(
    spice-vdagent spice-client-gtk virt-viewer qemu-utils spice-webdavd
)
ALL_PKGS=("${CORE_PKGS[@]}" "${COCKPIT_PKGS[@]}" "${SPICE_PKGS[@]}")

# ------------------------------------------------------------------------------
# INSTALLATION FUNCTION (original logic, unchanged)
install_environment() {
    clear
    print_msg "$BLUE" "
========================================
  FULL QEMU/KVM + SPICE + Cockpit Setup
   (Intelligent Reinstall Mode)
========================================
"

    print_msg "$CYAN" "[1/7] Updating system packages..."
    if [[ "$PKG_MANAGER" == "nala" ]]; then
        nala update && nala upgrade -y
    elif [[ "$PKG_MANAGER" == "aptitude" ]]; then
        aptitude update && aptitude upgrade -y
    else
        apt update && apt upgrade -y
    fi

    print_msg "$CYAN" "[2/7] Processing virtualization stack (fresh reinstall if present)..."
    install_or_reinstall "${ALL_PKGS[@]}"

    print_msg "$CYAN" "[3/7] Enabling required services..."
    systemctl enable --now libvirtd
    systemctl enable --now cockpit.socket

    print_msg "$CYAN" "[4/7] Adding user to virtualization groups..."
    USER_NAME="${SUDO_USER:-$USER}"
    usermod -aG libvirt "$USER_NAME"
    usermod -aG kvm "$USER_NAME"

    print_msg "$CYAN" "[5/7] Validating installation..."

    if kvm-ok | grep -q "KVM acceleration can be used"; then
        print_msg "$GREEN" "  ✓ KVM acceleration is active"
    else
        print_msg "$YELLOW" "  ⚠ KVM acceleration not available (check BIOS settings)"
    fi

    if systemctl is-active --quiet libvirtd; then
        print_msg "$GREEN" "  ✓ libvirtd is running"
    else
        print_msg "$RED" "  ✗ libvirtd failed to start"
    fi

    if systemctl is-active --quiet cockpit.socket; then
        print_msg "$GREEN" "  ✓ cockpit.socket is active"
    else
        print_msg "$RED" "  ✗ cockpit.socket failed"
    fi

    if command -v spice-vdagent &>/dev/null; then
        print_msg "$GREEN" "  ✓ SPICE tools available"
    else
        print_msg "$YELLOW" "  ⚠ spice-vdagent not found (install inside guest OS later)"
    fi

    print_msg "$BG_BLUE$BOLD" "
========================================
 INSTALLATION COMPLETE
========================================
"
    print_msg "$GREEN" "✔ Cockpit UI: https://localhost:9090"
    print_msg "$GREEN" "✔ Virt-Manager (GUI application available)"
    echo ""
    print_msg "$BOLD" " IMPORTANT POST-SETUP STEPS:"
    print_msg "$YELLOW" "1. Reboot OR log out and log back in (group changes)."
    print_msg "$YELLOW" "2. In VM settings, enable SPICE display and clipboard sharing."
    print_msg "$YELLOW" "3. Inside each guest OS, install 'spice-vdagent' for drag/drop & clipboard."
    echo ""
    print_msg "$BOLD" " FEATURES ENABLED:"
    print_msg "$CYAN" "- Drag & Drop (SPICE)"
    print_msg "$CYAN" "- Clipboard sharing"
    print_msg "$CYAN" "- VirtIO performance drivers"
    print_msg "$CYAN" "- Cockpit web management"
    echo ""
    print_msg "$BLUE" "Script made by GeoKing®"
    print_msg "$RESET"
}

# ------------------------------------------------------------------------------
# UNINSTALL FUNCTION (full purge + reset)
uninstall_environment() {
    clear
    print_msg "$RED" "
========================================
   FULL PURGE: QEMU/KVM + SPICE + Cockpit
========================================
"
    print_msg "$YELLOW" "WARNING: This will remove all virtualization packages,"
    print_msg "$YELLOW" "remove user from libvirt/kvm groups, delete VM configs,"
    print_msg "$YELLOW" "and purge related system data. This action is IRREVERSIBLE."
    echo ""
    read -q "REPLY?Type 'yes' to confirm full uninstall: "
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        print_msg "$RED" "Uninstall cancelled."
        exit 0
    fi

    print_msg "$CYAN" "[1/6] Stopping and disabling services..."
    systemctl stop libvirtd cockpit.socket 2>/dev/null || true
    systemctl disable libvirtd cockpit.socket 2>/dev/null || true

    print_msg "$CYAN" "[2/6] Removing virtualization packages..."
    if [[ "$PKG_MANAGER" == "nala" ]]; then
        nala remove --purge -y "${ALL_PKGS[@]}" 2>/dev/null || true
        nala autoremove -y
    elif [[ "$PKG_MANAGER" == "aptitude" ]]; then
        aptitude remove --purge -y "${ALL_PKGS[@]}" 2>/dev/null || true
        aptitude autoremove -y
    else
        apt remove --purge -y "${ALL_PKGS[@]}" 2>/dev/null || true
        apt autoremove -y
    fi

    print_msg "$CYAN" "[3/6] Removing residual configuration files and data..."
    rm -rf /etc/libvirt/ /var/lib/libvirt/ /etc/cockpit/ /var/lib/cockpit/
    rm -rf ~/.config/libvirt/ ~/.local/share/libvirt/ ~/.cache/virt-manager/
    rm -rf /var/log/libvirt/ /var/log/cockpit/

    print_msg "$CYAN" "[4/6] Removing user from virtualization groups..."
    USER_NAME="${SUDO_USER:-$USER}"
    deluser "$USER_NAME" libvirt 2>/dev/null || true
    deluser "$USER_NAME" kvm 2>/dev/null || true

    print_msg "$CYAN" "[5/6] Cleaning package manager leftovers..."
    if [[ "$PKG_MANAGER" == "nala" ]]; then
        nala clean
    elif [[ "$PKG_MANAGER" == "aptitude" ]]; then
        aptitude clean
    else
        apt clean
    fi

    print_msg "$CYAN" "[6/6] Removing optional dependencies that were auto-installed..."
    if [[ "$PKG_MANAGER" == "nala" ]]; then
        nala autopurge -y 2>/dev/null || true
    elif [[ "$PKG_MANAGER" == "aptitude" ]]; then
        aptitude purge ~c 2>/dev/null || true
    else
        apt autoremove --purge -y 2>/dev/null || true
    fi

    print_msg "$GREEN" "
========================================
 UNINSTALL COMPLETE
========================================
"
    print_msg "$YELLOW" "System has been fully purged of QEMU/KVM, Cockpit, and SPICE tools."
    print_msg "$YELLOW" "A reboot is recommended to clean up any remaining kernel modules."
    print_msg "$BLUE" "Script made by GeoKing®"
    print_msg "$RESET"
}

# ------------------------------------------------------------------------------
# MAIN MENU
main_menu() {
    print_msg "$BLUE" "
========================================
  QEMU/KVM + Cockpit Environment Manager
========================================
"
    echo "1) Install Virtual Environment (QEMU + Cockpit)"
    echo "2) Uninstall / Full Purge"
    echo "0) Exit"
    echo ""
    read "choice?Select option [0-2]: "

    case $choice in
        1)
            detect_pkg_manager
            install_environment
            ;;
        2)
            detect_pkg_manager   # needed for uninstall commands
            uninstall_environment
            ;;
        0)
            print_msg "$GREEN" "Exiting."
            exit 0
            ;;
        *)
            print_msg "$RED" "Invalid option. Exiting."
            exit 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Run the menu
main_menu
