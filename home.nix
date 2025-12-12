{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage
  home.username = "user";
  home.homeDirectory = "/home/user";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "24.05"; # Don't change this

  # User packages
  home.packages = with pkgs; [
    # Add your packages here
    # Example:
    # firefox
    # vscode
    # htop
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "your.email@example.com";
  };

  # Bash configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      # Note: Replace 'default' with your hostname if you changed it in flake.nix
      update = "sudo nixos-rebuild switch --flake .#default";
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
