{
  lib,
  pkgs,
  options,
  ...
} @ args:
{
  config = lib.mkMerge [
    {
      # Bootloader setup - overwritten by BIOS boot in pc-bios-mutable
      boot.loader.systemd-boot.enable = lib.mkDefault true;
      boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

      # NixOS garbage collection and store optimization
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      nix.settings.auto-optimise-store = true;

      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "yes";
      users.users.root.initialPassword = "root";

      # Set keyboard layout to Belgian
      console.keyMap = "be-latin1";

      # Set timezone and NTP
      time.timeZone = "Europe/Brussels";
      services.timesyncd.enable = true;

      environment.systemPackages = [
        pkgs.curl
        pkgs.gitMinimal
        pkgs.btop
        pkgs.htop
        pkgs.wget
        pkgs.pciutils
        pkgs.dnsutils
      ];

      users.users.nixos = {
        isNormalUser = true;
        extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
        initialPassword = "nixos";
      };

      # Enable automatic disk resizing on boot
      boot.growPartition = true;

      # Ensure the ext4/XFS filesystem expands to fill the grown partition
      fileSystems."/".autoResize = true;

      # Enable serial console for Proxmox (xterm.js & qm terminal)
      boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" ];

      # Ensure systemd starts a getty on the serial port
      systemd.services."serial-getty@ttyS0" = {
        enable = true;
        wantedBy = [ "getty.target" ];
        serviceConfig.Restart = "always";
      };

      system.stateVersion = "26.05";
    }
  ];
}
