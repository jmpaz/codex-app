{
  description = "Linux Nix packaging for the Codex desktop app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        codexApp = pkgs.callPackage ./nix/package.nix { };
      in
      {
        packages = {
          default = codexApp;
          codex-app = codexApp;
        };

        apps.default = {
          type = "app";
          program = "${codexApp}/bin/codex-app";
        };

        checks.default = pkgs.callPackage ./nix/check.nix {
          inherit codexApp;
        };

        devShells.default = pkgs.callPackage ./nix/dev-shell.nix { };
      }) // {
        homeManagerModules.default = import ./nix/home-manager.nix self;
      };
}
