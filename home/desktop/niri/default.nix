{ pkgs, ... }:

{
  home.packages = with pkgs; [
    swaybg
    grim
    slurp
    wl-clipboard
    xwayland-satellite
    hyprlock
    hypridle
    playerctl
  ];

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
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
        lock_cmd = pidof hyprlock || hyprlock
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
}
