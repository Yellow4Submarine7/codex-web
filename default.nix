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
    appVersion = "26.415.20818";
    cliVersion = "0.121.0";
    codexZip = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/Codex-darwin-arm64-${appVersion}.zip";
      hash = "sha256-NQgcjVeR9ACr2ZinsWSlR8GTsak6zuv1Qv+OyPIMtUg=";
    };
  in
  {
    devShells.default = pkgs.mkShell {
      HOSTED_CODEX_APP_ZIP = codexZip;

      packages = [
        pkgs.nodejs
        pkgs.yarn
        pkgs.unzip
        pkgs.patch
      ];
    };

    packages = {
      default =
        let
          nodeSources = pkgs.srcOnly pkgs.nodejs;
        in
        pkgs.stdenv.mkDerivation {
          HOSTED_CODEX_APP_ZIP = codexZip;

          pname = "codex-hosted";
          version = "1.0.0";
          src = ./.;

          yarnOfflineCache = pkgs.fetchYarnDeps {
            yarnLock = ./yarn.lock;
            hash = "sha256-29HFx48gV+fuk2hDWJr2b4ZnU76xH3L65fg0v/RVBd8=";
          };

          nativeBuildInputs = [
            pkgs.yarnConfigHook
            pkgs.yarnBuildHook
            pkgs.yarnInstallHook
            pkgs.nodejs
            pkgs.yarn
            pkgs.unzip
            pkgs.patch
            pkgs.python3
            pkgs.removeReferencesTo
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.cctools ];

          preInstall = ''
            # Keep only extracted asar artifacts for packaging.
            rm -rf scratch/Codex.app

            # yarn pack drops any directory named node_modules, so rename the
            # nested asar tree in-place to keep it in the package output.
            mv scratch/asar/node_modules scratch/asar/asar_node_modules
          '';

          postInstall = ''
            mv $out/lib/node_modules/codex-hosted/scratch/asar/{asar_,}node_modules

            pushd $out/lib/node_modules/codex-hosted/node_modules/better-sqlite3
            npm run build-release --offline --nodedir="${nodeSources}"
            rm -rf build/Release/{.deps,obj,obj.target,test_extension.node}
            find build -type f -exec ${pkgs.lib.getExe pkgs.removeReferencesTo} -t "${nodeSources}" {} \;
            popd
          '';
        };

      codex = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "codex-app-server";
        version = cliVersion;

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@openai/codex/-/codex-${finalAttrs.version}-linux-x64.tgz";
          hash = "sha256-suRePMCtRmK+csvAwNAdMDwbHbfvbIYlZt5rSoGk7yU";
        };

        nativeBuildInputs = [ pkgs.makeWrapper ];
        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          tar -xzf "$src"

          install -Dm755 package/vendor/x86_64-unknown-linux-musl/codex/codex "$out/libexec/codex/codex"
          install -Dm755 package/vendor/x86_64-unknown-linux-musl/path/rg "$out/libexec/codex/rg"

          makeWrapper "$out/libexec/codex/codex" "$out/bin/codex" \
            --prefix PATH : "$out/libexec/codex"

          runHook postInstall
        '';

        meta = {
          description = "Pinned Codex CLI binary used to run the app-server";
          homepage = "https://www.npmjs.com/package/@openai/codex";
          license = pkgs.lib.licenses.asl20;
          platforms = [ "x86_64-linux" ];
          mainProgram = "codex";
        };
      });

      codex_remote_proxy = pkgs.stdenvNoCC.mkDerivation {
        pname = "codex-remote-proxy";
        version = "1.0.0";
        src = ./scripts/codex_remote_proxy;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          runHook preInstall

          install -D "$src" "$out/bin/codex_remote_proxy"

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
    };
  }
)
