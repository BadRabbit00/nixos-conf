{ pkgs, ... }:

{
  networking.hostName = "badrabbitpc"; # We can change this per host if needed
  networking.networkmanager.enable = true;
  
  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Firewall settings if needed
  # networking.firewall.allowedTCPPorts = [ ... ];
}
