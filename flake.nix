{
  description = "Development environments on your infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    drpc.url = "github:storj/drpc/v0.0.32";
  };

  outputs = { self, nixpkgs, flake-utils, drpc }:
    let
      # NOTE: We can't read the latest tag due to purity restrictions.
      # See nix/version.nix for more info.
      tag = "0.9.7";
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        devPackages = import ./nix/dev.nix { inherit pkgs drpc; };
        frontend = import ./site {
          inherit pkgs;
          inherit (versionData) version;
        };
        mkCoder = import ./nix/package.nix;
        mkContainer = import ./nix/container.nix;
        versionData = import ./nix/version.nix { inherit self pkgs tag; };
        inherit (versionData) version;
      in
      {
        formatter = pkgs.nixpkgs-fmt;
        packages = rec {
          default = coder;

          coder = mkCoder {
            inherit pkgs;
            inherit (versionData) version;
          };
          coder-agpl = mkCoder {
            inherit pkgs;
            inherit (versionData) version;
            agpl = true;
          };
          container = mkContainer {
            inherit pkgs coder;
            inherit (versionData) tag;
          };
          container-agpl = mkContainer {
            inherit pkgs;
            coder = coder-agpl;
            inherit (versionData) tag;
          };
        };

        devShells = {
          default = pkgs.mkShell {
            # Install site/node_modules
            inherit (frontend) shellHook;
            buildInputs = devPackages.all;
          };

          frontend = pkgs.mkShell {
            # Install site/node_modules
            inherit (frontend) shellHook;
            buildInputs = devPackages.frontend;
          };

          backend = pkgs.mkShell {
            buildInputs = devPackages.backend;
          };
        };
      }
    );
}
