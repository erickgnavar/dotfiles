# Helium for NixOS

Standalone flake following [Hitsu's packaging layout][hitsu]. Packages the upstream Linux
binary distribution of [Helium][helium], version **0.20.1.1**, for **x86_64-linux**.
It includes the desktop entry, icon, URL associations, and ChromeDriver.

The browser archive is SHA-256 pinned. `flake.lock` initially reuses the nixpkgs revision
from `../nixos/flake.lock`; updating either lock file does not update the other.
No existing NixOS configuration is changed automatically.

## Build and run

From the repository root:

```sh
nix build ./helium
nix run ./helium -- --version
nix run ./helium
nix flake check ./helium
```

For a per-user installation:

```sh
nix profile install ./helium
```

If working in a Git checkout, stage the new `helium/` files before using a Git-backed
flake reference so Nix can see them.

## Install declaratively in this repository

Add an input to `nixos/flake.nix`, alongside the existing inputs:

```nix
helium = {
  url = "path:../helium";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Add `helium` to the `outputs` arguments and pass it to the existing NixOS configuration:

```nix
outputs = { self, nixpkgs, haru, helium }: {
  nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit haru helium; };
    modules = [ ./configuration.nix ];
  };
};
```

In `nixos/configuration.nix`, add `helium` to the module arguments, then add this package
to the existing `environment.systemPackages` list:

```nix
helium.packages.${pkgs.stdenv.hostPlatform.system}.default
```

Rebuild from the repository root:

```sh
sudo nixos-rebuild switch --flake ./nixos#nixos
```

Alternatively, after publishing these files, another flake can use:

```nix
helium.url = "github:erickgnavar/dotfiles?dir=helium";
```

Optionally set the default browser for your desktop session:

```sh
xdg-settings set default-web-browser helium.desktop
```

## Runtime and updates

- Uses native ELF patching and GTK environment wrapping, not an AppImage/FHS environment.
- Keeps Chromium's sandbox enabled; does not inject `--no-sandbox`. NixOS must allow
  unprivileged user namespaces, as for other Chromium-based browsers without a setuid helper.
- Uses the system Vulkan loader and includes Wayland, audio, and PipeWire runtime libraries.
  Actual hardware acceleration depends on the host's graphics configuration and drivers.
- To request native Wayland explicitly: `nix run ./helium -- --ozone-platform=wayland`.
- Nix manages updates. Change `version` and the archive `hash` in `nix/package.nix` for new
  browser releases. Updating nixpkgs alone does not update Helium. Keep browser security
  updates current; this package does not download replacement browser binaries at runtime.
- ARM64 upstream releases exist but are not packaged by this flake yet.

The flake's checks build the package and exercise `helium --version`. They do not test
sandbox operation, desktop integration, video playback, or Wayland rendering. Before relying
on the package, run these checks on NixOS and verify `chrome://sandbox`, `chrome://gpu`, audio,
video, URL opening, and screen sharing in a real session.

[hitsu]: https://github.com/ruaylabs/hitsu/tree/master/nix
[helium]: https://github.com/imputnet/helium-linux
