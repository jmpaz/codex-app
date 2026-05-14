import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from '@jest/globals';

const repoRoot = path.resolve(__dirname, '..', '..', '..');

function readRepoFile(relativePath: string): string {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

describe('Nix flake contract', () => {
  test('flake exposes only the supported Linux package interfaces', () => {
    const flake = readRepoFile('flake.nix');

    expect(flake).toContain('"x86_64-linux"');
    expect(flake).toContain('"aarch64-linux"');
    expect(flake).not.toContain('darwin');
    expect(flake).toContain('packages = {');
    expect(flake).toContain('default = codexApp;');
    expect(flake).toContain('codex-app = codexApp;');
    expect(flake).toContain('apps.default = {');
    expect(flake).toContain('checks.default = pkgs.callPackage ./nix/check.nix');
    expect(flake).toContain('devShells.default = pkgs.callPackage ./nix/dev-shell.nix');
    expect(flake).toContain('homeManagerModules.default = import ./nix/home-manager.nix self');
  });

  test('package builds through the desktop pipeline with host helper selection', () => {
    const packageNix = readRepoFile('nix/package.nix');

    expect(packageNix).toContain('buildNpmPackage');
    expect(packageNix).toContain('sourceRoot = "codex-app-source/desktop";');
    expect(packageNix).toContain('x86_64-linux = "linux-x64";');
    expect(packageNix).toContain('aarch64-linux = "linux-arm64";');
    expect(packageNix).toContain('CODEX_LINUX_HELPER_ARCH = helperDir;');
    expect(packageNix).toContain('ELECTRON_SKIP_BINARY_DOWNLOAD = "1";');
    expect(packageNix).toContain('node ./scripts/generate-linux-icons.mjs --check');
    expect(packageNix).toContain('./node_modules/.bin/electron-rebuild');
    expect(packageNix).toContain('node ./scripts/assemble-codex-runtime.mjs');
    expect(packageNix).toContain('--set-default ELECTRON_OZONE_PLATFORM_HINT x11');
    expect(packageNix).toContain('--set-default CHROME_DESKTOP Codex.desktop');
    expect(packageNix).toContain('--set-default ELECTRON_DESKTOP_FILE_NAME Codex.desktop');
    expect(packageNix).toContain('--set-default CODEX_ELECTRON_RESOURCES_PATH');
    expect(packageNix).toContain('--class=Codex');
    expect(packageNix).toContain('name = "Codex";');
    expect(packageNix).toContain('startupWMClass = "Codex";');
    expect(packageNix).toContain('exec ${lib.getExe codex} "$@"');
    expect(packageNix).toContain('exec ${lib.getExe ripgrep} "$@"');
    expect(packageNix).toContain('exec ${lib.getExe git} "$@"');
  });

  test('runtime assembly keeps Linux on the production desktop flavor', () => {
    const assembleRuntime = readRepoFile('desktop/scripts/assemble-codex-runtime.mjs');

    expect(assembleRuntime).toContain('bootstrap linux prod flavor');
    expect(assembleRuntime).toContain(
      'x=process.platform===`linux`?`prod`:t.C.resolve()',
    );
  });

  test('Home Manager module keeps launch policy separate from the package', () => {
    const homeManager = readRepoFile('nix/home-manager.nix');

    expect(homeManager).toContain('options.programs.codex-app');
    expect(homeManager).toContain('ozonePlatform');
    expect(homeManager).toContain('type = lib.types.enum [ "x11" "wayland" "auto" ]');
    expect(homeManager).toContain('enableWaylandDecorations');
    expect(homeManager).toContain('enableTitleBarOverlay');
    expect(homeManager).toContain('extraArgs');
    expect(homeManager).toContain('desktopEntry');
    expect(homeManager).toContain('CODEX_DISABLE_LINUX_TITLEBAR_OVERLAY=1');
    expect(homeManager).toContain('--disable-features=WaylandWindowDecorations');
    expect(homeManager).toContain('exec ${lib.getExe cfg.package}');
    expect(homeManager).toContain('rm -f $out/share/applications/codex-app.desktop $out/share/applications/Codex.desktop');
    expect(homeManager).toContain('default = "Codex";');
    expect(homeManager).toContain('StartupWMClass = "Codex";');
    expect(homeManager).toContain('xdg.desktopEntries.${cfg.desktopEntry.name}');
  });

  test('package check covers runtime modules, helpers, icons, and desktop metadata', () => {
    const checkNix = readRepoFile('nix/check.nix');

    expect(checkNix).toContain('requireFromApp("tslib")');
    expect(checkNix).toContain('CHROME_DESKTOP');
    expect(checkNix).toContain('ELECTRON_DESKTOP_FILE_NAME');
    expect(checkNix).toContain('new Database(":memory:")');
    expect(checkNix).toContain('requireFromApp("node-pty")');
    expect(checkNix).toContain('resources/bin/codex');
    expect(checkNix).toContain('resources/bin/git');
    expect(checkNix).toContain('resources/bin/rg');
    expect(checkNix).toContain('share/icons/hicolor/');
    expect(checkNix).toContain('desktopName !== "Codex.desktop"');
    expect(checkNix).toContain('--class=Codex');
    expect(checkNix).toContain('share/applications/Codex.desktop');
    expect(checkNix).toContain('Exec=codex-app %u');
    expect(checkNix).toContain('Icon=codex-desktop');
    expect(checkNix).toContain('StartupWMClass=Codex');
    expect(checkNix).toContain('MimeType=x-scheme-handler/codex');
  });
});
