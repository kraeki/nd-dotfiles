# NixOS Flake Configuration - naptop

This repository contains the declarative configuration for my NixOS system (`naptop`), using **Nix flakes** and **Home Manager**.

---

## 🧭 Structure

```text
.
├── flake.nix             # Main flake file
├── flake.lock            # Locked versions of inputs
├── hosts/
│   └── naptop/           # Host-specific system config
│       └── configuration.nix
└── home/
    └── kraeki/           # Home Manager config for user 'kraeki'
        └── home.nix
```

## 🛠️ Usage

### Rebuild System

```bash
sudo nixos-rebuild switch --flake .#naptop
```

You can also use `boot` or `test` instead of `switch`.

### Update Flake inputs (e.g. nixpkgs)

```bash
nix flake update
sudo nixos-rebuild switch --flake .#naptop
```

This updates `flake.lock` to track the latest versions of your inputs (like `nixpkgs` or `home-manager`).
