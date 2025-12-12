# Quick Reference Guide

## Commonly Used Commands

### System Management
```bash
# Apply configuration changes
sudo nixos-rebuild switch --flake .#default

# Test configuration without switching
sudo nixos-rebuild test --flake .#default

# Build configuration without activating
sudo nixos-rebuild build --flake .#default

# Check configuration syntax
nix flake check

# Update flake inputs
nix flake update
```

### Package Management
```bash
# Search for packages
nix search nixpkgs package-name

# Install package temporarily
nix shell nixpkgs#package-name

# Run package without installing
nix run nixpkgs#package-name
```

### System Maintenance
```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Delete old generations (keep last 3)
sudo nix-env --delete-generations +3 --profile /nix/var/nix/profiles/system

# Garbage collection
sudo nix-collect-garbage
sudo nix-collect-garbage -d  # Delete everything not currently in use

# Optimize nix store
nix-store --optimise
```

### Home Manager
```bash
# Apply home-manager changes separately (if needed)
home-manager switch --flake .#user

# List home-manager generations
home-manager generations
```

## File Locations

- System configuration: `/etc/nixos/`
- Nix store: `/nix/store/`
- User profiles: `~/.nix-profile/`
- System profile: `/run/current-system/`

## Useful NixOS Options

### Desktop Environment
```nix
# GNOME
services.xserver.enable = true;
services.xserver.displayManager.gdm.enable = true;
services.xserver.desktopManager.gnome.enable = true;

# KDE Plasma
services.xserver.enable = true;
services.xserver.displayManager.sddm.enable = true;
services.xserver.desktopManager.plasma5.enable = true;

# XFCE
services.xserver.enable = true;
services.xserver.displayManager.lightdm.enable = true;
services.xserver.desktopManager.xfce.enable = true;
```

### Common Services
```nix
# Docker
virtualisation.docker.enable = true;
users.users.user.extraGroups = [ "docker" ];

# PostgreSQL
services.postgresql.enable = true;
services.postgresql.package = pkgs.postgresql_15;

# Redis
services.redis.servers."".enable = true;

# Printing
services.printing.enable = true;

# Sound
sound.enable = true;
hardware.pulseaudio.enable = true;
# OR for pipewire:
security.rtkit.enable = true;
services.pipewire = {
  enable = true;
  alsa.enable = true;
  pulse.enable = true;
};
```

### Useful System Settings
```nix
# Auto-upgrade
system.autoUpgrade.enable = true;
system.autoUpgrade.allowReboot = false;

# Automatic garbage collection
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

# Bluetooth
hardware.bluetooth.enable = true;

# Firewall
networking.firewall.enable = true;
networking.firewall.allowedTCPPorts = [ 22 80 443 ];
```

## Troubleshooting

### Build fails
```bash
# Clean build
sudo nixos-rebuild switch --flake .#default --option eval-cache false

# Update flake lock
nix flake update
```

### Boot issues
- At boot menu, select an older generation
- After booting, investigate and fix configuration
- Apply corrected configuration

### Disk space
```bash
# Check space
df -h /nix

# Clean up aggressively
sudo nix-collect-garbage -d
sudo nix-store --optimise
```

## Tips

1. Always commit working configurations to git
2. Test configurations before switching: `nixos-rebuild test`
3. Keep at least 2-3 recent generations
4. Use `nix search` to find package names
5. Check NixOS options: https://search.nixos.org/options
6. Check packages: https://search.nixos.org/packages
