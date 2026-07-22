# Post-Install Provisioning & Hardening Suite

I built this modular post-installation repository to automate provisioning and baseline security setup across my Debian and Ubuntu workstations and servers.

---

## Directory Structure

```text
.
├── .zshrc               # My personal Zsh shell configuration & functions
├── bin/
│   ├── README.md        # Directory placeholder note
│   └── deb/
│       ├── README.md    # Debian directory placeholder note
│       ├── dev.sh       # Developer workstation suite (Packages, Zsh, Docker, Go, Rust, uv, agy, gh, Tailscale)
│       ├── hardening.sh # Server security baseline (UFW, SSH hardening, fail2ban, auto-upgrades)
│       ├── samba-srv.sh # Samba storage host setup & Proxmox LXC unprivileged container mapping
│       └── samba-cli.sh # CIFS client storage automount & credential management
└── README.md            # You are here!
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

### 1. Developer Workstation Setup (`bin/deb/dev.sh`)
Provisions a full development workstation:
- **CLI & Core Tools**: Prompts interactively to install `git`, `jq`, `tree`, `zip`, `unzip`, `wget`, `curl`, `zsh`, `xclip`, `ripgrep`, `fzf`, `fd-find`, `zoxide`, `eza`, `bat`, `btop`, `gcc`, `ca-certificates`.
- **Shell Customization**:
  - Sets Zsh as default shell.
  - Automatically deploys my `.zshrc` configuration (backing up any pre-existing `~/.zshrc`).
  - Installs the [Starship](https://starship.rs) prompt.
- **APT Repository Managed Services**:
  - Installs official **Docker Engine** (`docker-ce`, `docker-compose-plugin`, `docker-buildx-plugin`) and adds current user to the `docker` group.
  - Installs official **GitHub CLI** (`gh`).
- **Developer Toolchains & Binaries**:
  - [uv](https://astral.sh/uv) (Fast Python package installer)
  - [Antigravity CLI](https://antigravity.google) (`agy`)
  - [Rust](https://rustup.rs) (`rustc`, `cargo`)
  - **Go** (Tarball installation to `/usr/local/go`)
  - [Tailscale](https://tailscale.com) mesh VPN

> **Maintenance Note**: Future updates for Docker Engine, GitHub CLI, and Tailscale are automatically handled via your native package manager:
> ```bash
> sudo apt update && sudo apt upgrade
> ```

### 2. Server Baseline Hardening (`bin/deb/hardening.sh`)
Secures a server baseline:
- Installs `ufw`, `openssh-server`, `unattended-upgrades`, `fail2ban`.
- Configures default deny incoming, default allow outgoing UFW policy.
- Restricts SSH access to local subnet (`192.168.1.0/24`).
- Hardens SSH home directory file permissions (`~/.ssh`, `authorized_keys`).

### 3. Samba File Host (`bin/deb/samba-srv.sh`)
Provisions a Samba file server:
- Installs `samba` and configures UFW firewall rules.
- Prompts for unprivileged Proxmox LXC container mapping (`chown -R 100000:100000` & `chmod -R 775`).
- Idempotently provisions `/mnt/storage` and appends `[storage]` share to `/etc/samba/smb.conf`.

### 4. CIFS Storage Mount Client (`bin/deb/samba-cli.sh`)
Mounts remote CIFS shares on client nodes:
- Prompts for SMB IP, share name, mount point, username, and password.
- Stores credentials securely in `/etc/cifs-credentials` (`chmod 600`).
- Configures `/etc/fstab` for automatic network mounting (`_netdev,x-systemd.automount`).

---

## Single-Line Remote Execution

You can run any full provisioning module remotely via `curl`:

```bash
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

## Local Execution

Clone the repository and execute locally:

```bash
git clone https://github.com/notasandworm/install.git
cd install

./bin/deb/dev.sh
./bin/deb/hardening.sh
./bin/deb/samba-srv.sh
./bin/deb/samba-cli.sh
```
