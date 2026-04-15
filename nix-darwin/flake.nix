{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, emacs-overlay }:
    {
      darwinConfigurations."simple" = nix-darwin.lib.darwinSystem {
        modules = [
          ./common.nix
          ./personal.nix
          {
            nixpkgs.overlays = [ emacs-overlay.overlays.default ];
          }
          {
            system.configurationRevision = self.rev or self.dirtyRev or null;
          }
        ];
      };

      darwinPackages = self.darwinConfigurations."simple".pkgs;
    };
}
