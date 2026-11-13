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
      "evaserver-local" = {
        HostName = "192.168.10.52";
        User = "BadRabbit";
        IdentityFile = "~/.ssh/eva_server";
        IdentitiesOnly = true;
        ServerAliveInterval = 60;
      };
    };
  };
}
