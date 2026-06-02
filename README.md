#  QEMU + Cockpit VM Installer

A simple automated script to install and configure a full virtualization environment on Debian based Linux Distros using **QEMU, KVM, libvirt, and Cockpit** with SPICE support for better VM experience.

---

##  Why I Built This

Setting up virtualization on Linux manually is painful and time-consuming.  
You need to install multiple packages, configure services, fix permissions, and enable features like networking and SPICE manually.

This project was created to automate all of that into a **single easy-to-run script**.

---

##  Features

-  QEMU + KVM full virtualization setup
-  libvirt + bridge networking support
-  Cockpit web-based VM management
-  SPICE support (clipboard + drag & drop)
-  Automatic service enablement
-  User permission setup (libvirt + kvm groups)
-  Ready for Linux + Windows VM environments

---

##  Why It Is Useful

This script helps you:

- Avoid manual configuration errors
- Set up a VM lab in minutes
- Get a working cybersecurity testing environment
- Manage VMs using both CLI and web UI
- Enable performance-optimized virtualization

Perfect for:
- Cybersecurity learners
- Linux users
- Developers
- System administrators

---

##  Installation

```bash
git clone https://github.com/aghaasfandyarkhan/QEMU-COCKPIT-INSTALLER
cd your-repo
chmod +x setup-vm-stack.sh
sudo ./setup-vm-stack.sh
