{
  description = "NixOS flake configuration for Proxmox VMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }@inputs: {
    nixosConfigurations = {
      proxmox-vm-base = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          # Update this to your Proxmox VM disk (e.g. /dev/vda)
          { disko.devices.disk.disk1.device = "/dev/vda"; }
          ./proxmox-vm-base/configuration.nix
          ./proxmox-vm-base/hardware-configuration.nix
        ];
      };

      proxmox-vm-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          # Update this to your Proxmox VM disk (e.g. /dev/vda)
          { disko.devices.disk.disk1.device = "/dev/vda"; }
          ./proxmox-vm-1/configuration.nix
          ./proxmox-vm-1/hardware-configuration.nix
        ];
      };
    };
  };
}
