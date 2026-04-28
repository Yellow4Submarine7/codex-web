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
    src = pkgs.fetchFromGitHub {
      owner = "openai";
      repo = "codex";
      rev = "rust-v${version}";
      hash = "sha256-vVkwAD2vbRykfIlfxc4CyzIf/8UF94V5fKhJbAE9mog=";
    };
    codexCrateOverrides = pkgs.defaultCrateOverrides // {
      aws-lc-sys = attrs: {
        nativeBuildInputs = (attrs.nativeBuildInputs or [ ]) ++ [
          pkgs.cmake
          pkgs.perl
        ];
      };
      codex-linux-sandbox = attrs: {
        CODEX_BWRAP_SOURCE_DIR = "${src}/codex-rs/vendor/bubblewrap";
        nativeBuildInputs = (attrs.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
        buildInputs = (attrs.buildInputs or [ ]) ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.libcap ];
      };
      codex-core = attrs: {
        preBuild = (attrs.preBuild or "") + ''
          cp ${src}/codex-rs/node-version.txt "$NIX_BUILD_TOP/node-version.txt"
        '';
      };
      codex-models-manager = attrs: {
        patches = (attrs.patches or [ ]) ++ [
          ./patches/codex-models-manager/model-list-cache-before-auth.patch
        ];
      };
      rmcp = _: {
        CARGO_CRATE_NAME = "rmcp";
      };
      v8 = attrs: {
        RUSTY_V8_ARCHIVE =
          let
            version = "146.4.0";
            info = {
              aarch64-darwin = {
                file = "librusty_v8_release_aarch64-apple-darwin.a.gz";
                hash = "sha256-v+LJvjKlbChUbw+WWCXuaPv2BkBfMQzE4XtEilaM+Yo=";
              };
              x86_64-darwin = {
                file = "librusty_v8_release_x86_64-apple-darwin.a.gz";
                hash = "sha256-YwzSQPG77NsHFBfcGDh6uBz2fFScHFFaC0/Pnrpke7c=";
              };
              aarch64-linux = {
                file = "librusty_v8_release_aarch64-unknown-linux-gnu.a.gz";
                hash = "sha256-2/FlsHyBvbBUvARrQ9I+afz3vMGkwbW0d2mDpxBi7Ng=";
              };
              x86_64-linux = {
                file = "librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
                hash = "sha256-5ktNmeSuKTouhGJEqJuAF4uhA4LBP7WRwfppaPUpEVM=";
              };
            };
          in
          pkgs.fetchurl {
            url = "https://github.com/denoland/rusty_v8/releases/download/v${version}/${info.${system}.file}";
            hash = info.${system}.hash;
          };
        nativeBuildInputs = (attrs.nativeBuildInputs or [ ]) ++ [
          pkgs.python3
          pkgs.pkg-config
        ];
      };
      "webrtc-sys" = attrs: {
        LK_CUSTOM_WEBRTC =
          let
            info = {
              aarch64-darwin = {
                triple = "mac-arm64-release";
                hash = "sha256-eb5cwV5uBjPEOA4z4XLX6/Gm3Og+ngmXYdYQPw1+tsE=";
              };
              x86_64-darwin = {
                triple = "mac-x64-release";
                hash = "sha256-COQh7Wa0KEmM1qUTMMldmP7WncRKPBNJ7RaiRowUyV8=";
              };
              aarch64-linux = {
                triple = "linux-arm64-release";
                hash = "sha256-QBPVPoY+RwQt1Ztnsb2EltoER6yEw9cMFwSZQG8Tqgs=";
              };
              x86_64-linux = {
                triple = "linux-x64-release";
                hash = "sha256-89SaZMN+qJmvUt3GhfUx8Kvi+3VSiqTa4lKtqqA77Mw=";
              };
            };
            selected = info.${system};
            zip = pkgs.fetchurl {
              url = "https://github.com/livekit/rust-sdks/releases/download/webrtc-24f6822-2/webrtc-${selected.triple}.zip";
              hash = selected.hash;
            };
            unpacked = pkgs.runCommand "webrtc-${selected.triple}" { nativeBuildInputs = [ pkgs.unzip ]; } ''
              mkdir -p "$out"
              unzip -q -o ${zip} -d "$out"
            '';
          in
          "${unpacked}/${selected.triple}";
        postInstall = (attrs.postInstall or "") + ''
          rm -rf "$lib/lib/webrtc-sys.out/cxxbridge"
        '';
      };
    };
    codexCrates = import ./Cargo.nix {
      inherit pkgs;
      workspaceSrc = "${src}/codex-rs";
      buildRustCrateForPkgs =
        pkgs:
        pkgs.buildRustCrate.override {
          defaultCodegenUnits = 16;
          defaultCrateOverrides = codexCrateOverrides;
        };
    };
  in
  {
    packages.codex = codexCrates.workspaceMembers."codex-cli".build.overrideAttrs (old: {
      pname = "codex";

      LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
      PKG_CONFIG_PATH = pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" (
        [ pkgs.openssl ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.libcap ]
      );

      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        pkgs.cmake
        pkgs.llvmPackages.clang
        pkgs.llvmPackages.libclang.lib
        pkgs.pkg-config
      ];
      buildInputs =
        (old.buildInputs or [ ])
        ++ [ pkgs.openssl ]
        ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.libcap ];
    });
  }
)
