{ modulesPath, lib, pkgs, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./base-configuration.nix
    ./disk-config.nix
  ];

  # Proxmox VM with UEFI boot - systemd-boot from base-configuration.nix is used
  # Root filesystem is persistent (mutable) - changes to / survive reboots

  # Enable the QEMU Guest Agent
  services.qemuGuest.enable = true;

  # Limit the boot loader to only keep the last 5 generations
  boot.loader.systemd-boot.configurationLimit = 5;

  # Network Configuration
  networking.useDHCP = false; # Configure interfaces explicitly
  networking.enableIPv6 = false; # Disable IPv6 globally

  # Static IP configuration for ens18
  networking.interfaces.ens18.ipv4.addresses = [
    {
      address = "10.0.69.25";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "10.0.69.1";
  networking.nameservers = [ "10.0.69.1" ];

  # Disable the firewall entirely
  networking.firewall.enable = false;

  # Enable Docker
  virtualisation.docker.enable = true;

  # Add user to docker group
  users.users.nixos.extraGroups = [ "docker" ];

  # Docker Compose tools
  environment.systemPackages = [
    pkgs.docker-compose
  ];
}
