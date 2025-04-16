# 🍷 BottleForge for macOS

![Release](https://img.shields.io/github/v/release/Alien4042x/BottleForge)
![Downloads](https://img.shields.io/github/downloads/Alien4042x/BottleForge/total)
![License](https://img.shields.io/github/license/Alien4042x/BottleForge)

**BottleForge** is an experimental macOS utility app for managing and fixing Wine/CrossOver-based wrappers. Whether you're a gamer or tinkerer, it helps apply common fixes for compatibility issues on macOS.

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
- Not all CrossOver features exposed
- Advanced tweaks require editing external JSON

---

## 🔧 Building & Usage

1. Clone this repo
2. Open `BottleForge.xcodeproj` in Xcode
3. Build & Run (macOS 12.4+ required)

---

## 🪪 License
MIT — free for personal or commercial use.

---

## 📸 Screenshots
![BottleForge](https://github.com/user-attachments/assets/2519a710-d37f-4773-96c2-a007becd2a1d)

![BottleForge_2](https://github.com/user-attachments/assets/eae78b7f-92e5-4e54-9663-586ef3eaae97)

---

Made with ❤️ by [Alien4042x](https://github.com/Alien4042x)
