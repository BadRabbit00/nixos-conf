{ pkgs, ... }:

{
  # Steam Configuration
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for a Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    gamescopeSession.enable = true; # Enables a Gamescope session from the display manager
  };

  # Feral Interactive's GameMode
  programs.gamemode.enable = true;

  # Gamescope - Micro-compositor for gaming
  programs.gamescope.enable = true;

  # Additional Gaming Tools
  environment.systemPackages = with pkgs; [
    mangohud       # Performance overlay
    protonup-qt    # Easy Proton-GE management
    lutris         # Open gaming platform
    heroic         # Epic/GOG/Amazon launcher
    bottles        # Run Windows software
    vulkan-tools   # vulkaninfo, etc.
    osu-lazer-bin  # Rhythm game
  ];
}
