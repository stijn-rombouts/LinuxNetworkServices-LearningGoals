{ config, pkgs, ... }:

{
  # Samba SMB/CIFS File Server
  services.samba = {
    enable = true;

    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "Lab Samba Server";
        "netbios name" = "SAMBA";
        "security" = "user";
        "map to guest" = "Bad User";
        "hosts allow" = "10.0.69. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
      };

      # Public Share (Guest accessible, Read/Write)
      public = {
        "path" = "/var/shares/public";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "force user" = "nobody";
        "force group" = "nogroup";
        "create mask" = "0666";
        "directory mask" = "0777";
      };

      # Secured Share (Authenticated users only: user1, user2, nixos)
      secured = {
        "path" = "/var/shares/secured";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "@sambashare nixos user1 user2";
        "force group" = "sambashare";
        "create mask" = "0660";
        "directory mask" = "0770";
      };
    };
  };

  # Web Services Dynamic Discovery host daemon (WSDD)
  # Allows Linux and Windows clients to discover the Samba server automatically
  services.samba-wsdd = {
    enable = true;
  };

  # Automatically provision share directories and permissions
  systemd.tmpfiles.rules = [
    "d /var/shares 0755 root root -"
    "d /var/shares/public 0777 nobody nogroup -"
    "d /var/shares/secured 2770 root sambashare -"
  ];

  # User groups
  users.groups.sambashare = {};

  # Add nixos user to sambashare group
  users.users.nixos.extraGroups = [ "sambashare" ];

  # Provision local user accounts on server host for Samba authentication
  users.users.user1 = {
    isNormalUser = true;
    extraGroups = [ "sambashare" ];
    initialPassword = "Password123!";
  };

  users.users.user2 = {
    isNormalUser = true;
    extraGroups = [ "sambashare" ];
    initialPassword = "Password123!";
  };

  # Automatically initialize Samba passwords in passdb on boot
  systemd.services.samba-init-passwords = {
    description = "Initialize Samba user passwords in passdb";
    after = [ "samba-smbd.service" ];
    wants = [ "samba-smbd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      for u in nixos user1 user2; do
        if id "$u" >/dev/null 2>&1; then
          if ! ${pkgs.samba}/bin/pdbedit -u "$u" >/dev/null 2>&1; then
            echo "Initializing Samba passdb entry for $u..."
            (${pkgs.coreutils}/bin/echo "Password123!"; ${pkgs.coreutils}/bin/echo "Password123!") | ${pkgs.samba}/bin/smbpasswd -s -a "$u"
          fi
        fi
      done
    '';
  };
}
