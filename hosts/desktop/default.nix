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
    ../../modules/core/gaming.nix
    ../../modules/core/docker.nix
    ../../modules/hyprland/default.nix
  ];
  
  # Legion Pro 5 Touchpad Support
  boot.kernelModules = [ "i2c-hid-acpi" ];
  services.libinput.enable = true;
  
  # ACL Support
  fileSystems."/".options = [ "acl" ];
  
  # Windows Mount
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/72646C41646C0A65";
    fsType = "ntfs3";
    options = [ "ro" "uid=1000" "gid=100" "fmask=0022" "dmask=0022" "nofail" ];
  };

  services.logind.settings = {
    Login = {
      HandleLidSwitch = "poweroff";
      HandlePowerKey = "suspend";
    };
  };

  # Custom SSH Key Name
  services.openssh.enable = true;

  system.stateVersion = "24.05";
}
