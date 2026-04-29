{
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
    version = "0.125.0-alpha.3";
    platform =
      {
        aarch64-darwin = {
          npm = "darwin-arm64";
          hash = "sha256-H6kCDiNAUgiEzCZvfVqVs4ECgZWu3AnXXEtjyzSZ43w=";
        };
        x86_64-darwin = {
          npm = "darwin-x64";
          hash = "sha256-qmCnP+v7KSci3w7aa94Q4KsJiVizMUy0ujBxx6Sg2Qo=";
        };
        aarch64-linux = {
          npm = "linux-arm64";
          hash = "sha256-XPbu4RsGZZ+mDXGSFfL1sFbv7HfvvBWpzzrV9fBElK0=";
        };
        x86_64-linux = {
          npm = "linux-x64";
          hash = "sha256-jUl2Q9DkTK9ZyDHzD/mlYjTxpfBdlb+Tc3/qdPbEynI=";
        };
      }
      .${system};
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-${platform.npm}.tgz";
      hash = platform.hash;
    };
  in
  {
    packages.codex =
      pkgs.runCommand "codex-app-server-${version}"
        {
          pname = "codex-app-server";
          inherit src version;
          meta.mainProgram = "codex";
        }
        ''
          tar -xzf "$src"
          install -Dm755 package/vendor/*/codex/codex "$out/bin/codex"
        '';
  }
)
