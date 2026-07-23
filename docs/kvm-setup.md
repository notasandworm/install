# QEMU / KVM Virtualization & Ephemeral Testing Setup

This document outlines how to configure a lightweight, hardware-accelerated QEMU/KVM virtual machine testing environment on Debian/Ubuntu and Arch Linux. 

Rather than running heavy, slow interactive installer ISOs, we use pre-baked distribution cloud images combined with **Cloud-Init** and **Copy-on-Write (CoW) overlays** to boot fresh, clean OS instances in 2-4 seconds.

---

## Technical Architecture

The virtualization harness (`bin/qemu-vm`) runs entirely in user-space (no system daemon overhead or root service management required) using the following stack:

1. **Base Cloud Images**: Official, pre-installed generic QCOW2 cloud disk images downloaded directly from distribution mirrors (Debian 12/13, Arch Linux) and cached locally at `~/.cache/qemu-test-images/`.
2. **Copy-on-Write (CoW) Overlays**: For every test run, a thin overlay is created:
   ```bash
   qemu-img create -f qcow2 -b base.qcow2 -F qcow2 overlay.qcow2 20G
   ```
   All VM writes are redirected to this overlay file. Resetting or tearing down the VM simply requires terminating the QEMU process and deleting the overlay file (completes in `< 10ms`).
3. **NoCloud Seed Drive**: Cloud-Init configuration is passed to the guest VM via a secondary virtual CD-ROM drive containing `user-data` and `meta-data` files packaged into a seed ISO.
4. **User-Mode Networking**: VM network is configured using QEMU user-mode SLIRP networking with port forwarding to enable local SSH access:
   ```bash
   -netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=n1
   ```

---

## Setup & Provisioning

### Host Dependencies Installation
Run the appropriate post-install script depending on your host OS. These scripts verify hardware support, configure group permissions for non-root KVM access, install the required QEMU and cloud utilities, and cache base cloud images:

* **Debian/Ubuntu Hosts**:
  ```bash
  ./bin/deb/kvm.sh
  ```
  *(Installs `qemu-system-x86`, `qemu-utils`, `cloud-image-utils`, `genisoimage`)*

* **Arch Linux Hosts**:
  ```bash
  ./bin/arch/kvm.sh
  ```
  *(Installs `qemu-desktop`, `qemu-img`, `cloud-utils`, `cdrtools`)*

---

## VM Runner CLI (`qemu-vm`)

Once provisioning is complete, you can interact with VMs using `qemu-vm`.

### Common Commands

* **Run a local script inside a clean guest VM and exit**:
  ```bash
  qemu-vm run --os debian12 --script bin/deb/dev.sh
  ```
* **Run a remote script via curl inside a guest VM**:
  ```bash
  qemu-vm run --os debian13 --url https://raw.githubusercontent.com/.../hardening.sh
  ```
* **Spin up a clean VM and drop into an interactive SSH shell**:
  ```bash
  qemu-vm interactive --os arch
  ```
* **Clean up cached base cloud images**:
  ```bash
  qemu-vm clean
  ```

---

## Troubleshooting: Nested KVM (Proxmox VE Hosts)

If you run the setup script inside a VM managed by Proxmox PVE and get the warning `⚠️ Warning: /dev/kvm was not detected`, you need to enable nested virtualization.

### 1. Enable Nested Virtualization on PVE Host
SSH into your physical Proxmox host and check module parameters:
* **Intel CPUs**:
  ```bash
  cat /sys/module/kvm_intel/parameters/nested
  # If N/0, run:
  echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm_intel.conf
  sudo reboot
  ```
* **AMD CPUs**:
  ```bash
  cat /sys/module/kvm_amd/parameters/nested
  # If 0, run:
  echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm_amd.conf
  sudo reboot
  ```

### 2. Configure VM CPU Type
In Proxmox, CPU virtualization extensions must be explicitly passed through to the VM:
1. Log in to the Proxmox Web GUI.
2. Go to your VM -> **Hardware** -> **Processor (CPU)** -> **Edit**.
3. Set the CPU **Type** dropdown to **`host`** (or check *Enable Nested Virtualization*).
4. Click **OK**.
5. **Stop and Start** (cold reboot) the VM to apply the new CPU topology.
