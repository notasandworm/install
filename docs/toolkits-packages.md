# Automated GUI Navigation & Frontend Dev Toolkits

This document outlines the optimized package lists for setting up headless GUI browser automation, input injection, visual verification, and web development toolchains across Debian/Ubuntu and Arch Linux environments.

---

## 1. Debian/Ubuntu (`apt`) Toolkits

### Toolkit 1: Headless GUI & Web Browser Automation

Packages for spawning virtual frames, simulating human desktop input, capturing screen states, and running automated browsers:

* **Display Server & Framebuffer:** `xvfb` (virtual display), `x11-utils` (provides `xwd`), `x11vnc` (VNC stream server), `wmctrl` (X11 window manager manipulation).
* **Input Injection & Clipboard:** `xdotool` (X11 input injection), `ydotool` (Wayland/evdev input injection), `xclip` (X11 clipboard control), `wl-clipboard` (Wayland clipboard control).
* **Visual Perception & Capture:** `maim` & `scrot` (screenshot capture utilities), `imagemagick` (image post-processing), `tesseract-ocr` (OCR engine for local text recognition).
* **Browser Engines & Playwright System Libraries:** `chromium`, `firefox-esr`, `libnss3`, `libatk-bridge2.0-0`, `libxcomposite1`, `libxdamage1`, `libxfixes3`, `libxrandr2`, `libgbm1`, `libasound2`, `libcups2`, `libpango-1.0-0`.
* **Scripting & Run-time Utilities:** `curl`, `jq`, `ripgrep`, `python3`, `python3-pip`, `python3-venv`.

**One-line installation command:**
```bash
sudo apt update && sudo apt install -y \
  xvfb x11-utils x11vnc wmctrl \
  xdotool ydotool xclip wl-clipboard \
  maim scrot imagemagick tesseract-ocr \
  chromium firefox-esr \
  libnss3 libatk-bridge2.0-0 libxcomposite1 libxdamage1 libxfixes3 \
  libxrandr2 libgbm1 libasound2 libcups2 libpango-1.0-0 \
  curl jq ripgrep python3 python3-pip python3-venv
```

### Toolkit 2: Modern Web Dev & Frontend Workstation

Core packages to provision frontend runtimes, package managers, and compilation toolchains:

* **Runtimes & Package Managers:** `nodejs`, `npm`, `golang`, `python3`, `python3-venv`.
* **Search & Development Utilities:** `git`, `ripgrep`, `fd-find`, `jq`, `fzf`, `patch`, `diffutils`.
* **Process Supervision & Build Toolchain:** `supervisor` (process manager), `tmux`, `make`, `build-essential` (`gcc`, `g++`, native module compilation).

**One-line installation command:**
```bash
sudo apt update && sudo apt install -y \
  nodejs npm golang python3 python3-venv \
  git ripgrep fd-find jq fzf patch diffutils \
  supervisor tmux make build-essential
```

---

## 2. Arch Linux (`pacman`) Toolkits

*(Packages are pulled strictly from official `core` and `extra` repositories — no AUR package management is needed)*

### Toolkit 1: Headless GUI & Web Browser Automation

* **Display Server & Framebuffer:** `xorg-server-xvfb`, `xorg-xwd`, `x11vnc`, `wmctrl`.
* **Input Injection & Clipboard:** `xdotool`, `ydotool`, `xclip`, `wl-clipboard`.
* **Visual Perception & Capture:** `maim`, `scrot`, `imagemagick`, `tesseract`, `tesseract-data-eng`.
* **Browser Engines & Playwright System Libraries:** `chromium`, `firefox`, `nss`, `atk`, `libxcomposite`, `libxdamage`, `libxfixes`, `libxrandr`, `mesa`, `alsa-lib`, `cups`, `pango`.
* **Scripting & Run-time Utilities:** `curl`, `jq`, `ripgrep`, `python`, `python-pip`, `python-uv`.

**One-line installation command:**
```bash
sudo pacman -S --noconfirm \
  xorg-server-xvfb xorg-xwd x11vnc wmctrl \
  xdotool ydotool xclip wl-clipboard \
  maim scrot imagemagick tesseract tesseract-data-eng \
  chromium firefox \
  nss atk libxcomposite libxdamage libxfixes libxrandr mesa alsa-lib cups pango \
  curl jq ripgrep python python-pip python-uv
```

### Toolkit 2: Modern Web Dev & Frontend Workstation

* **Runtimes & Package Managers:** `nodejs`, `npm`, `pnpm`, `bun`, `go`, `python`, `python-uv`.
* **Search & Development Utilities:** `git`, `ripgrep`, `fd`, `jq`, `fzf`, `patch`, `diffutils`.
* **Process Supervision & Build Toolchain:** `supervisor`, `tmux`, `make`, `base-devel` (includes `gcc`, compiler headers).

**One-line installation command:**
```bash
sudo pacman -S --noconfirm \
  nodejs npm pnpm bun go python python-uv \
  git ripgrep fd jq fzf patch diffutils \
  supervisor tmux make base-devel
```

---

## Runtimes & Utilities Summary

| Capability Category | Debian / Ubuntu (`apt`) | Arch Linux (`pacman`) |
| --- | --- | --- |
| **Virtual Framebuffer** | `xvfb` | `xorg-server-xvfb` |
| **GUI Input Simulation** | `xdotool`, `ydotool` | `xdotool`, `ydotool` |
| **Local OCR** | `tesseract-ocr` | `tesseract`, `tesseract-data-eng` |
| **JS/Node Toolchain** | `nodejs`, `npm` | `nodejs`, `npm`, `pnpm`, `bun` |
| **Python Package Runner** | Manual via `pip` | `python-uv` *(official extra repo)* |
| **Process Supervision** | `supervisor` | `supervisor` |
