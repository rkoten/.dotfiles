{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
  };

  outputs = { self, nixpkgs, ... }@flakeInputs:
    let
      currentSystem = builtins.currentSystem;
    in {
      nixosConfigurations.rmdesklin = nixpkgs.lib.nixosSystem {
        system = currentSystem;
        modules = [ ./configuration.nix ];
        specialArgs = {
          inherit flakeInputs;
          inherit currentSystem;
        };
      };
    };
}
