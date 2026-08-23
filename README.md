# 🩸 NixOS "Infernal Mecha" Configuration

This repository contains a modular NixOS configuration managed with **Flakes** and **Home Manager**, themed with a deep, infernal palette and a mecha-inspired interface. It is optimized for a high-performance, keyboard-centric workflow.

## 🎨 Aesthetic Profile

*   **Theme**: Infernal Blood (Static Palette).
*   **Colors**: 
    *   Accent: `#d33637` (Bright Red)
    *   Background: `#0c0c0c` (Deep Void)
    *   Foreground: `#ac7e7c` (Dusty Rose)
    *   Armor Layers: `#351212`, `#403736`, `#242424`
*   **UI Style**: Modular, mechanical, aggressive, and cohesive across all applications.

## 🚀 Key Components

*   **WM**: [Niri](https://github.com/YaLTeR/niri) (Wayland) - A scrollable tiling compositor with a unique horizontal workflow and "Infernal Blood" styling.
*   **Bar**: [Mechabar](https://github.com/sejjy/mechabar) (Waybar) - Fully integrated with custom scripts and the Blood-Red palette. 
    *   *Original credits to [Jesse Mirabel](https://github.com/sejjy) for the mecha-themed base.*
*   **Launcher**: [Rofi](https://github.com/davatorium/rofi) with a custom static Blood-Red theme.
*   **Terminal**: [Kitty](https://sw.kovidgoyal.net/kitty/) - Enhanced with Kittens (hints, icat), ligatures (`CommitMono Nerd Font`), and shell integration.
*   **Lockscreen**: [Hyprlock](https://github.com/hyprwm/hyprlock) - Visual masterpiece with blurred wallpaper, large red clock, and elegant input fields.
*   **System Monitor**: [Btop](https://github.com/aristocratos/btop) with a custom "Infernal Blood" theme.
*   **System Info**: [Fastfetch](https://github.com/fastfetch-cli/fastfetch) configured with custom modules and image support (`logo.png`).

## ⌨️ "Arrow-Mecha" Navigation

The system uses `SUPER` (Win) as the main modifier with standard arrow keys:
*   **Focus**: `Win + Left/Right` (Columns), `Win + Up/Down` (Windows).
*   **Window Resizing**: `Ctrl + Alt + Arrows`
*   **Quick Apps**: `Win + Enter` (Kitty), `Win + B` (Browser), `Win + S` (Spotify), `Win + Q` (Close).
*   **Screenshot**: `Win + Shift + S` (Area selection to clipboard).
*   **Layout Toggle**: `Win + Space`.

## 🛠️ Integrated Scripts (Mechabar)

*   **Network/Bluetooth**: `fzf`-based selection menus inside Kitty.
*   **Power Menu**: Compact session control via `fzf`.
*   **Media/Brightness**: Integrated OSD notifications via `volume.sh` and `backlight.sh`.

## ⚙️ Initial Setup

1.  Clone the repo:
    ```bash
    git clone https://github.com/BadRabbit00/nixos-conf.git && cd nixos-conf
    ```
2.  Set your username/hostname:
    ```bash
    ./setup.sh
    ```
3.  Add your custom logo for fastfetch:
    Place your image at `home/programs/logo.png`.
4.  Apply configuration:
    ```bash
    sudo nixos-rebuild switch --flake .#badrabbitpc
    ```

*Forged in blood and code for the Architect.* 🧛‍♀️🩸
