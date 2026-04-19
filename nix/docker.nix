{
  self,
  flake-utils,
  nixpkgs,
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
  in
  {
    packages = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "codex-hosted";
        tag = "latest";
        contents = [
          self.packages.${system}.default
          self.packages.${system}.codex
          pkgs.cacert
          pkgs.coreutils
        ];
        config = {
          Cmd = [
            "${pkgs.coreutils}/bin/env"
            "CODEX_CLI_PATH=${self.packages.${system}.codex}/bin/codex"
            "${self.packages.${system}.default}/bin/codex-hosted-server"
            "--host"
            "0.0.0.0"
            "--port"
            "8214"
          ];
          ExposedPorts = {
            "8214/tcp" = { };
          };
          Env = [
            "NODE_ENV=production"
            "HOME=/tmp"
            "PATH=${pkgs.lib.makeBinPath [ self.packages.${system}.codex ]}"
            "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          ];
        };
      };
    };
  }
)
