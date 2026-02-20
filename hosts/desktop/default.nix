{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/bootloader.nix
    ../../modules/core/network.nix
    ../../modules/core/user.nix
    ../../modules/core/system.nix
    ../../modules/core/program.nix
    ../../modules/core/audio.nix
    ../../modules/core/nvidia.nix
    ../../modules/hyprland/default.nix
  ];
  
  # ACL Support
  fileSystems."/".options = [ "acl" ];
  services.logind.settings.Login.HandleLidSwitch = "hibernate";

  # Custom SSH Key Name
  services.openssh.enable = true;

  # Hibernation Support (Swap File)
  swapDevices = [ {
    device = "/swapfile";
    size = 32 * 1024; # 32GB
  } ];

  system.stateVersion = "24.05";
}
