{ pkgs, ... }:

{
  programs.eww = {
    enable = true;
    configDir = ./config;
  };

  home.packages = with pkgs; [
    cava
    pamixer
    jq              # For parsing JSON in keyboard layout detection
    networkmanager  # For nmcli wifi info
  ];
}
