# DNS & DHCP Implementatieplan (Server VM 1)

Dit document beschrijft de architectuur, configuratie en verificatiestappen voor de native **DNS** en **DHCP** services op de centrale server (**VM 1 / `proxmox-vm-1`**).

---

## 🎯 Doelstellingen

Volgens de leerdoelen van [ARCHITECTURE.md](file:///home/stijn/Documents/git/LinuxNetworkServices-LearningGoals/ARCHITECTURE.md) fungeert VM 1 als de centrale infrastructuurserver. De netwerkservices moeten:
1. **DHCP**: Dynamisch IP-adressen toewijzen aan clients op het lab-netwerk (`10.0.69.0/24`), inclusief gateway, subnetmasker en DNS-server.
2. **DNS**: Zowel lokale naamresolutie binnen het privédomein (`lab.lan`) als upstream forwarding voor externe domeinen verzorgen.
3. **Automatische Host-registratie**: DHCP-clients met een hostname automatisch registreerbaar maken in DNS via Dnsmasq.

---

## ⚙️ Servicekeuze: Dnsmasq

Voor dit lab is gekozen voor **Dnsmasq** als geïntegreerde DNS- en DHCP-server.

### Voordelen:
* **Alles-in-één oplossing**: Eén lichtgewicht daemon (< 10 MB RAM) beheert zowel DNS caching/forwarding als DHCP.
* **Automatische Dynamic DNS**: Hostnames die via DHCP worden aangeboden, worden direct door de interne DNS-server opgenomen zonder complexe TSIG/DDNS-koppelingen.
* **Declaratieve NixOS integratie**: Volledig configureerbaar via `services.dnsmasq.settings`.

---

## 🌐 Netwerkparameters

| Parameter | Waarde | Beschrijving |
| :--- | :--- | :--- |
| **Lab Domein** | `lab.lan` | Privé lokaal lab-domein |
| **Server Hostname** | `server.lab.lan` | Hostnaam van VM 1 |
| **Server IP (VM 1)** | `10.0.69.15/24` | Vast IP-adres op interface `ens18` |
| **Standaard Gateway** | `10.0.69.1` | Proxmox / Host gateway |
| **Upstream DNS Server** | `1.1.1.1` | Cloudflare DNS voor internetlookups |
| **DHCP IP-Range** | `10.0.69.100` – `10.0.69.200` | Dynamische IP-pool voor clients |
| **DHCP Leasetime** | `12h` | Duur van een DHCP-lease |
| **Subnetmasker** | `255.255.255.0` (`/24`) | Subnet voor lab VM's |

### Statische DNS Records

De server publiceert standaard de volgende statische A-records:

| FQDN | IP-adres | Functie |
| :--- | :--- | :--- |
| `server.lab.lan` | `10.0.69.15` | Centrale NixOS server |
| `ldap.lab.lan` | `10.0.69.15` | OpenLDAP authenticatiedienst (Docker) |
| `samba.lab.lan` | `10.0.69.15` | Samba fileserver (SMB share) |
| `client.lab.lan` | `10.0.69.25` | Client VM (VM 2) |

---

## 📁 NixOS Bestandsstructuur

De configuratie is modulair opgebouwd onder `NIX/proxmox-vm-1`:

```
NIX/proxmox-vm-1/
├── base-configuration.nix
├── configuration.nix           <-- Importeert services/dnsmasq.nix en stelt nameservers in
├── disk-config.nix
├── hardware-configuration.nix
└── services/
    └── dnsmasq.nix             <-- Declaratieve DNS & DHCP module
```

### Module `services/dnsmasq.nix`

```nix
{ config, pkgs, ... }:

{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;

    settings = {
      # Netwerkinterfaces & binding
      interface = [ "ens18" "lo" ];
      bind-interfaces = true;

      # Upstream forwarding (geen loop met lokaal resolv.conf)
      no-resolv = true;
      server = [ "1.1.1.1" "1.0.0.1" ];
      domain-needed = true;
      bogus-priv = true;

      # Lokaal domein
      domain = "lab.lan";
      local = [ "/lab.lan/" ];
      expand-hosts = true;

      # DHCP pool & opties
      dhcp-range = [ "10.0.69.100,10.0.69.200,255.255.255.0,12h" ];
      dhcp-option = [
        "option:router,10.0.69.1"
        "option:dns-server,10.0.69.15"
        "option:domain-name,lab.lan"
      ];
      dhcp-authoritative = true;

      # Statische A-records
      address = [
        "/server.lab.lan/10.0.69.15"
        "/ldap.lab.lan/10.0.69.15"
        "/samba.lab.lan/10.0.69.15"
        "/client.lab.lan/10.0.69.25"
      ];
    };
  };

  # Firewall-poorten voor DNS en DHCP
  networking.firewall = {
    allowedUDPPorts = [ 53 67 ];
    allowedTCPPorts = [ 53 ];
  };
}
```

---

## 🚀 Uitrol- & Verificatiestappen (Handmatig door beheerder)

> [!NOTE]
> De configuratie wordt niet automatisch gedeployed. Volg onderstaande commando's op het beheerstation / jump host om de wijzigingen te activeren.

### 1. Wijzigingen stagen in Git
```bash
git add NIX/proxmox-vm-1/
```

### 2. VM 1 Rebuilden via NixOS Flake
```bash
nixos-rebuild switch --flake .#proxmox-vm-1 --target-host root@10.0.69.15
```

### 3. Status controleren op VM 1
Log in op VM 1 (`ssh root@10.0.69.15`) en voer uit:
```bash
# Controleer of dnsmasq actief is
systemctl status dnsmasq

# Bekijk recente logs
journalctl -u dnsmasq -n 50 --no-pager
```

### 4. DNS-resolutie testen
```bash
# Test lokale FQDN resolutie
dig @10.0.69.15 server.lab.lan +short
# Verwacht: 10.0.69.15

dig @10.0.69.15 ldap.lab.lan +short
# Verwacht: 10.0.69.15

# Test upstream forwarding naar internet
dig @10.0.69.15 google.com +short
```

### 5. DHCP-functionaliteit testen
Vanaf een client machine (bijv. VM 2):
```bash
# Vraag een nieuw DHCP-lease aan
dhclient -r && dhclient ens18

# Controleer verkregen IP en router
ip addr show ens18
ip route show

# Controleer DNS-server in resolv.conf
cat /etc/resolv.conf
```

Controleer op VM 1 actieve leases:
```bash
cat /var/lib/dnsmasq/dnsmasq.leases
```
