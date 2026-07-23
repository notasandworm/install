---
name: kvm-test-runner
description: Instructions for AI agents to spin up instant ephemeral KVM virtual machines using test-vm to safely test post-install scripts and shell commands in isolated Debian 12, Debian 13, and Arch Linux environments.
---

# KVM Ephemeral Test Runner Skill

Use this skill when you need to test bash scripts, post-installation procedures, systemd service setups, APT/Pacman packages, or network/UFW configurations in a clean, isolated hardware-accelerated Linux VM.

## Overview
The `test-vm` utility spins up an instant QEMU/KVM virtual machine using Copy-on-Write (CoW) disk overlays. Tests execute in 2-4 seconds without modifying the host system or altering base cloud images.

## Supported Distributions
- `debian12` (Debian 12 Bookworm - Stable)
- `debian13` (Debian 13 Trixie - Testing)
- `arch` (Arch Linux - Rolling)

## Common Usage Patterns

### 1. Test a Local Script File
To test a script modified in the local workspace:
```bash
./bin/test-vm run --os debian12 --script bin/deb/dev.sh
```

### 2. Test a Remote Single-Line `curl | bash` Command
To test a remote deployment URL:
```bash
./bin/test-vm run --os debian12 --url https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/vnc.sh
```

### 3. Spin Up an Interactive Session
To interactively debug inside a clean VM via SSH:
```bash
./bin/test-vm interactive --os debian12
```

## How It Works
1. Creates a temporary 20GB QCOW2 Copy-on-Write overlay (`< 10ms`).
2. Attaches a Cloud-Init seed ISO containing auto-configured SSH keys.
3. Boots `qemu-system-x86_64` headlessly with `-enable-kvm` and SSH port forwarding (`localhost:2222`).
4. Executes the script over SSH, streaming stdout/stderr back to the terminal.
5. Automatically terminates the VM process and deletes temporary overlay files upon completion.
