# Post-Install Provisioning & Hardening Suite

I built this modular post-installation repository to automate provisioning, baseline security setup, and human device interaction toolkits across my Debian, Ubuntu, and Arch Linux workstations and servers.

---

## Single-Line Remote Execution

You can run any full provisioning module remotely via `curl`:

```bash
# Human Device Interaction Suite (HDI)
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/dev/bin/deb/hdi.sh | bash

# Developer Workstation & Tooling
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/dev.sh | bash

# Server Hardening & Security Baseline
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/hardening.sh | bash

# Samba Storage Server Host
curl -fsSL https://raw.githubusercontent.com/notasandworm/install/main/bin/deb/samba-srv.sh | bash

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

### 1. Human Device Interaction Suite (`bin/deb/hdi.sh`)
Provisions toolkits for autonomous computer use and automated web frontend engineering:
- **Toolkit 1 (Autonomous Computer Use & GUI Navigation)**: Virtual display (`xvfb`), input injection (`xdotool`, `ydotool`), clipboard (`xclip`, `wl-clipboard`), visual capture/OCR (`maim`, `scrot`, `imagemagick`, `tesseract-ocr`), headless browsers & Playwright system libraries (`chromium`, `firefox-esr`, `libnss3`, etc.). Handles `ydotool` via default APT or official `trixie-backports` with interactive confirmation.
- **Toolkit 2 (Automated Web Dev Frontend)**: Runtimes (`nodejs`, `npm`, `golang`, `python3`), search & code intelligence (`git`, `ripgrep`, `fd-find`, `jq`, `fzf`), and process supervision (`supervisor`, `tmux`, `make`, `build-essential`).

### 2. Developer Workstation Setup (`bin/deb/dev.sh`)
Provisions a full development workstation:
- **CLI & Core Tools**: Prompts interactively to install `git`, `jq`, `tree`, `zip`, `unzip`, `wget`, `curl`, `zsh`, `xclip`, `ripgrep`, `fzf`, `fd-find`, `zoxide`, `eza`, `bat`, `btop`, `gcc`, `ca-certificates`.
- **Shell Customization**: Sets Zsh as default shell, deploys custom `.zshrc`, and installs Starship prompt.
- **APT Repository Managed Services**: Installs official **Docker Engine** and **GitHub CLI** (`gh`).
- **Developer Toolchains & Binaries**: [uv](https://astral.sh/uv), [Antigravity CLI](https://antigravity.google) (`agy`), [Rust](https://rustup.rs), and **Go**.

### 3. Server Baseline Hardening & Remote Access (`bin/deb/hardening.sh`)
Secures a server baseline and remote access:
- Installs `ufw`, `openssh-server`, `unattended-upgrades`, `fail2ban`, `tailscale`, and `vsec`.
- Configures default deny incoming UFW policy and restricts SSH access.
- Supports custom SSH ports with automated `/etc/ssh/sshd_config.d/custom-port.conf` configuration.
- Hardens SSH home directory permissions (`~/.ssh`, `authorized_keys`).

### 4. Samba File Host (`bin/deb/samba-srv.sh`)
Provisions a Samba file server:
- Installs `samba` and configures UFW firewall rules.
- Prompts for unprivileged Proxmox LXC container mapping (`chown -R 100000:100000` & `chmod -R 775`).
- Idempotently provisions `/mnt/storage` and appends `[storage]` share to `/etc/samba/smb.conf`.

### 5. CIFS Storage Mount Client (`bin/deb/samba-cli.sh`)
Mounts remote CIFS shares on client nodes:
- Prompts for SMB IP, share name, mount point, username, and password.
- Stores credentials securely in `/etc/cifs-credentials` (`chmod 600`).
- Configures `/etc/fstab` for automatic network mounting (`_netdev,x-systemd.automount`).

---

## Local Execution

Clone the repository and execute locally:

```bash
git clone https://github.com/notasandworm/install.git
cd install

./bin/deb/hdi.sh
./bin/deb/dev.sh
./bin/deb/hardening.sh
./bin/deb/samba-srv.sh
./bin/deb/samba-cli.sh
```
