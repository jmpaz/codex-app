import childProcess from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const desktopRoot = path.resolve(__dirname, '..');
const iconRoot = path.join(desktopRoot, 'assets', 'icons');
const sourceIcon = path.join(iconRoot, 'codex-logo-source.png');
const iconSizes = [32, 64, 128, 256, 512];

function parseArgs(argv) {
  return {
    check: argv.includes('--check'),
  };
}

function sha256(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function runMagick(args) {
  childProcess.execFileSync('magick', args, {
    stdio: 'pipe',
  });
}

function renderIcon(size, outputPath) {
  runMagick([
    sourceIcon,
    '-resize',
    `${size}x${size}`,
    outputPath,
  ]);
}

function assertGeneratedIconsMatch() {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-icons-'));

  try {
    for (const size of iconSizes) {
      const expectedPath = path.join(iconRoot, `codex-logo-${size}.png`);
      const generatedPath = path.join(tempDir, `codex-logo-${size}.png`);
      renderIcon(size, generatedPath);

      if (sha256(expectedPath) !== sha256(generatedPath)) {
        throw new Error(
          `Generated ${size}x${size} icon does not match ${expectedPath}. ` +
            'Run "npm run generate:linux-icons" to refresh committed icons.',
        );
      }
    }
  } finally {
    fs.rmSync(tempDir, { force: true, recursive: true });
  }
}

function generateIcons() {
  for (const size of iconSizes) {
    renderIcon(size, path.join(iconRoot, `codex-logo-${size}.png`));
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.check) {
    assertGeneratedIconsMatch();
    return;
  }

  generateIcons();
}

main();
