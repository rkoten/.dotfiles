{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@flakeInputs:
    let
      currentSystem = builtins.currentSystem;
    in {
      nixosConfigurations.rmdesklin = nixpkgs.lib.nixosSystem {
        system = currentSystem;
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.rm = import ./home.nix {
                inherit flakeInputs;
                inherit currentSystem;
                username = "rm";
              };
            };
          }
        ];
        specialArgs = {
          inherit flakeInputs;
          inherit currentSystem;
        };
      };
    };
}
