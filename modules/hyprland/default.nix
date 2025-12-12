{ pkgs, ... }:

{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Environment variables for Wayland
  environment.sessionVariables = {
    # Hint Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
    # Fix for some Java apps
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  # Display Manager (SDDM)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    # We will use a nice theme. 'where-is-my-sddm-theme' is a popular clean choice in nixpkgs.
    theme = "where_is_my_sddm_theme";
  };

  # Install the theme
  environment.systemPackages = with pkgs; [
    where-is-my-sddm-theme
    # Add other Hyprland essentials here if they are system-wide
    bibata-cursors
  ];
  
  # Enable OpenGL
  hardware.graphics.enable = true;
}
