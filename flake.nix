{
  description = "macOS dotfiles (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, nix-darwin, home-manager }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" ];
      mkHost = import ./lib/mkHost.nix;

      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};

      hosts = {
        mac      = { determinate = false; };
        mac-mini = { determinate = false; };
      };
    in
    {
      darwinConfigurations = nixpkgs.lib.mapAttrs (hostName: hostCfg: mkHost {
        inherit inputs hostName system;
        username = "mihiro";
        determinate = hostCfg.determinate;
      }) hosts;

      formatter = forAllSystems (sys:
        nixpkgs.legacyPackages.${sys}.nixpkgs-fmt);

      apps.${system} = {
        build = {
          type = "app";
          meta.description = "Build the darwin system into ./result without activating";
          program = toString (pkgs.writeShellScript "darwin-build" ''
            set -e
            HOST="''${DARWIN_HOST:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
            echo "Building darwin configuration for: ''${HOST}"
            nix build .#darwinConfigurations.''${HOST}.system "$@"
            echo "Build successful. Run 'nix run .#switch' to apply."
          '');
        };

        switch = {
          type = "app";
          meta.description = "Build and activate the darwin system";
          program = toString (pkgs.writeShellScript "darwin-switch" ''
            set -eo pipefail
            HOST="''${DARWIN_HOST:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
            echo "Activating darwin configuration for: ''${HOST}"
            REBUILD=$(nix build --no-link --print-out-paths \
              .#darwinConfigurations.''${HOST}.config.system.build.darwin-rebuild)
            exec sudo "''${REBUILD}/bin/darwin-rebuild" switch --flake .#''${HOST} "$@"
          '');
        };

        update = {
          type = "app";
          meta.description = "Refresh flake.lock (run nix run .#switch afterwards)";
          program = toString (pkgs.writeShellScript "flake-update" ''
            set -e
            echo "Updating flake.lock..."
            nix flake update "$@"
            echo "Done. Run 'nix run .#switch' to apply changes."
          '');
        };
      };
    };
}
