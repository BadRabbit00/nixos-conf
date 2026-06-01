# 🩸 NixOS "Infernal Mecha" Configuration - GEMINI Context

This repository contains a highly modular, aesthetic-driven NixOS configuration managed via **Flakes** and **Home Manager**. It is designed with an "Infernal Blood" mecha theme, prioritizing a high-performance, keyboard-centric workflow.

## 🛠️ Project Architecture

The configuration is split into three main layers to ensure modularity and ease of maintenance:

*   **Flake Entry (`flake.nix`)**: The central hub that defines inputs (nixpkgs unstable, home-manager, catppuccin) and outputs the `badrabbitpc` system configuration.
*   **Host Layer (`hosts/desktop/`)**: Contains system-level NixOS modules specific to the hardware and core OS settings (bootloader, networking, drivers, NVIDIA).
*   **User Layer (`home/`)**: Managed by Home Manager, this directory handles all dotfiles, application settings, and the "Infernal Blood" aesthetic.
*   **Shared Modules (`modules/`)**: Reusable Nix expressions for system-wide services like `audio.nix`, `nvidia.nix`, and `hyprland/default.nix`.

## 🎨 Aesthetic Profile: "Infernal Blood"

*   **Color Palette**: Deep Void (`#0c0c0c`) background with Blood Red (`#d33637`) accents.
*   **Visual Style**: Aggressive, mechanical UI inspired by mecha-cockpit displays.
*   **Core UI Components**:
    *   **Hyprland**: Tiling Wayland compositor with red-to-dark gradient borders and custom bezier animations.
    *   **Mechabar (Waybar)**: Heavily customized top bar featuring slanted dividers and dynamic system monitoring.
    *   **Terminal (Kitty)**: Uses `CommitMono Nerd Font` with red-themed syntax highlighting and shell integration.

## 🚀 Key Commands & Workflow

### System Management
*   **Rebuild System**: `sudo nixos-rebuild switch --flake .#badrabbitpc`
*   **Update Flake**: `nix flake update`
*   **Personalization**: Run `./setup.sh` to globally rename the default user (`BadRabbit`) and hostname (`badrabbitpc`).

### Navigation (Vim-Mecha)
Navigation follows Vim logic using the `SUPER` (Win) key:
*   **Focus**: `SUPER + H/J/K/L`
*   **Resize**: `CTRL + ALT + H/J/K/L`
*   **Launchers**: `SUPER + Enter` (Kitty), `SUPER + R` (Rofi).
*   **Session**: `SUPER + Q` (Close Window), `SUPER + SHIFT + E` (Power Menu).

## 📂 Key File Map

| File/Directory | Description |
| :--- | :--- |
| `flake.nix` | Main entry point for the NixOS flake. |
| `hosts/desktop/default.nix` | System-level entry point (Hardware, Boot, Core Modules). |
| `home/default.nix` | Home Manager entry point (User apps, UI theme). |
| `home/desktop/hyprland/` | Core window manager logic and keybindings. |
| `home/desktop/waybar/` | "Mechabar" styling and integrated scripts. |
| `modules/core/` | System-wide service configurations (Audio, Nvidia, etc.). |
| `setup.sh` | Utility script for initial deployment and renaming. |

## ⚙️ Development Conventions

*   **Modular Imports**: Always prefer adding new logic to a separate file in `modules/` or `home/` and importing it, rather than bloating main entry points.
*   **Git Awareness**: As a Flake-based project, **all new files must be tracked by Git** (`git add .`) before they can be seen by the Nix evaluator.
*   **Path Management**: Use absolute flake paths (e.g., `./modules/...`) or Home Manager relative paths to ensure reproducibility.

---
*Forged in blood and code for the Architect.* 🧛‍♀️🩸
