import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtemp, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = fileURLToPath(new URL('../..', import.meta.url));

test('native asset compilation produces the named macOS Store icon and bundle metadata', {
  skip: process.platform !== 'darwin',
}, async () => {
  const output = await mkdtemp(join(tmpdir(), 'panepeek-store-icon-'));
  const env = { ...process.env };
  if (!env.DEVELOPER_DIR && execFileSync('xcode-select', ['--print-path'], { encoding: 'utf8' }).trim() === '/Library/Developer/CommandLineTools') {
    env.DEVELOPER_DIR = '/Applications/Xcode.app/Contents/Developer';
  }
  try {
    const infoPath = join(output, 'icon.plist');
    execFileSync('xcrun', ['actool', join(root, 'assets', 'app-icon.xcassets'),
      '--compile', output, '--platform', 'macosx', '--minimum-deployment-target', '26.0',
      '--app-icon', 'AppIcon', '--output-partial-info-plist', infoPath,
    ], { env, stdio: 'pipe', timeout: 60_000 });
    const info = JSON.parse(execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', infoPath], { encoding: 'utf8' }));
    assert.equal(info.CFBundleIconName, 'AppIcon');
    assert.equal(info.CFBundleIconFile, 'AppIcon');
    assert.ok((await stat(join(output, 'AppIcon.icns'))).size > 0);
    const assets = JSON.parse(execFileSync('/usr/bin/assetutil', ['--info', join(output, 'Assets.car')], { encoding: 'utf8' }));
    assert.ok(assets.some(asset => asset.Name === 'AppIcon' && asset.PixelWidth === 1024 && asset.PixelHeight === 1024),
      'the compiled catalogue must contain the full-resolution Store icon');
  } finally {
    await rm(output, { recursive: true, force: true });
  }
});
