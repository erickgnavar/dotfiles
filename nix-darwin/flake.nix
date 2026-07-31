{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    emacs-src = {
      url = "github:emacs-mirror/emacs/b6332ac21b12bc15083935574a18d0316d31b02b";
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
