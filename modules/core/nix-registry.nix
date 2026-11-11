{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  src = inputs.nixpkgs;
  ref = "path:${src.outPath}?narHash=${src.narHash}";

  # Lock кладём рядом: у обёртки в read-only сторе Nix не сможет его
  # записать сам и упадёт; так же исходник не скачивается второй раз.
  lock = {
    version = 7;
    root = "root";
    nodes = {
      root.inputs.nixpkgs = "nixpkgs";
      nixpkgs = {
        inherit (src) lastModified;
        locked = {
          type = "path";
          path = src.outPath;
          inherit (src) narHash lastModified;
        };
        original = {
          type = "path";
          path = src.outPath;
          inherit (src) narHash;
        };
      };
    };
  };

  # Тонкая обёртка над тем же nixpkgs, из которого собрана система, но с
  # allowUnfree: `nix shell/run/build nixpkgs#<unfree>` работает без --impure
  # (NIXPKGS_ALLOW_UNFREE в чистом режиме flake-eval игнорируется).
  # Без cudaSupport и оверлеев, чтобы не терять бинарный кэш.
  wrapper = pkgs.runCommand "nixpkgs-unfree" { } ''
    mkdir $out
    cp ${pkgs.writeText "flake.nix" ''
      {
        description = "nixpkgs with allowUnfree (system registry wrapper)";
        inputs.nixpkgs.url = "${ref}";
        outputs = { nixpkgs, ... }: nixpkgs // {
          legacyPackages = nixpkgs.lib.genAttrs (builtins.attrNames nixpkgs.legacyPackages) (
            system: import nixpkgs { inherit system; config.allowUnfree = true; }
          );
        };
      }
    ''} $out/flake.nix
    cp ${pkgs.writeText "flake.lock" (builtins.toJSON lock)} $out/flake.lock
  '';
in
{
  # Обычное определение бьёт mkDefault из nixpkgs.flake.setFlakeRegistry.
  nix.registry.nixpkgs.to = {
    type = "path";
    path = "${wrapper}";
  };

  # <nixpkgs> и <nixpkgs/nixos> должны вести прямо в исходники: через реестр
  # (flake:nixpkgs) они попали бы в обёртку, где нет default.nix и nixos/.
  # Остальной список повторяет дефолт из nixpkgs-flake.nix.
  nix.nixPath = [
    "nixpkgs=${src.outPath}"
  ]
  ++ lib.optional config.nix.channel.enable "/nix/var/nix/profiles/per-user/root/channels";
}
