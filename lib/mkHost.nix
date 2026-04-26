{ inputs, hostName, system, username, determinate ? false }:

let
  dotfilesPath = "/Users/${username}/Documents/personal/dotfiles";
in
inputs.nix-darwin.lib.darwinSystem {
  inherit system;
  specialArgs = { inherit inputs hostName username system dotfilesPath determinate; };
  modules = [
    ../darwin
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = { inherit inputs username dotfilesPath; };
        users.${username} = import ../home;
      };
    }
  ];
}
