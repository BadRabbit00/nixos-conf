{ pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        HostName = "github.com";
        IdentityFile = "~/.ssh/id_github";
        User = "git";
      };
      "archbox" = {
        HostName = "ssh.aaag.dev";
        Port = 16179;
        User = "badrabbit";
        IdentityFile = "~/.ssh/arch-box";
        IdentitiesOnly = true;
        ServerAliveInterval = 60;
      };
    };
  };
}
