{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    emacs-src = {
      url = "github:emacs-mirror/emacs/58e4dc3c53ab5f685d5077ec6a592e27e141cb08";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, emacs-src }:
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#simple
      darwinConfigurations."simple" = nix-darwin.lib.darwinSystem {
        modules = [
          ./common.nix
          ./personal.nix
          {
            # Set Git commit hash for darwin-version.
            system.configurationRevision = self.rev or self.dirtyRev or null;
          }
        ];
        specialArgs = { inherit emacs-src; };
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."simple".pkgs;
    };
}
