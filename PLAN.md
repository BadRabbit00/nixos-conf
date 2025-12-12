# NixOS Configuration Plan 🚀

## 🎯 Goal
Build a modular, dual-boot NixOS system with a highly customized Hyprland environment.
**Strategy:** Start with a minimal working setup (MVP) with default themes, then iteratively customize each component (CSS, colors, animations).

---

## 📂 Directory Structure
We will transition from a flat structure to a modular tree:

```text
nixos-conf/
├── flake.nix                # Entry point
├── hosts/                   # Host-specific configurations
│   └── desktop/             # Main PC
│       ├── default.nix      # Imports hardware & modules
│       └── hardware-configuration.nix
├── modules/                 # System-level modules (root)
│   ├── core/                # Essential (boot, network, users)
│   └── hyprland/            # Window manager base
└── home/                    # User-level configuration (Home Manager)
    ├── default.nix          # Entry point
    ├── shell/               # Zsh, Starship, Git
    ├── terminal/            # Hyper
    ├── desktop/             # Hyprland, Eww, Fuzzel, Hyprlock
    └── theme/               # GTK, Cursor, Fonts
```

---

## 📝 Roadmap

### Phase 1: Foundation & Refactoring 🏗️
- [ ] **Structure**: Create folders `hosts/desktop`, `modules`, `home`.
- [ ] **Migration**: Move existing `configuration.nix` logic into modules.
- [ ] **Bootloader**:
    - Switch to **GRUB 2**.
    - Enable `os-prober` for Windows dual-boot detection.
    - *Theme:* Keep default for MVP.
- [ ] **Fonts**:
    - Install **SpaceMono Nerd Font** (Space Grotesk variant).
    - Install emoji fonts.

### Phase 2: Hyprland Core 🖥️
- [ ] **Engine**: Enable Hyprland module.
- [ ] **Display Manager**: Install **SDDM** (Simple Desktop Display Manager).
- [ ] **Lockscreen**: Setup **Hyprlock** (minimal config).
- [ ] **Idle Daemon**: Setup **Hypridle**.

### Phase 3: UI Components (MVP) 🎨
*Note: Minimal configuration first, heavy CSS customization later.*
- [ ] **Bar**: Install **Eww** (ElKowars Wacky Widgets).
    - Create a basic bar structure (Workspaces, Time).
- [ ] **Launcher**: Install **Fuzzel**.
- [ ] **Notifications**: Install **SwayNotificationCenter (SwayNC)**.
- [ ] **Wallpaper**: Install **Hyprpaper**.
- [ ] **Screenshots**: Install **Grim** + **Slurp**.

### Phase 4: User Environment 🛠️
- [ ] **Terminal**: Install **Hyper**.
    - *Customization:* Will be done via CSS later.
- [ ] **Shell**:
    - Enable **Zsh**.
    - Install **Starship** prompt.
    - Configure aliases.
- [ ] **Applications**:
    - **File Manager**: Thunar (plus archive plugins).
    - **Browsers**: Firefox, Google Chrome.
    - **Editors**: VS Code, Nano.

### Phase 5: Theming & Polish ✨
- [ ] **Cursor**: Enable **Bibata-Modern-Ice** (Immediate priority).
- [ ] **GTK Theme**: Select a placeholder theme (e.g., Adwaita or basic Catppuccin) for now.
- [ ] **Styling**: Iteratively apply CSS to Eww, Hyper, and Fuzzel.

---

## 🚀 Next Steps
1. Create the directory structure.
2. Move `hardware-configuration.nix` to `hosts/desktop/`.
3. Update `flake.nix` to point to the new structure.
