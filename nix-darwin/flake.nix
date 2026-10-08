{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    haru = {
      url = "github:ruaylabs/haru";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    emacs-src = {
      url = "github:emacs-mirror/emacs/65dc4f1c6d91c85911daea3e913adcb91e0e65b2";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, emacs-src, haru }:
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
        specialArgs = { inherit emacs-src haru; };
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."simple".pkgs;
    };
}
