{ config, lib, pkgs, isNixOS ? true, ... }:

let
  sessionPath = lib.concatStringsSep ":" [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.profileDirectory}/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
  sessionDataDirs = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/share"
    "/nix/var/nix/profiles/default/share"
    "/usr/local/share"
    "/usr/share"
  ];
in
{
  config = lib.mkMerge [
    {
      # One entry point for every home module; NixOS never evaluates nixGL.
      _module.args.gpuWrap = pkg: if isNixOS then pkg else config.lib.nixGL.wrap pkg;
    }
    (lib.mkIf (!isNixOS) {
      # Arch's fontconfig must discover the fonts installed by Home Manager.
      fonts.fontconfig.enable = true;
      home.packages = with pkgs; [
        nerd-fonts.commit-mono
        nerd-fonts.space-mono
        nerd-fonts.jetbrains-mono
        noto-fonts-color-emoji
        noto-fonts-cjk-sans
        # Utilities previously inherited from the NixOS system profile.
        bash coreutils gnugrep gnused gawk findutils curl procps
      ];

      # niri-session runs the account's login shell before importing its environment.
      programs.bash.enable = true;
      home.sessionPath = [
        "${config.home.homeDirectory}/.local/bin"
        "${config.home.profileDirectory}/bin"
        "/nix/var/nix/profiles/default/bin"
      ];
      home.sessionVariables.NIXOS_OZONE_WL = "1";
      systemd.user.sessionVariables = {
        PATH = "${sessionPath}:$PATH";
        NIXOS_OZONE_WL = "1";
      };
      # genericLinux already exports XDG_DATA_DIRS in both hm-session-vars.sh and
      # environment.d. Pin both paths for niri as well: niri-session imports GDM's
      # environment, which can overwrite the user manager's environment.d values.
      xdg.configFile."systemd/user/niri.service.d/10-home-manager.conf".text = ''
        [Service]
        Environment="PATH=${sessionPath}"
        Environment="XDG_DATA_DIRS=${sessionDataDirs}"
        Environment="NIXOS_OZONE_WL=1"
        Environment="TMPDIR=%t"
      '';
    })
  ];
}
