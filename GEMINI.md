# 🩸 NixOS "Infernal Mecha" Context

This repository contains a modular NixOS configuration managed with **Flakes** and **Home Manager**. It features a custom "Infernal Blood" aesthetic, merging high-performance mecha-inspired UI with a deep red/black palette.

## 🛠️ Project Architecture

*   **Flake Entry**: `flake.nix` defines inputs (nixpkgs unstable) and outputs the `badrabbitpc` configuration.
*   **Host Logic**: `hosts/desktop/` contains system-level NixOS modules (hardware, bootloader, networking, users).
*   **User Logic (Home Manager)**: `home/` contains granular desktop environment settings, organized by functional modules (hyprland, terminal, theme).
*   **Shared Modules**: `modules/` houses reusable system-level configurations (audio, core utilities, hyprland support).

## 🎨 Aesthetic Profile (Infernal Blood)

*   **Base Theme**: Catppuccin Mocha (Black/Rimless variant).
*   **Accent Color**: Blood Red (`#d33637`).
*   **Background**: Deep Void (`#0c0c0c`).
*   **Key UI Elements**:
    *   **Mechabar**: A heavily customized Waybar implementation inspired by mecha aesthetics, featuring slanted dividers and dynamic system monitoring.
    *   **Hyprland**: Red-to-dark gradient borders, custom bezier animations.
    *   **GTK/Icons**: Catppuccin Red variants with Tela-circle-red icons.

## 🚀 Key Commands

### Initial Setup
1.  **Rename User/Host**: Run `./setup.sh` to globally replace default names.
2.  **Generate Hardware Config**:
    ```bash
    nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix
    ```

### Applying Changes
*   **Rebuild System**:
    ```bash
    sudo nixos-rebuild switch --flake .#badrabbitpc
    ```
*   **VM Testing** (WSL2/QEMU):
    ```bash
    nix build .#nixosConfigurations.badrabbitpc.config.system.build.vm
    ./result/bin/run-badrabbitpc-vm
    ```

## ⌨️ Development & Workflow Conventions

*   **Git Tracking**: Since this is a Flake-based project, **all new files must be tracked by Git** (`git add .`) before Nix can see them.
*   **Vim-Mecha Bindings**: Navigation follows Vim logic (`SUPER + H/J/K/L` for focus, `CTRL+ALT + H/J/K/L` for resizing).
*   **Integrated Scripts**: Scripts for volume, backlight, and power management are located in `home/desktop/waybar/scripts/` and symlinked to `.config/waybar/scripts`.
*   **Modularity**: System-wide settings belong in `modules/`, while user-specific dotfile logic stays in `home/`.

## 📂 Key File Structure
*   `flake.nix`: Main entry point and dependency management.
*   `home/desktop/hyprland/hyprland.conf`: Core window manager rules and keybindings.
*   `home/desktop/waybar/default.nix`: Comprehensive Mechabar styling and module logic.
*   `home/theme/default.nix`: GTK, Qt, and cursor synchronization.
*   `setup.sh`: Utility for initial deployment and personalization.
