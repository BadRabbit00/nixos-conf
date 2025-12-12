{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos"; # Change this to your hostname
  networking.networkmanager.enable = true;

  # Timezone and localization
  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # User account
  users.users.user = {
    isNormalUser = true;
    description = "User";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
  ];

  # Enable SSH
  services.openssh.enable = true;

  # System version
  system.stateVersion = "24.05"; # Don't change this
}
