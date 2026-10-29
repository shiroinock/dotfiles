{
  description = "shiroino's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Kando 3.x requires a newer nixpkgs; keep existing packages pinned.
    nixpkgs-kando.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-kando, nix-darwin, home-manager, ... }: {
    darwinConfigurations."MacBook-Air" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./system.nix
        home-manager.darwinModules.home-manager
        ({ lib, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = {
            kandoPkgs = nixpkgs-kando.legacyPackages.aarch64-darwin;
          };
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.shiroino = import ./home.nix;
          users.users.shiroino.home = "/Users/shiroino";
        })
      ];
    };
  };
}
