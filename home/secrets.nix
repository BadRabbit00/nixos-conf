{ lib, isNixOS ? true, sopsAgeKeyFile ? null, ... }:

{
  # NixOS keeps its existing system sops module and /run/secrets untouched.
  # On Arch decryption is an unprivileged sops-nix user service, opt-in via flake.
  sops = lib.mkIf (!isNixOS && sopsAgeKeyFile != null) {
    age.keyFile = sopsAgeKeyFile;
    defaultSopsFile = ../modules/core/secrets/secrets.yaml;
    secrets.context7_api_key = { };
  };
}
