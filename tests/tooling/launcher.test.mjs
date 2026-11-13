import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmod, copyFile, mkdir, mkdtemp, realpath, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { readCommonBundleMetadata, verifyCommonBundleMetadata } from '../../scripts/bundle-metadata.mjs';

const root = fileURLToPath(new URL('../..', import.meta.url));

test('the bundled entry preserves physical cwd and literal arguments through relative symlinks', async t => {
  const base = await mkdtemp(join(tmpdir(), 'panepeek-launcher-'));
  t.after(() => rm(base, { recursive: true, force: true }));
  const directory = await realpath(base);
  const app = join(directory, 'Application ü\n.app', 'Contents');
  const resources = join(app, 'Resources');
  await mkdir(resources, { recursive: true });
  await mkdir(join(app, 'MacOS'));
  const entry = join(resources, 'panepeek');
  await copyFile(join(root, 'assets', 'panepeek'), entry);
  await chmod(entry, 0o755);
  const executable = join(app, 'MacOS', 'PanePeek');
  await writeFile(executable, '#!' + process.execPath + '\nprocess.stdout.write(JSON.stringify({ cwd: process.cwd(), args: process.argv.slice(2) }));\n', { mode: 0o755 });
  const cwd = join(directory, 'physical ü\n');
  await mkdir(cwd);
  const alias = join(directory, 'cwd-link');
  await symlink(cwd, alias);
  const bin = join(directory, 'bin');
  await mkdir(bin);
  await symlink('../Application ü\n.app/Contents/Resources/panepeek', join(bin, 'first'));
  const launcher = join(bin, 'panepeek');
  await symlink('first', launcher);
  const literalArguments = ['--reveal', '--', '-space ü %?#&=+ $(literal)'];
  for (const command of [launcher, 'panepeek']) {
    const result = spawnSync(command, literalArguments, {
      cwd: alias, env: { ...process.env, PWD: '/misleading', PATH: bin + ':/usr/bin:/bin' }, encoding: 'utf8', timeout: 5_000,
    });
    assert.equal(result.status, 0, result.stderr || result.error?.message || 'launcher did not reach the containing executable');
    assert.deepEqual(JSON.parse(result.stdout), { cwd, args: ['--panepeek-cli', cwd, ...literalArguments] });
  }
});

test('a copied entry outside its app reports failure without running another command', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'panepeek-copied-launcher-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const entry = join(directory, 'panepeek');
  await copyFile(join(root, 'assets', 'panepeek'), entry);
  await chmod(entry, 0o755);
  const result = spawnSync(entry, ['--help'], { encoding: 'utf8', timeout: 5_000 });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /containing PanePeek app/i);
  assert.equal(result.stdout, '');
});

test('native and scripted bundles share exactly the local launcher URL declaration', { skip: process.platform !== 'darwin' }, () => {
  const common = readCommonBundleMetadata();
  const expected = [{
    CFBundleURLName: 'com.bcinarli.PanePeek.launcher',
    CFBundleTypeRole: 'Viewer',
    CFBundleURLSchemes: ['panepeek'],
  }];
  assert.deepEqual(common.CFBundleURLTypes, expected);
  assert.throws(() => verifyCommonBundleMetadata({ ...common, CFBundleURLTypes: [{
    ...expected[0], CFBundleURLSchemes: ['other-scheme'],
  }] }), /CFBundleURLTypes/);
});
