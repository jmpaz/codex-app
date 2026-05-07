{ lib
, runCommand
, codexApp
, electron_41
, gnugrep
}:

runCommand "codex-app-package-check" {
  nativeBuildInputs = [ gnugrep ];
} ''
  test -x ${codexApp}/bin/codex-app
  grep -q 'CODEX_ELECTRON_RESOURCES_PATH' ${codexApp}/bin/codex-app
  grep -q 'CHROME_DESKTOP' ${codexApp}/bin/codex-app
  grep -q 'ELECTRON_DESKTOP_FILE_NAME' ${codexApp}/bin/codex-app
  grep -q -- '--class=Codex' ${codexApp}/bin/codex-app
  test -f ${codexApp}/share/codex-app/resources/app.asar
  test -x ${codexApp}/share/codex-app/resources/bin/codex
  test -x ${codexApp}/share/codex-app/resources/bin/git
  test -x ${codexApp}/share/codex-app/resources/bin/rg
  grep -a 'tslib.js' ${codexApp}/share/codex-app/resources/app.asar >/dev/null
  grep -a 'bindings.js' ${codexApp}/share/codex-app/resources/app.asar >/dev/null
  grep -a 'file-uri-to-path' ${codexApp}/share/codex-app/resources/app.asar >/dev/null
  grep -a 'better-sqlite3' ${codexApp}/share/codex-app/resources/app.asar >/dev/null
  grep -a 'node-pty' ${codexApp}/share/codex-app/resources/app.asar >/dev/null
  test -f ${codexApp}/share/codex-app/resources/app.asar.unpacked/node_modules/better-sqlite3/build/Release/better_sqlite3.node
  test -f ${codexApp}/share/codex-app/resources/app.asar.unpacked/node_modules/node-pty/build/Release/pty.node
  ELECTRON_RUN_AS_NODE=1 ${lib.getExe electron_41} -e '
    const { createRequire } = require("node:module");
    const requireFromApp = createRequire("${codexApp}/share/codex-app/resources/app.asar/package.json");
    const packageMetadata = requireFromApp("./package.json");
    if (packageMetadata.desktopName !== "Codex.desktop") {
      throw new Error("unexpected desktopName: " + packageMetadata.desktopName);
    }
    requireFromApp("tslib");
    const Database = requireFromApp("better-sqlite3");
    const db = new Database(":memory:");
    if (db.prepare("select 1 as value").get().value !== 1) {
      throw new Error("better-sqlite3 smoke query failed");
    }
    db.close();
    requireFromApp("node-pty");
  '
  test -x ${codexApp}/share/codex-app/resources/codex
  test -x ${codexApp}/share/codex-app/resources/git
  test -x ${codexApp}/share/codex-app/resources/rg

  for size in 32 64 128 256 512; do
    test -f ${codexApp}/share/icons/hicolor/''${size}x''${size}/apps/codex-desktop.png
  done

  test -f ${codexApp}/share/applications/Codex.desktop
  grep -q '^Exec=codex-app %u$' ${codexApp}/share/applications/Codex.desktop
  grep -q '^Icon=codex-desktop$' ${codexApp}/share/applications/Codex.desktop
  grep -q '^StartupWMClass=Codex$' ${codexApp}/share/applications/Codex.desktop
  grep -Eq '^MimeType=x-scheme-handler/codex;?$' ${codexApp}/share/applications/Codex.desktop
  touch $out
''
