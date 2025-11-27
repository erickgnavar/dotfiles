1. Install upstream `nix` from `DeterminateSystems`:

```shell
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

2. Make build build, inside `nix-darwin` folder:

> Make sure terminal.app have permissions to access full disk, this is required because we need to modify some system
> preferences

```shell
nix --extra-experimental-features 'nix-command flakes' build ".#darwinConfigurations.simple.system"
```

3. Install build

```shell
sudo ./result/sw/bin/darwin-rebuild switch --flake ".#simple"
```

4. After this we can rebuild system by using this helper function `nixdarwnin_run_install`
