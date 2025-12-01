# 🍷 BottleForge for macOS

[![Release](https://img.shields.io/github/v/release/Alien4042x/BottleForge)](https://github.com/Alien4042x/BottleForge/releases)
[![Downloads](https://img.shields.io/github/downloads/Alien4042x/BottleForge/total)](https://github.com/Alien4042x/BottleForge/releases)
[![License](https://img.shields.io/github/license/Alien4042x/BottleForge)](https://github.com/Alien4042x/BottleForge/blob/main/LICENSE)

**BottleForge** is an experimental macOS utility for managing and fixing Wine/CrossOver bottles.  
It serves as a macOS-friendly alternative to the Linux Winetricks tool.  
Whether you're a gamer or tinkerer, it helps apply common fixes for compatibility issues on macOS.

- 🎯 Also check out [StealthPointer](https://github.com/Alien4042x/StealthPointer) – hide/show your macOS cursor with hotkeys. Perfect for Wine fullscreen gaming!

---

## ✨ Features

- 🔍 **Diagnostics Panel**
  - Quickly apply well-known fixes like Visual C++ overrides
  - Great for games that keep asking for missing DLLs

- 📁 **File Explorer**
  - Browse and manage Wine bottle files visually
  - Inspired by Finder — see what's inside your bottle prefix

- 🍷 **WineTricks macOS** (optional JSON-powered tweaks)
  - Load Wine-specific tweaks from a remote [JSON database](https://github.com/Alien4042x/winemactricks-json)
  - One-click install/uninstall with metadata

- ⚙️ **Runtime Detection**
  - Detect and support both **CrossOver** and **CXPatcher** runtimes
  - Easy toggle between runtimes

- 📦 **Classic Winetricks Support**
  - Run upstream winetricks shell scripts directly from the app
  - Useful for power users — not all tweaks are uninstallable or macOS-friendly

- 🛠️ **Homebrew Integration**
  - Automatically detects missing tools (e.g. cabextract, wget, unzip)
  - Offers to install them via Homebrew with one click

- 📜 **Tweak Log Panel**
  - Live terminal-style output for Classic Winetricks installs
  - Helps identify errors or stuck installations

- 🧯 **Stuck Process Protection**
  - Automatic timeout and watchdog detection if Winetricks becomes unresponsive
  - Prevents app freezes and gives useful error feedback

- 🍾 **Bottle Config**
  - New configuration panel for individual bottles
  - Enable or disable custom scripts and tweaks per bottle
  - Provides easier control over runtime behavior
---

## 🧪 Experimental Tips

### ⚙️ Max Files Limit Trick (for heavy games)
Boost your macOS file descriptor limits — can help with games using thousands of assets:

```sh
sudo launchctl limit maxfiles 1048576 1048576
ulimit -n 1048576
```

⚠️ *Only works until next reboot. Not persistent.*

### 🌡️ Thermal Tip
High temperatures while gaming?

> Try enabling **VSync** to reduce CPU/GPU load — yes, it may reduce FPS slightly, but it lowers heat and can prevent thermal throttling.

---

## ✅ Pros

- Works out-of-the-box with CrossOver and CXPatcher
- Lightweight and native app
- JSON-based tweak integration
- Friendly UI with zero CLI knowledge needed

## ⚠️ Limitations

- Still in **early development**
- No auto-updates yet
- Advanced tweaks require editing external JSON

---

## 🔧 Building & Usage

1. Clone this repo
2. Open `BottleForge.xcodeproj` in Xcode
3. Build & Run (macOS 12.4+ required)

---

## 🪪 License

This project is licensed under the **Mozilla Public License 2.0**.  
If you modify and distribute any part of the source, you must publish those changes under the same license.  
More info: [https://mozilla.org/MPL/2.0/](https://mozilla.org/MPL/2.0/)

---

## 📸 Screenshots

<img width="1652" height="944" alt="Snímek obrazovky 2025-10-02 v 19 43 00" src="https://github.com/user-attachments/assets/ba774f99-317d-4b7a-8a53-5bda937618e9" />
<img width="1652" height="944" alt="Snímek obrazovky 2025-10-02 v 19 44 17" src="https://github.com/user-attachments/assets/ffc0d52b-1e47-4ead-b0a4-1763d6e1e9e5" />

---

Made with ❤️ by [Alien4042x](https://github.com/Alien4042x)
