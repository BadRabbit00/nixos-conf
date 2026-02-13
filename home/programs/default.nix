{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Browsers
    firefox
    google-chrome

    # Editors
    vscode
    nano
    spotify

    # File Manager
    xfce.thunar
    xfce.thunar-archive-plugin
    xfce.thunar-volman
    
    # System Tray Tools
    networkmanagerapplet # Network icon in tray
    pasystray            # Audio icon in tray

    # Theming Tools
    hyprpicker
    wl-clipboard
  ];

  # Configure Nano
  home.file.".nanorc".text = ''
    set linenumbers
    set tabsize 2
    set tabstospaces
  '';
}
