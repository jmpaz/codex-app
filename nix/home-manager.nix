self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.codex-app;
  ozoneEnv =
    if cfg.ozonePlatform == "auto" then "auto" else cfg.ozonePlatform;
  ozoneFlags =
    if cfg.ozonePlatform == "auto" then [
      "--ozone-platform-hint=auto"
    ] else [
      "--ozone-platform=${cfg.ozonePlatform}"
    ];
  decorationFlags = lib.optionals (!cfg.enableWaylandDecorations) [
    "--disable-features=WaylandWindowDecorations"
  ];
  disableTitleBarOverlay = !cfg.enableWaylandDecorations || !cfg.enableTitleBarOverlay;
  launcherArgs = lib.escapeShellArgs (ozoneFlags ++ decorationFlags ++ cfg.extraArgs);
  wrapper = pkgs.writeShellScriptBin "codex-app" ''
    export ELECTRON_OZONE_PLATFORM_HINT=${lib.escapeShellArg ozoneEnv}
    ${lib.optionalString disableTitleBarOverlay ''
      export CODEX_DISABLE_LINUX_TITLEBAR_OVERLAY=1
    ''}
    exec ${lib.getExe cfg.package} ${launcherArgs} "$@"
  '';
  managedPackage = pkgs.symlinkJoin {
    name = "codex-app-managed";
    paths = [ cfg.package ];
    postBuild = ''
      rm -f $out/bin/codex-app
      ln -s ${wrapper}/bin/codex-app $out/bin/codex-app
      rm -f $out/share/applications/codex-app.desktop $out/share/applications/Codex.desktop
    '';
  };
in
{
  options.programs.codex-app = {
    enable = lib.mkEnableOption "Codex desktop app";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Package providing the Codex desktop app.";
    };

    ozonePlatform = lib.mkOption {
      type = lib.types.enum [ "x11" "wayland" "auto" ];
      default = "x11";
      description = "Electron Ozone platform used by the managed launcher.";
    };

    enableWaylandDecorations = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Electron's Wayland window decorations when launching on Wayland.";
    };

    enableTitleBarOverlay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the app's Linux client-side titlebar controls.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional command-line arguments passed to Codex.";
    };

    desktopEntry = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install a Home Manager desktop entry for the managed launcher.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "Codex";
        description = "Desktop entry file basename.";
      };

      desktopName = lib.mkOption {
        type = lib.types.str;
        default = "Codex";
        description = "Display name for the desktop entry.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ managedPackage ];

    xdg.desktopEntries.${cfg.desktopEntry.name} = lib.mkIf cfg.desktopEntry.enable {
      name = cfg.desktopEntry.desktopName;
      comment = "Codex desktop app";
      exec = "codex-app %u";
      icon = "codex-desktop";
      terminal = false;
      type = "Application";
      startupNotify = true;
      categories = [ "Development" ];
      mimeType = [ "x-scheme-handler/codex" ];
      settings = {
        StartupWMClass = "Codex";
      };
    };
  };
}
