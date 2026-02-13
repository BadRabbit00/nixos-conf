# 🩸 NixOS "Blood-Red Mecha" Configuration

This repository contains a modular NixOS configuration managed with **Flakes** and **Home Manager**, themed with a deep, infernal palette and a mecha-inspired interface.

| ![Waybar Mechabar](./ref/mechabar/assets/catppuccin-mocha.png) |
| :----------------------------------------------------------: |
| *Note: Theme has been customized to a Blood-Red variant.*    |

## 🎨 Aesthetic Profile

*   **Theme**: Infernal Blood (Static Palette).
*   **Colors**: 
    *   Accent: `#d33637` (Bright Red)
    *   Background: `#0c0c0c` (Deep Void)
    *   Foreground: `#ac7e7c` (Dusty Rose)
*   **UI Style**: Modular, mechanical, aggressive.

## 🚀 Key Components

*   **WM**: [Hyprland](https://hyprland.org/) (Wayland).
*   **Bar**: [Mechabar](https://github.com/sejjy/mechabar) (Waybar) - Custom modular design with integrated scripts. 
    *   *Original credits to [Jesse Mirabel](https://github.com/sejjy) for the incredible mecha-themed base.*
*   **Launcher**: [Rofi](https://github.com/davatorium/rofi) (Wayland-wayland) with a static Blood-Red theme.
*   **Terminal**: [Kitty](https://sw.kovidgoyal.net/kitty/).
*   **Shell**: Zsh + Starship.
*   **Wallpaper Manager**: Swww.

## 🛠️ Integrated Scripts (Mechabar)

The status bar includes custom interactive modules:
*   **Network Manager**: `fzf`-based Wi-Fi selection.
*   **Bluetooth Manager**: `fzf`-based device pairing.
*   **Power Menu**: Compact session management.
*   **Volume/Brightness**: Integrated OSD notifications.

## 📂 Project Structure

*   `flake.nix`: Entry point.
*   `hosts/`: Host-specific configs (`badrabbitpc`).
*   `home/`: User-level configuration (Home Manager).
    *   `desktop/waybar/`: The heart of the "Mecha" UI.
    *   `desktop/rofi/`: Static red theme.
*   `modules/`: Reusable system modules (Core, Hyprland).
*   `ref/mechabar/`: Original reference files for the UI components.

## ⚙️ Initial Setup

1.  Clone the repo:
    ```bash
    git clone https://github.com/your-repo/nixos-conf.git && cd nixos-conf
    ```
2.  Set your username/hostname:
    ```bash
    ./setup.sh
    ```
3.  Apply configuration:
    ```bash
    sudo nixos-rebuild switch --flake .#badrabbitpc
    ```

*Created with ❤️ for the Architect.*
