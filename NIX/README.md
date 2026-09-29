# PVE-nixos

## 🚀 Deployment Commands

Before deploying, ensure any file changes/additions are staged in Git:
```bash
git add .
```

```bash
git add -N .
```

### Rebuiding

**VM 1**:
```bash
nixos-rebuild switch --flake .#proxmox-vm-1 --target-host root@10.0.69.15
nix run nixpkgs#nixos-rebuild -- switch --flake .#proxmox-vm-1 --target-host root@10.0.69.15
```

**VM 2**:
```bash
nixos-rebuild switch --flake .#proxmox-vm-2 --target-host root@10.0.69.25
nix run nixpkgs#nixos-rebuild -- switch --flake .#proxmox-vm-2 --target-host root@10.0.69.25
```

## NixOS Anywhere
### Base VM
```bash
nix run github:nix-community/nixos-anywhere -- --flake .#proxmox-vm-base root@<VM-IP>
```
