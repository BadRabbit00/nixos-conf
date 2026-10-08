{ pkgs, lib, isNixOS ? true, ... }:

{
  home.packages = with pkgs; [
    swaybg
    grim
    slurp
    wl-clipboard
    # xwayland-satellite ставится системно в modules/niri/default.nix (убран дубль).
  ] ++ lib.optionals isNixOS [ hyprlock hypridle ] ++ [ playerctl ];

  xdg.configFile."niri/config.kdl" = if isNixOS then {
    source = ./config.kdl;
  } else {
    # GDM already authenticated the user. Keep greetd's startup lock on NixOS.
    # Arch niri manages Xwayland on demand; don't force DISPLAY=:0 or start a
    # second satellite manually. All other bindings come from the same file.
    text = lib.replaceStrings
      [ ''spawn-at-startup "hyprlock"''
        ''spawn-at-startup "xwayland-satellite"''
        ''    DISPLAY ":0"''
        ''spawn "hyprlock"'' ]
      [ "// GDM handles authentication at login."
        "// niri starts the system xwayland-satellite on demand."
        ""
        ''spawn "/usr/bin/hyprlock"'' ]
      (builtins.readFile ./config.kdl);
  };
  xdg.configFile."hypr/hyprlock.conf".source = ./hyprlock.conf;
  
  # Пробрасываем скрипты и фразы для локера
  home.file.".config/niri/scripts/random_phrase.sh" = {
    source = ./scripts/random_phrase.sh;
    executable = true;
  };
  home.file.".config/niri/scripts/fail_text.sh" = {
    source = ./scripts/fail_text.sh;
    executable = true;
  };
  home.file.".config/niri/scripts/phrases.txt".source = ./scripts/phrases.txt;
  
  # hypridle config
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || ${if isNixOS then "hyprlock" else "/usr/bin/hyprlock"}
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = niri msg action power-on-monitors
    }

    listener {
        timeout = 300
        on-timeout = loginctl lock-session
    }

    listener {
        timeout = 330
        on-timeout = niri msg action power-off-monitors
        on-resume = niri msg action power-on-monitors
    }
  '';

  # Binaries, PAM and polkit policy belong to pacman; HM owns only user units.
  systemd.user.services = lib.mkIf (!isNixOS) {
    hypridle = {
      Unit = {
        Description = "Idle locking for niri";
        After = [ "niri.service" ];
        PartOf = [ "niri.service" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = { ExecStart = "/usr/bin/hypridle"; Restart = "on-failure"; };
      Install.WantedBy = [ "niri.service" ];
    };
    niri-polkit-agent = {
      Unit = {
        Description = "Polkit authentication agent for niri";
        After = [ "niri.service" ];
        PartOf = [ "niri.service" ];
      };
      Service = {
        ExecStart = "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "niri.service" ];
    };
  };
}
