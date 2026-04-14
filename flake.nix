{
  description = "codex-hosted dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    flake-utils.lib.eachSystem systems (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmtEval = treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        };
        codexZip = pkgs.fetchurl {
          url = "https://persistent.oaistatic.com/codex-app-prod/Codex-darwin-arm64-26.409.20454.zip";
          hash = "sha256-J1xOgVwwXWIcU80Nwqg3xhQxQLHuuDPjpTGlhU2SybQ=";
        };
      in
      {
        formatter = treefmtEval.config.build.wrapper;

        checks = {
          formatting = treefmtEval.config.build.check self;
        };

        devShells.default = pkgs.mkShell {
          HOSTED_CODEX_APP_ZIP = codexZip;

          packages = [
            pkgs.nodejs
            pkgs.yarn
            pkgs.unzip
            pkgs.patch
          ];
        };

        packages.default = pkgs.stdenv.mkDerivation {
          HOSTED_CODEX_APP_ZIP = codexZip;

          pname = "codex-hosted";
          version = "1.0.0";
          src = ./.;

          yarnOfflineCache = pkgs.fetchYarnDeps {
            yarnLock = ./yarn.lock;
            hash = "sha256-uvt9oiCu33rY3UuKEghOw5RvuJLpHy4Xqkp1Eexe2J0=";
          };

          nativeBuildInputs = [
            pkgs.yarnConfigHook
            pkgs.yarnBuildHook
            pkgs.yarnInstallHook
            pkgs.nodejs
            pkgs.yarn
            pkgs.unzip
            pkgs.patch
          ];
        };

        packages.codex_remote_proxy = pkgs.stdenvNoCC.mkDerivation {
          pname = "codex-remote-proxy";
          version = "1.0.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          installPhase = ''
            runHook preInstall

            mkdir -p "$out/bin"
            cp scripts/codex_remote_proxy "$out/bin/codex_remote_proxy"
            chmod +x "$out/bin/codex_remote_proxy"

            wrapProgram "$out/bin/codex_remote_proxy" \
              --prefix PATH : ${
                pkgs.lib.makeBinPath [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.websocat
                ]
              }

            runHook postInstall
          '';
        };
      }
    );
}
