{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Browsers
    firefox
    google-chrome

    # Editors
    vscode
    nano

    # File Manager
    xfce.thunar
    xfce.thunar-archive-plugin
    xfce.thunar-volman
    
    # System Tray Tools
    networkmanagerapplet # Network icon in tray
    pasystray            # Audio icon in tray
  ];

  # Configure Nano
  home.file.".nanorc".text = ''
    set linenumbers
    set tabsize 2
    set tabstospaces
  '';
}
