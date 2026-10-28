{
  description = "Helium browser for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      helium = pkgs.callPackage ./nix/package.nix { };
    in
    {
      packages.${system} = {
        inherit helium;
        default = helium;
      };

      apps.${system}.default = {
        type = "app";
        program = "${helium}/bin/helium";
      };

      checks.${system} = {
        inherit helium;
        version = pkgs.testers.testVersion {
          package = helium;
        };
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
