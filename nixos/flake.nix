{
  description = "NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    helium = {
      url = "path:../helium";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    haru = {
      url = "github:ruaylabs/haru";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, haru, helium }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit haru helium; };
      modules = [ ./configuration.nix ];
    };
  };
}
