# Antigravity Plus

A layout and typography patching utility for the Antigravity desktop environment. Install beautiful fonts, customized theme styling, and smart text alignment in seconds.

<p align="center">
  <a href="https://github.com/abbasnaqdi/antigravity-plus">
    <img src="https://img.shields.io/github/stars/abbasnaqdi/antigravity-plus?style=for-the-badge&logo=github&color=24292e" alt="GitHub Stars">
  </a>
  <a href="https://github.com/abbasnaqdi/antigravity-plus/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/abbasnaqdi/antigravity-plus?style=for-the-badge&color=24292e" alt="License">
  </a>
</p>

<p align="center">
  🚀 <b>Help this project grow!</b> If Antigravity Plus improved your layout, please drop a ⭐ on GitHub!
</p>

<p align="center">
  <img src="src/terminal_preview.png?v=1.1" width="85%" alt="Terminal Patcher Preview" />
</p>
<p align="center">
  <img src="src/patched_app_preview.png?v=1.1" width="85%" alt="Patched App UI Preview" />
</p>

---

## Core Features

* **Deep Shadow-DOM Piercing**: Custom styles propagate seamlessly into sandboxed webviews and iframes to style agent responses correctly.
* **Keyboard-Aware Auto-Direction**: Dynamically applies `dir="auto"` based on keyboard language layouts (supporting Persian/RTL and English/LTR).
* **Corner Rounding Control**: Choose a tailored border-radius (0px to 5px) for cards, buttons, and panels.
* **Sub-pixel Text Rendering**: Enables optimal font-smoothing for crisp typography on high-DPI displays.
* **Auto-Font Installer & Cache**: Detects active desktop fonts (GNOME, KDE, XFCE), caches configuration under `~/.config/antigravity-plus/`, and installs missing font packages via apt.
* **Custom CSS Ingest**: Supply an optional path to any custom `.css` file to inject personalized themes.
* **Safe Automatic Backups**: Automatically backs up and restores `app.asar` resources securely.

---

## Quick Start Guide

### Linux
Verified on **Ubuntu 26.04 LTS** (supports any Debian/Ubuntu-based system, download the client from [antigravity.google](https://antigravity.google)).

```bash
# 1. Grant execution permissions
chmod +x install.sh

# 2. Run the patcher
./install.sh
```
*Note: Sudo privileges are only requested if the application is installed in system-protected folders (like `/opt`).*

### macOS
Supports macOS (Apple Silicon & Intel). The patcher dynamically detects macOS, resolves the application bundle path, and installs custom fonts via Homebrew.

```bash
# 1. Grant execution permissions
chmod +x install.sh

# 2. Run the patcher
./install.sh
```

### Windows (Experimental)
> [!WARNING]
> **Untested Platform**: The Windows version of this patcher (`install.ps1` and `rollback.ps1`) is **untested**. Use at your own risk. Ensure you have backed up any critical data before running.

Run the patcher in PowerShell (run PowerShell as Administrator if Antigravity is installed in `C:\Program Files`):
```powershell
# 1. Bypass script execution policy for the current process
Set-ExecutionPolicy Bypass -Scope Process -Force

# 2. Run the patcher script
.\install.ps1
```

---

## Rollback & Uninstall

### Linux
To revert back to the original layout:
```bash
# Grant execution permissions
chmod +x rollback.sh

# Run the rollback utility
./rollback.sh
```

### macOS
To revert back to the original layout:
```bash
# Grant execution permissions
chmod +x rollback.sh

# Run the rollback utility
./rollback.sh
```

### Windows (Experimental)
To revert back to the original layout (run PowerShell as Administrator if needed):
```powershell
# 1. Bypass script execution policy for the current process
Set-ExecutionPolicy Bypass -Scope Process -Force

# 2. Run the rollback utility
.\rollback.ps1
```

---

## Star History

<p align="center">
  <a href="https://star-history.com/#abbasnaqdi/antigravity-plus&Date">
    <img src="https://api.star-history.com/svg?repos=abbasnaqdi/antigravity-plus&type=Date" width="85%" alt="Star History Chart">
  </a>
</p>

---

## Contributing

Contributions of all kinds are welcome! Whether you are reporting a bug, proposing a new feature, or submitting a Pull Request, feel free to open an issue or pull request.

Check out our [good first issues](https://github.com/abbasnaqdi/antigravity-plus/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) to get started!

---

## Disclaimer & Feedback
This utility is open-source and provided "as-is" without warranty. If you run into any issues, have suggestions, or want to share feedback, please let us know!
