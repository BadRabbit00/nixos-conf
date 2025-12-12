# Configuration Examples

## Desktop Environment Examples

### Example 1: GNOME Desktop
```nix
# Add to configuration.nix
services.xserver = {
  enable = true;
  displayManager.gdm.enable = true;
  desktopManager.gnome.enable = true;
  layout = "us,ru";
  xkbOptions = "grp:alt_shift_toggle";
};

# Add to home.nix packages
home.packages = with pkgs; [
  gnome.gnome-tweaks
  gnomeExtensions.appindicator
];
```

### Example 2: KDE Plasma
```nix
# Add to configuration.nix
services.xserver = {
  enable = true;
  displayManager.sddm.enable = true;
  desktopManager.plasma5.enable = true;
};
```

### Example 3: i3 Window Manager
```nix
# Add to configuration.nix
services.xserver = {
  enable = true;
  displayManager.lightdm.enable = true;
  windowManager.i3.enable = true;
};

# Add to home.nix
xsession.windowManager.i3 = {
  enable = true;
  config = {
    modifier = "Mod4";
    terminal = "alacritty";
  };
};
```

## Development Environment Examples

### Example 4: Web Development
```nix
# Add to home.nix
home.packages = with pkgs; [
  vscode
  nodejs_20
  nodePackages.npm
  nodePackages.typescript
  nodePackages.eslint
  nodePackages.prettier
  firefox
  google-chrome
];

programs.git = {
  enable = true;
  userName = "Your Name";
  userEmail = "your@email.com";
  extraConfig = {
    init.defaultBranch = "main";
    pull.rebase = true;
  };
};
```

### Example 5: Python Development
```nix
# Add to home.nix
home.packages = with pkgs; [
  python311
  python311Packages.pip
  python311Packages.virtualenv
  poetry
  vscode
];
```

### Example 6: Docker Development
```nix
# Add to configuration.nix
virtualisation.docker.enable = true;
users.users.user.extraGroups = [ "docker" ];

# Add to home.nix
home.packages = with pkgs; [
  docker-compose
  lazydocker
];
```

## Multimedia Examples

### Example 7: Audio Production
```nix
# Add to configuration.nix
sound.enable = true;
security.rtkit.enable = true;
services.pipewire = {
  enable = true;
  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;
  jack.enable = true;
};

# Add to home.nix
home.packages = with pkgs; [
  ardour
  audacity
  lmms
];
```

### Example 8: Video Editing
```nix
# Add to home.nix
home.packages = with pkgs; [
  kdenlive
  obs-studio
  mpv
  vlc
  ffmpeg
];
```

## Gaming Example

### Example 9: Gaming Setup
```nix
# Add to configuration.nix
programs.steam.enable = true;
hardware.opengl.driSupport32Bit = true;
hardware.pulseaudio.support32Bit = true;

# Add to home.nix
home.packages = with pkgs; [
  lutris
  wine
  winetricks
  gamemode
];
```

## Office and Productivity

### Example 10: Office Suite
```nix
# Add to home.nix
home.packages = with pkgs; [
  libreoffice-fresh
  hunspell
  hunspellDicts.en_US
  hunspellDicts.ru_RU
  thunderbird
  telegram-desktop
  discord
];
```

## Shell Configuration

### Example 11: ZSH with Oh-My-Zsh
```nix
# Add to home.nix
programs.zsh = {
  enable = true;
  enableCompletion = true;
  autosuggestion.enable = true;
  syntaxHighlighting.enable = true;
  
  oh-my-zsh = {
    enable = true;
    theme = "robbyrussell";
    plugins = [ "git" "docker" "kubectl" ];
  };
  
  shellAliases = {
    ll = "ls -la";
    update = "sudo nixos-rebuild switch --flake ~/.config/nixos#default";
    upgrade = "nix flake update ~/.config/nixos && sudo nixos-rebuild switch --flake ~/.config/nixos#default";
  };
};

# Add to configuration.nix
programs.zsh.enable = true;
users.users.user.shell = pkgs.zsh;
```

### Example 12: Starship Prompt
```nix
# Add to home.nix
programs.starship = {
  enable = true;
  settings = {
    add_newline = true;
    character = {
      success_symbol = "[➜](bold green)";
      error_symbol = "[➜](bold red)";
    };
  };
};
```

## Security Examples

### Example 13: Firewall Configuration
```nix
# Add to configuration.nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 80 443 ];
  allowedUDPPorts = [ 53 ];
  allowPing = true;
};
```

### Example 14: SSH Configuration
```nix
# Add to configuration.nix
services.openssh = {
  enable = true;
  settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
  };
};

# Add to home.nix
programs.ssh = {
  enable = true;
  matchBlocks = {
    "github" = {
      hostname = "github.com";
      user = "git";
      identityFile = "~/.ssh/id_ed25519";
    };
  };
};
```

## System Optimization

### Example 15: Performance Tuning
```nix
# Add to configuration.nix
# Enable SSD TRIM
services.fstrim.enable = true;

# Optimize nix store automatically
nix.settings.auto-optimise-store = true;

# Automatic garbage collection
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

# Limit journal size
services.journald.extraConfig = ''
  SystemMaxUse=100M
'';
```

## Usage

Copy any of these examples into your configuration files and adjust as needed. Remember to run `sudo nixos-rebuild switch --flake .#default` after making changes.
