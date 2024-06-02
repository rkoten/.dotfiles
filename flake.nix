{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    hyprland.url = "github:hyprwm/Hyprland/v0.40.0";  # Append `?ref=v{version}` to specify version tag.
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";  # Guarantees that plugins will always be built using locked Hyprland version.
    };
    hy3 = {
      # It's recommended to match hy3 version tag to hyperland version tag.
      url = "github:outfoxxed/hy3/hl0.40.0";  # Append `?ref=hl{version}` to specify version tag.
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = flakeInputs@{ self, nixpkgs, ... }: {
    nixosConfigurations.rmdesklin = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
      specialArgs = { inherit flakeInputs; };
    };
  };
}
