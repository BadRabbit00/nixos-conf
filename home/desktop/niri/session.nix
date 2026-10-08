{ config, lib, pkgs, gpuWrap, isNixOS ? true, sopsAgeKeyFile ? null, ... }:

let
  unit = {
    After = [ "niri.service" ];
    PartOf = [ "niri.service" ];
    Requisite = [ "niri.service" ];
  };
  service = description: command: {
    Unit = unit // { Description = description; };
    Service = { ExecStart = command; Restart = "on-failure"; Environment = [ "TMPDIR=%t" ]; };
    Install.WantedBy = [ "niri.service" ];
  };
in
{
  config = lib.mkIf (!isNixOS) {
    systemd.user.services = {
      # HM's Waybar module adds tray.target even with systemd.targets configured.
      waybar = {
        Unit = {
          PartOf = lib.mkForce [ "niri.service" ];
          Requisite = [ "niri.service" ];
        };
        Install.WantedBy = lib.mkForce [ "niri.service" ];
        Service.Environment = [ "TMPDIR=%t" ];
      };
      hypridle.Unit.Requisite = [ "niri.service" ];
      hypridle.Service.Environment = [ "TMPDIR=%t" ];
      niri-polkit-agent.Unit.Requisite = [ "niri.service" ];
      niri-polkit-agent.Service.Environment = [ "TMPDIR=%t" ];
      swaync = service "Notifications for niri"
        "${gpuWrap pkgs.swaynotificationcenter}/bin/swaync";
      nm-applet = service "Network tray for niri" "${pkgs.networkmanagerapplet}/bin/nm-applet";
      pasystray = service "Audio tray for niri" "${pkgs.pasystray}/bin/pasystray";
      sops-nix = lib.mkIf (sopsAgeKeyFile != null) {
        Unit = unit;
        Install.WantedBy = lib.mkForce [ "niri.service" ];
      };
    };

    # User desktop files take precedence over distro/profile XDG autostarts.
    # The tray apps are launched by the niri-bound units above instead.
    xdg.configFile = lib.genAttrs
      [ "autostart/nm-applet.desktop" "autostart/pasystray.desktop" ]
      (_: { text = "[Desktop Entry]\nType=Application\nHidden=true\n"; });

    # Override both package D-Bus activation entries. Requisite prevents a call
    # from starting swaync in this user's GNOME session (or outside any session).
    xdg.dataFile = lib.mapAttrs (file: busName: {
      text = ''
        [D-BUS Service]
        Name=${busName}
        Exec=${pkgs.coreutils}/bin/false
        SystemdService=swaync.service
      '';
    }) {
      "dbus-1/services/org.erikreider.swaync.service" = "org.freedesktop.Notifications";
      "dbus-1/services/org.erikreider.swaync.cc.service" = "org.erikreider.swaync.cc";
    };

    # sops-nix normally restarts itself at every HM activation, even in GNOME.
    home.activation.sops-nix = lib.mkIf (sopsAgeKeyFile != null) (lib.mkForce ''
      if ${config.systemd.user.systemctlPath} --user is-active --quiet niri.service; then
        ${config.systemd.user.systemctlPath} --user restart sops-nix.service
      fi
    '');
  };
}
