{ config, pkgs, ... }:

{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;

    settings = {
      # Bind to specific interfaces
      interface = [ "ens18" "lo" ];
      bind-interfaces = true;

      # Upstream DNS forwarding
      no-resolv = true;
      server = [ "1.1.1.1" "1.0.0.1" ];
      domain-needed = true;
      bogus-priv = true;

      # Local domain configuration
      domain = "lab.lan";
      local = [ "/lab.lan/" ];
      expand-hosts = true;

      # DHCP server settings
      dhcp-range = [ "10.0.69.100,10.0.69.200,255.255.255.0,12h" ];
      dhcp-option = [
        "option:router,10.0.69.1"
        "option:dns-server,10.0.69.15"
        "option:domain-name,lab.lan"
      ];
      dhcp-authoritative = true;

      # Static DNS records
      address = [
        "/server.lab.lan/10.0.69.15"
        "/ldap.lab.lan/10.0.69.15"
        "/samba.lab.lan/10.0.69.15"
        "/client.lab.lan/10.0.69.25"
      ];
    };
  };

  # Firewall rules for DNS and DHCP
  networking.firewall = {
    allowedUDPPorts = [ 53 67 ];
    allowedTCPPorts = [ 53 ];
  };
}
