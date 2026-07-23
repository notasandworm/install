# Post-Install Provisioning & Hardening Suite

I built this modular post-installation repository to automate provisioning, baseline security setup, human device interaction toolkits, and secure remote headless desktop environments across my Debian, Ubuntu, and Arch Linux workstations and servers.

---

## Single-Line Remote Execution

You can run any full provisioning module remotely via `curl`:

```bash
# Secure Headless Desktop & noVNC Suite
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/vnc.sh | bash

# Human Device Interaction Suite (HDI)
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/hdi.sh | bash

# Developer Workstation & Tooling
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/dev.sh | bash

# Server Hardening & Security Baseline
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/hardening.sh | bash

# Samba Storage Server Host
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/samba-srv.sh | bash

# QEMU / KVM Virtualization & AI Test Harness (Debian/Ubuntu)
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/kvm.sh | bash

# QEMU / KVM Virtualization & AI Test Harness (Arch Linux)
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/arch/kvm.sh | bash

# CIFS Mount Client
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/samba-cli.sh | bash
```

---

## Quick Shell Configuration Only (`.zshrc`)

If you only need to fetch and deploy my custom `.zshrc` shell configuration:

```bash
# Fetch and overwrite ~/.zshrc directly from GitHub
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/.zshrc -o ~/.zshrc
```

Or to safely back up your existing `.zshrc` first before overwriting:

```bash
[ -f ~/.zshrc ] && cp ~/.zshrc ~/.zshrc.bak.$(date +%Y%m%d%H%M%S); curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/.zshrc -o ~/.zshrc
```

---

## Modules Overview

### 1. Secure Headless Desktop & noVNC Web Suite (`bin/deb/vnc.sh`)
Provisions an isolated HTML5 web desktop environment:
- **Core Desktop Stack**: Installs `xvfb`, `x11-utils`, `x11vnc`, `novnc`, and `websockify`. Binds VNC (`5900`) and WebSocket (`6080`) ports strictly to `127.0.0.1`.
- **noVNC Direct Access**: Automatically symlinks `/usr/share/novnc/vnc.html` to `index.html`.
- **Private & Zero-Trust Transport**: Prompts interactively to configure **Tailscale Serve** (private HTTPS mesh domain) or install **Cloudflare Tunnel (`cloudflared`)** via official Cloudflare GPG repos.

### 2. Human Device Interaction Suite (`bin/deb/hdi.sh`)
Provisions toolkits for autonomous computer use and automated web frontend engineering:
- **Toolkit 1 (Autonomous Computer Use & GUI Navigation)**: Virtual display (`xvfb`), input injection (`xdotool`, `ydotool`), clipboard (`xclip`, `wl-clipboard`), visual capture/OCR (`maim`, `scrot`, `imagemagick`, `tesseract-ocr`), headless browsers & Playwright system libraries (`chromium`, `firefox-esr`, `libnss3`, etc.). Handles `ydotool` via default APT or official `trixie-backports` with interactive confirmation.
- **Toolkit 2 (Automated Web Dev Frontend)**: Runtimes (`nodejs`, `npm`, `golang`, `python3`), search & code intelligence (`git`, `ripgrep`, `fd-find`, `jq`, `fzf`), and process supervision (`supervisor`, `tmux`, `make`, `build-essential`).

### 3. Developer Workstation Setup (`bin/deb/dev.sh`)
Provisions a full development workstation:
- **CLI & Core Tools**: Prompts interactively to install `git`, `jq`, `tree`, `zip`, `unzip`, `wget`, `curl`, `zsh`, `xclip`, `ripgrep`, `fzf`, `fd-find`, `zoxide`, `eza`, `bat`, `btop`, `gcc`, `ca-certificates`.
- **Shell Customization**: Sets Zsh as default shell, deploys custom `.zshrc`, and installs Starship prompt.
- **APT Repository Managed Services**: Installs official **Docker Engine** and **GitHub CLI** (`gh`).
- **Developer Toolchains & Binaries**: [uv](https://astral.sh/uv), [Antigravity CLI](https://antigravity.google) (`agy`), [Rust](https://rustup.rs), and **Go**.

### 4. Server Baseline Hardening & Remote Access (`bin/deb/hardening.sh`)
Secures a server baseline and remote access:
- Installs `ufw`, `openssh-server`, `unattended-upgrades`, `fail2ban`, `tailscale`, and `vsec`.
- Configures default deny incoming UFW policy and restricts SSH access.
- Supports custom SSH ports with automated `/etc/ssh/sshd_config.d/custom-port.conf` configuration.
- Hardens SSH home directory permissions (`~/.ssh`, `authorized_keys`).

### 5. Samba File Host (`bin/deb/samba-srv.sh`)
Provisions a Samba file server:
- Installs `samba` and configures UFW firewall rules.
- Prompts for unprivileged Proxmox LXC container mapping (`chown -R 100000:100000` & `chmod -R 775`).
- Idempotently provisions `/mnt/storage` and appends `[storage]` share to `/etc/samba/smb.conf`.

### 6. CIFS Storage Mount Client (`bin/deb/samba-cli.sh`)
Mounts remote CIFS shares on client nodes:
- Prompts for SMB IP, share name, mount point, username, and password.
- Stores credentials securely in `/etc/cifs-credentials` (`chmod 600`).
- Configures `/etc/fstab` for automatic network mounting (`_netdev,x-systemd.automount`).

### 7. QEMU / KVM Virtualization & AI Test Harness (`bin/deb/kvm.sh` & `bin/test-vm`)
Provisions lightweight QEMU/KVM virtualization and instant testing harness:
- **KVM & User Permissions**: Installs QEMU/KVM packages and adds user to `kvm` group for non-root hardware virtualization.
- **Base Image Cache**: Pre-fetches Debian 12 (Bookworm), Debian 13 (Trixie), or Arch Linux cloud QCOW2 images in `~/.cache/qemu-test-images/`.
- **Ephemeral VM Testing Harness (`test-vm`)**: Spins up clean KVM instances in 2-4 seconds using Copy-on-Write (CoW) overlays for testing post-install scripts:
  ```bash
  test-vm run --os debian12 --script bin/deb/dev.sh
  test-vm run --os debian13 --script bin/deb/hdi.sh
  test-vm run --os arch --url https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/vnc.sh
  ```

---

## Local Execution

Clone the repository and execute locally:

```bash
git clone https://github.com/notasandworm/install.git
cd install

./bin/deb/kvm.sh
./bin/test-vm run --os debian12 --script bin/deb/dev.sh
```
