import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, test } from 'node:test';

const root = fileURLToPath(new URL('../..', import.meta.url));
const temporary = [];
afterEach(() => {
  for (const directory of temporary.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function run(args = [], failingPhase = '') {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-test-runner-'));
  temporary.push(directory);
  mkdirSync(join(directory, 'scripts'));
  mkdirSync(join(directory, 'bin'));
  copyFileSync(join(root, 'scripts/test.mjs'), join(directory, 'scripts/test.mjs'));
  const log = join(directory, 'calls.jsonl');
  writeFileSync(join(directory, 'bin/xcrun'), `#!${process.execPath}\nconsole.log('/missing/swiftc');\n`, { mode: 0o755 });
  writeFileSync(join(directory, 'bin/swift'), `#!${process.execPath}
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.TEST_RUN_LOG, JSON.stringify(args) + '\\n');
const phase = args.includes('--filter') ? 'highlighting' : 'behaviour';
process.exit(phase === process.env.TEST_FAIL_PHASE ? 7 : 0);
`, { mode: 0o755 });
  const result = spawnSync(process.execPath, [join(directory, 'scripts/test.mjs'), ...args], {
    encoding: 'utf8', timeout: 10_000,
    env: { ...process.env, PATH: `${join(directory, 'bin')}:${process.env.PATH}`, TEST_RUN_LOG: log, TEST_FAIL_PHASE: failingPhase },
  });
  return { result, calls: readFileSync(log, 'utf8').trim().split('\n').map(JSON.parse) };
}

test('full validation separates complementary workloads and reuses the selected build', () => {
  const { result, calls } = run(['--configuration', 'release']);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(calls, [
    ['test', '--configuration', 'release', '--filter', '.*HighlightingTests'],
    ['test', '--configuration', 'release', '--skip-build', '--skip', '.*HighlightingTests'],
  ]);
});

test('a failure in either workload fails the command without an automatic retry', () => {
  for (const phase of ['highlighting', 'behaviour']) {
    const { result, calls } = run([], phase);
    assert.equal(result.status, 7, result.stderr);
    assert.equal(calls.length, phase === 'highlighting' ? 1 : 2);
  }
});

test('explicit selections and queries are forwarded once without widening their scope', () => {
  for (const args of [['--filter', 'DirectoryBrowsingTests'], ['--filter=PathCopyTests'], ['--skip', 'EditorTests'], ['--skip=EditorTests'], ['list'], ['--help']]) {
    const { result, calls } = run(args);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(calls, [['test', ...args]]);
  }
});
