{ ... }:

{
  # Tailnet client to reach a remote server. Login is done manually (`tailscale up`).
  # openFirewall, trustedInterfaces and Tailscale SSH are intentionally left off:
  # client only, minimal exposure.
  services.tailscale = {
    enable = true;
    # Loose reverse-path filter so accepted subnet routes / exit nodes work with the firewall.
    useRoutingFeatures = "client";
    # Lets the regular user run tailscale without sudo.
    extraSetFlags = [ "--operator=BadRabbit" ];
  };
}
