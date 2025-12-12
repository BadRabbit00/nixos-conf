{ pkgs, ... }:

{
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.useOSProber = true; # For Windows dual boot
  
  # Optional: Grub theme (we can add this later)
  # boot.loader.grub.theme = ...
}
