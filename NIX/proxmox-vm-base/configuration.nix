{ modulesPath, lib, pkgs, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./base-configuration.nix
    ./disk-config.nix
  ];

  services.qemuGuest.enable = true;
}
