# NixOS Configuration: "Bocchi the Rock" Edition

> "If I can't be a rock star, I'll just be a Linux rice star!" - Hitori Gotoh (probably)

This repository contains a highly customized **NixOS** configuration, themed after the anime **Bocchi the Rock!**. It is designed to be built and tested inside a **QEMU VM** running on **WSL2** (Windows Subsystem for Linux), but can be deployed to real hardware.

## Features

### Visual Style (The Rice)
*   **Theme**: **Catppuccin Mocha** (Dark base) with **Pink (#f5c2e7)** accents, matching Hitori's hair and tracksuit.
*   **Wallpaper**: Animated video wallpapers powered by `mpvpaper`.
*   **Bar**: Custom **Eww** (ElKowars wacky widgets) bar with a pink border.
*   **Visualizer**: **Cava** audio visualizer that reacts to music with sunset colors.
*   **Cursor**: `Bibata-Modern-Ice` (Clean white cursor).
*   **Fonts**: `SpaceMono Nerd Font` for a consistent coding aesthetic.

### Core System
*   **OS**: NixOS Unstable (via Flakes).
*   **Window Manager**: **Hyprland** (Wayland compositor).
*   **Terminal**: **Kitty** (Transparent, themed).
*   **Shell**: **Zsh** + **Starship** prompt.
*   **Launcher**: **Fuzzel** (Fast, Wayland-native).
*   **Notifications**: **SwayNC**.
*   **Login Manager**: **SDDM**.

## Project Structure

```
.
├── flake.nix             # Entry point for the configuration
├── setup.sh              # Script to customize username/hostname
├── home/                 # Home Manager configuration (User: BadRabbit)
│   ├── default.nix       # Home Manager entry point
│   ├── desktop/          # Desktop Environment config
│   │   ├── hyprland/     # Hyprland & Hyprlock config
│   │   ├── eww/          # Bar & Widgets
│   │   ├── fuzzel/       # App Launcher
│   │   └── swaync/       # Notifications
│   ├── programs/         # User programs (VS Code, Firefox, etc.)
│   ├── shell/            # Zsh & Git config
│   ├── terminal/         # Kitty config
│   ├── theme/            # GTK & Cursor themes
│   └── wallpapers/       # Wallpapers storage
├── hosts/                # Host-specific configurations
│   └── desktop/          # Main desktop host config
├── modules/              # Reusable NixOS modules
│   ├── core/             # System core (Boot, Net, User, Audio)
│   └── hyprland/         # System-level Hyprland setup
└── result/               # Build output symlink
```

## Installation on Real Hardware

Follow these steps to install this configuration on a physical machine.

### 1. Boot NixOS
Boot into the NixOS Live ISO (Graphical or Minimal).

### 2. Clone the Repository
Open a terminal and clone this repository:
```bash
git clone https://github.com/BadRabbit00/nixos-conf.git ~/nixos-conf
cd ~/nixos-conf
```

### 3. Customize Configuration
Run the setup script to set your desired username and hostname. This will automatically update all necessary files.
```bash
chmod +x setup.sh
./setup.sh
```

### 4. Generate Hardware Configuration
Generate the hardware configuration for your specific machine and overwrite the default one in the repo:
```bash
nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix
```

### 5. Install
Start the installation process. Replace `your-hostname` with the hostname you entered in step 3.
```bash
# If you are not root, use sudo
sudo nixos-install --flake .#your-hostname
```

### 6. Post-Install
Reboot into your new system.
```bash
reboot
```
**Note:** Don't forget to change the Hyprland modifier key back to `SUPER` (Windows Key) in `home/desktop/hyprland/hyprland.conf` if you prefer it over `ALT`.

## Testing in VM (WSL2 + QEMU)

This setup allows you to develop and test the configuration on Windows without rebooting.

### Prerequisites
1.  **WSL2** installed with NixOS or Ubuntu (with Nix package manager).
2.  **QEMU** installed in your WSL distro.
3.  **XServer/Wayland Server** on Windows (e.g., VcXsrv or GWSL) if not using WSLg.

### Build & Launch

1.  **Add changes to Git** (Flakes require files to be tracked):
    ```bash
    git add .
    ```

2.  **Build the Virtual Machine**:
    ```bash
    # Replace 'badrabbitpc' with your hostname if you changed it
    nix build .#nixosConfigurations.badrabbitpc.config.system.build.vm --extra-experimental-features "nix-command flakes"
    ```

3.  **Run the VM**:
    ```bash
    ./result/bin/run-badrabbitpc-vm
    ```

### Keybindings (Modified for VM)

Since the Windows key (`Super`) is often captured by the host OS, the main modifier has been changed to **ALT**.

| Key Combination | Action |
| :--- | :--- |
| `ALT + Q` | Open Terminal (Kitty) |
| `ALT + R` | Open App Launcher (Fuzzel) |
| `ALT + C` | Close Active Window |
| `ALT + E` | Open File Manager (Thunar) |
| `ALT + V` | Toggle Floating Window |
| `ALT + M` | Exit Hyprland (Logout) |
| `ALT + Arrow Keys` | Move Focus |
| `ALT + 1-9` | Switch Workspace |

## Important Notes

*   **Wallpapers**: Place your `wallpaper.mp4` in `home/wallpapers/` before building. A placeholder is used by default.
*   **Performance**: Running a Wayland compositor (Hyprland) inside a VM inside WSL might have graphical artifacts depending on your GPU passthrough setup.

---
*Generated by GitHub Copilot for BadRabbit*
