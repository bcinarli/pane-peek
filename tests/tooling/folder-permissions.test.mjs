import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { chmod, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { inspectArchive } from '../../scripts/app-store.mjs';
import { readCommonBundleMetadata } from '../../scripts/bundle-metadata.mjs';

const root = fileURLToPath(new URL('../..', import.meta.url));
const descriptions = {
  NSDesktopFolderUsageDescription: 'PanePeek accesses your Desktop folder to preview and organise files, such as moving a screenshot into another folder.',
  NSDocumentsFolderUsageDescription: 'PanePeek accesses your Documents folder to preview and edit documents, such as opening a text file and saving your changes.',
  NSDownloadsFolderUsageDescription: 'PanePeek accesses your Downloads folder to preview and organise downloaded files, such as moving a downloaded PDF into Documents.',
};

test('Store metadata explains each protected folder with a concrete file-use example', { skip: process.platform !== 'darwin' }, () => {
  const info = JSON.parse(execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', join(root, 'xcode', 'Info.plist')], { encoding: 'utf8' }));
  for (const [key, description] of Object.entries(descriptions)) {
    assert.equal(info[key], description, key);
  }
});

test('archive inspection rejects missing, invalid and drifted common metadata', { skip: process.platform !== 'darwin' }, async t => {
  const archive = await mkdtemp(join(tmpdir(), 'panepeek-folder-permissions-'));
  t.after(() => rm(archive, { recursive: true, force: true }));
  const contents = join(archive, 'Products', 'Applications', 'PanePeek.app', 'Contents');
  await mkdir(join(contents, 'MacOS'), { recursive: true });
  await mkdir(join(contents, 'Resources'));
  execFileSync('xcrun', ['clang', '-arch', 'arm64', '-x', 'c', '-o', join(contents, 'MacOS', 'PanePeek'), '-'], {
    input: 'int main(void) { return 0; }\n', stdio: ['pipe', 'pipe', 'pipe'],
  });
  for (const name of ['Assets.car', 'AppIcon.icns', 'LICENSE', 'NOTICE', 'PRIVACY.md', 'lucide-LICENSE.txt', 'Privacy.txt', 'Acknowledgements.txt', 'panepeek']) {
    await writeFile(join(contents, 'Resources', name), 'fixture');
  }
  const launcher = join(contents, 'Resources', 'panepeek');
  await chmod(launcher, 0o755);
  const identity = { CFBundleIdentifier: 'com.bcinarli.PanePeek', CFBundleVersion: '11', CFBundleShortVersionString: '1.1.0' };
  await writeFile(join(archive, 'Info.plist'), JSON.stringify({ ApplicationProperties: {
    ...identity, ApplicationPath: 'Applications/PanePeek.app',
  } }));
  const common = readCommonBundleMetadata();
  const info = { ...common, ...identity, CFBundleExecutable: 'PanePeek',
    PanePeekSandboxed: true, CFBundleIconName: 'AppIcon', CFBundleIconFile: 'AppIcon' };
  await writeFile(join(contents, 'Info.plist'), JSON.stringify(info));
  assert.deepEqual((await inspectArchive(archive)).info, info);
  await chmod(launcher, 0o644);
  await assert.rejects(inspectArchive(archive), /launcher is not executable/);
  await chmod(launcher, 0o755);
  for (const [key, value] of Object.entries(common)) {
    const invalidValues = typeof value === 'boolean' ? [undefined, !value, String(value)] : [undefined, '', ' \n ', true, `${value} Changed wording.`];
    for (const invalid of invalidValues) {
      await writeFile(join(contents, 'Info.plist'), JSON.stringify({ ...info, [key]: invalid }));
      await assert.rejects(inspectArchive(archive), new RegExp(key));
    }
  }
});
