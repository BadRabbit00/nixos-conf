{ pkgs, ... }:

{
  # Enable Niri
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  # Environment variables for Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_DESKTOP = "niri";
  };

  # Display Manager (greetd)
  #
  # Один пароль, а не два. Раньше цепочка была: tuigreet спрашивает пароль ->
  # стартует niri -> hyprlock (spawn-at-startup в config.kdl) спрашивает ещё раз.
  # Тот же самый пароль, дважды подряд, за десять секунд.
  #
  # initial_session — автологин ПРИ ЗАГРУЗКЕ: greetd молча поднимает сессию, и
  # единственной дверью остаётся hyprlock. default_session остаётся страховкой:
  # greetd показывает tuigreet, только если сессия завершилась или упала —
  # то есть ровно тогда, когда экрана блокировки нет.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "niri-session";
        user = "BadRabbit";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Install essential system packages
  environment.systemPackages = with pkgs; [
    bibata-cursors
    tuigreet
    xwayland-satellite # For XWayland support in Niri
  ];

  # hardware.graphics включается в modules/core/nvidia.nix (enable + enable32Bit).
}
