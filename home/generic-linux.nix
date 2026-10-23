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
  # Arch has no xterm-kitty entry: kitty and its terminfo come from Nix.
  terminfoDirs = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/share/terminfo"
    "/etc/terminfo"
    "/lib/terminfo"
    "/usr/share/terminfo"
  ];
in
{
  config = lib.mkMerge [
    {
      # One entry point for every home module; NixOS never evaluates nixGL.
      _module.args.gpuWrap = pkg: if isNixOS then pkg else config.lib.nixGL.wrap pkg;
      # Пакеты с CUDA (blender, whisper-cpp) берём из nixpkgs с глобальным
      # cudaSupport: ровно такие варианты лежат в cache.nixos-cuda.org. Точечный
      # `.override { cudaSupport = true; }` даёт другой derivation и сборку
      # из исходников на часы (Blender).
      _module.args.pkgsCuda = import pkgs.path {
        inherit (pkgs) system;
        config = { allowUnfree = true; cudaSupport = true; };
      };
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
      home.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        # genericLinux exports TERMINFO_DIRS only through environment.d, which
        # SSH logins never read. Without it ZLE loses cursor movement and every
        # redraw is appended to the line.
        TERMINFO_DIRS = terminfoDirs;
      };
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
