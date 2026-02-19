{ pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        identityFile = "~/.ssh/id_github";
        user = "git";
      };
    };
  };
}
