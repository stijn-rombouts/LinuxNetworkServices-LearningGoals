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

**Docker VM**:
```bash
nixos-rebuild switch --flake .#proxmox-vm-1 --target-host root@10.0.69.15
```


## NixOS Anywhere
### Base VM
```bash
nix run github:nix-community/nixos-anywhere -- --flake .#proxmox-vm-base root@<VM-IP>
```
