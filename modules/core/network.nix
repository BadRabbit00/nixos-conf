{ pkgs, ... }:

{
  networking.hostName = "nixos"; # We can change this per host if needed
  networking.networkmanager.enable = true;
  
  # Firewall settings if needed
  # networking.firewall.allowedTCPPorts = [ ... ];
}
