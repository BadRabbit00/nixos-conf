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
    # NVIDIA Support
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1"; # Fix for missing cursor on NVIDIA
  };

  # Display Manager (greetd)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # Install essential system packages
  environment.systemPackages = with pkgs; [
    bibata-cursors
    tuigreet
  ];
  
  # Enable OpenGL
  hardware.graphics.enable = true;
}
