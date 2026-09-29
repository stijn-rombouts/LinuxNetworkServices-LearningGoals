{ config, pkgs, ... }:

let
  bootstrapLdif = ./ldap-bootstrap/01-init.ldif;
in
{
  # Enable OCI container daemon backend
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      # OpenLDAP Directory Server
      openldap = {
        image = "osixia/openldap:1.5.0";
        autoStart = true;
        cmd = [ "--copy-service" ];
        ports = [
          "389:389"
          "636:636"
        ];
        environment = {
          LDAP_ORGANISATION = "Lab LAN";
          LDAP_DOMAIN = "lab.lan";
          LDAP_BASE_DN = "dc=lab,dc=lan";
          LDAP_ADMIN_PASSWORD = "adminpassword";
          LDAP_CONFIG_PASSWORD = "configpassword";
          LDAP_READONLY_USER = "true";
          LDAP_READONLY_USER_USERNAME = "readonly";
          LDAP_READONLY_USER_PASSWORD = "readonlypassword";
          LDAP_TLS = "false"; # TLS disabled for initial lab simplicity
          LDAP_REMOVE_CONFIG_AFTER_SETUP = "false";
        };
        volumes = [
          "/var/lib/openldap/data:/var/lib/ldap"
          "/var/lib/openldap/config:/etc/ldap/slapd.d"
          "/var/lib/openldap/bootstrap:/container/service/slapd/assets/config/bootstrap/ldif/custom"
        ];
      };

      # phpLDAPadmin Web GUI
      phpldapadmin = {
        image = "osixia/phpldapadmin:0.9.0";
        autoStart = true;
        ports = [
          "8080:80"
        ];
        environment = {
          PHPLDAPADMIN_LDAP_HOSTS = "10.0.69.15";
          PHPLDAPADMIN_HTTPS = "false";
        };
        dependsOn = [ "openldap" ];
      };
    };
  };

  # Automatically provision bootstrap directory and copy 01-init.ldif
  systemd.tmpfiles.rules = [
    "d /var/lib/openldap 0755 root root -"
    "d /var/lib/openldap/data 0755 root root -"
    "d /var/lib/openldap/config 0755 root root -"
    "d /var/lib/openldap/bootstrap 0755 root root -"
    "C+ /var/lib/openldap/bootstrap/01-init.ldif 0644 root root - ${bootstrapLdif}"
  ];

  # Provide LDAP client utilities on the server host
  environment.systemPackages = [
    pkgs.openldap
  ];
}
