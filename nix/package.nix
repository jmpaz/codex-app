{ lib
, stdenv
, buildNpmPackage
, electron_41
, nodejs_22
, python3
, pkg-config
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, imagemagick
, bash
, coreutils
, git
, gnugrep
, ripgrep
, xdg-utils
, codex
, source ? lib.cleanSourceWith {
    name = "codex-app-source";
    src = ../.;
  }
}:

let
  packageJson = builtins.fromJSON (builtins.readFile ../desktop/package.json);
  electron = electron_41;
  helperDirs = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
  };
  helperDir = helperDirs.${stdenv.hostPlatform.system}
    or (throw "Unsupported Codex app system: ${stdenv.hostPlatform.system}");
  runtimePath = "$out/share/codex-app/resources";
in
buildNpmPackage {
  pname = "codex-app";
  inherit (packageJson) version;

  src = source;
  sourceRoot = "codex-app-source/desktop";

  npmDepsHash = "sha256-fOQHVE+H9hHT3eDtloZ2iJVRvDMnXIXvhSoOm0qFthQ=";
  makeCacheWritable = true;

  env = {
    CODEX_LINUX_HELPER_ARCH = helperDir;
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    npm_config_build_from_source = "true";
    npm_config_nodedir = electron.headers;
  };

  nativeBuildInputs = [
    copyDesktopItems
    imagemagick
    makeWrapper
    nodejs_22
    pkg-config
    python3
  ];

  buildInputs = [
    stdenv.cc.cc
  ];

  buildPhase = ''
    runHook preBuild

    rm -rf resources/bin/${helperDir}
    mkdir -p resources/bin/${helperDir}
    cat > resources/bin/${helperDir}/codex <<'EOF'
    #!${lib.getExe bash}
    exec ${lib.getExe codex} "$@"
    EOF
    cat > resources/bin/${helperDir}/rg <<'EOF'
    #!${lib.getExe bash}
    exec ${lib.getExe ripgrep} "$@"
    EOF
    cat > resources/bin/${helperDir}/git <<'EOF'
    #!${lib.getExe bash}
    exec ${lib.getExe git} "$@"
    EOF
    chmod 755 resources/bin/${helperDir}/codex resources/bin/${helperDir}/git resources/bin/${helperDir}/rg

    export npm_config_build_from_source=true
    export npm_config_nodedir=${electron.headers}
    export npm_config_runtime=electron
    export npm_config_target=${electron.version}
    node ./scripts/generate-linux-icons.mjs --check
    ./node_modules/.bin/electron-rebuild \
      --force \
      --build-from-source \
      --only better-sqlite3,node-pty \
      --version ${electron.version}
    node ./scripts/assemble-codex-runtime.mjs --output "$PWD/nix-runtime"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/codex-app
    cp -R nix-runtime/resources $out/share/codex-app/

    for size in 32 64 128 256 512; do
      install -d "$out/share/icons/hicolor/''${size}x''${size}/apps"
      magick assets/icons/codex-logo-source.png \
        -resize "''${size}x''${size}" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/codex-desktop.png"
    done

    makeWrapper ${lib.getExe electron} $out/bin/codex-app \
      --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
      --set-default ELECTRON_IS_DEV 0 \
      --set-default ELECTRON_OZONE_PLATFORM_HINT x11 \
      --set-default CHROME_DESKTOP Codex.desktop \
      --set-default ELECTRON_DESKTOP_FILE_NAME Codex.desktop \
      --set-default CODEX_ELECTRON_RESOURCES_PATH ${runtimePath} \
      --add-flags "--class=Codex" \
      --add-flags ${runtimePath}/app.asar \
      --prefix PATH : ${lib.makeBinPath [ bash coreutils git gnugrep ripgrep xdg-utils ]}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "Codex";
      desktopName = "Codex";
      comment = "Codex desktop app";
      exec = "codex-app %u";
      icon = "codex-desktop";
      terminal = false;
      type = "Application";
      startupNotify = true;
      startupWMClass = "Codex";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/codex" ];
    })
  ];

  meta = {
    description = "Linux desktop build for the Codex app";
    homepage = "https://github.com/jmpaz/codex-app";
    license = lib.licenses.unfree;
    mainProgram = "codex-app";
    platforms = builtins.attrNames helperDirs;
    sourceProvenance = with lib.sourceTypes; [ fromSource binaryNativeCode ];
  };
}
