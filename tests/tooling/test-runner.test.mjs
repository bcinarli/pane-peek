import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, test } from 'node:test';

const root = fileURLToPath(new URL('../..', import.meta.url));
const temporary = [];
const discovered = [
  'PanePeekCoreTests.CSVHighlightingTests/largeInput()',
  'PanePeekCoreTests.EditorTests/retainsDraft()',
  'PanePeekTests.PathCopyTests/copiesPath()',
  'PanePeekTests.NativeHighlightingTests/usesNativeState()',
];
afterEach(() => {
  for (const directory of temporary.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function run(args = [], failingPhase = '', listing = discovered) {
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
const filter = args[args.indexOf('--filter') + 1] || '';
const phase = args.includes('list') ? 'discovery' : filter.includes('PanePeekTests') ? 'native' : filter.includes('HighlightingTests') ? 'highlighting' : 'core';
if (phase === 'discovery') console.log(process.env.TEST_DISCOVERY);
else { console.log(phase + ' output'); console.error(phase + ' diagnostics'); }
process.exit(phase === process.env.TEST_FAIL_PHASE ? 7 : 0);
`, { mode: 0o755 });
  const result = spawnSync(process.execPath, [join(directory, 'scripts/test.mjs'), ...args], {
    encoding: 'utf8', timeout: 30_000,
    env: { ...process.env, PATH: `${join(directory, 'bin')}:${process.env.PATH}`, TEST_RUN_LOG: log, TEST_FAIL_PHASE: failingPhase, TEST_DISCOVERY: listing.join('\n') },
  });
  const calls = existsSync(log) ? readFileSync(log, 'utf8').trim().split('\n').map(JSON.parse) : [];
  return { result, calls, directory };
}

test('full validation discovers complete disjoint workloads and serialises native tests globally', () => {
  const { result, calls } = run(['--configuration', 'release']);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(calls.length, 4);
  assert.deepEqual(calls[0], ['test', '--configuration', 'release', 'list']);
  const memberships = discovered.map(() => 0);
  for (const args of calls.slice(1)) {
    assert.ok(args.includes('--skip-build'));
    assert.deepEqual(args.slice(0, 3), ['test', '--configuration', 'release']);
    const filter = new RegExp(args[args.indexOf('--filter') + 1]);
    const skip = args.includes('--skip') ? new RegExp(args[args.indexOf('--skip') + 1]) : null;
    discovered.forEach((id, i) => {
      if (filter.test(id) && !skip?.test(id)) {
        memberships[i] += 1;
        assert.equal(args.includes('--no-parallel'), id.startsWith('PanePeekTests.'));
      }
    });
  }
  assert.deepEqual(memberships, [1, 1, 1, 1]);
  assert.ok(calls[3].includes('--no-parallel'));
  assert.ok(!calls[1].includes('--no-parallel') && !calls[2].includes('--no-parallel'));
});

test('a failure in discovery or any workload stops immediately without retrying', () => {
  for (const [i, phase] of ['discovery', 'highlighting', 'core', 'native'].entries()) {
    const { result, calls } = run([], phase);
    assert.equal(result.status, 7, result.stderr);
    assert.equal(calls.length, i + 1);
  }
});

test('empty, duplicate, unknown and incomplete discovery fail before running a phase', () => {
  for (const listing of [[], [...discovered, discovered[0]], [...discovered, 'OtherTests.Suite/test()'], discovered.slice(1), ['not a test specifier']]) {
    const { result, calls } = run([], '', listing);
    assert.equal(result.status, 1, result.stderr);
    assert.equal(calls.length, 1);
    assert.match(result.stderr, /discovery|phase/i);
  }
});

test('explicit selections and queries are forwarded once without widening their scope', () => {
  for (const args of [['--filter', 'DirectoryBrowsingTests'], ['--filter=PathCopyTests'], ['--skip', 'EditorTests'], ['--skip=EditorTests'], ['--specifier', 'Suite/test'], ['-s', 'Suite/test'], ['--test-product', 'PanePeekTests'], ['list'], ['last'], ['--list-tests'], ['-l'], ['--help'], ['--version'], ['--show-coverage-path']]) {
    const { result, calls } = run(args);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(calls, [['test', ...args]]);
  }
});

test('failed-phase output and diagnostics are retained in the run directory', () => {
  const { result, directory } = run([], 'core');
  assert.equal(result.status, 7, result.stderr);
  const runs = join(directory, '.build/test-runs');
  const [runName] = readdirSync(runs);
  const log = readFileSync(join(runs, runName, 'core.log'), 'utf8');
  assert.match(log, /core output/);
  assert.match(log, /core diagnostics/);
  assert.match(result.stderr, /core/);
});

test('a hung command fails at its process bound and records the reason', { timeout: 90_000 }, async () => {
  const { runProcess } = await import('../../scripts/test.mjs');
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-test-bound-'));
  temporary.push(directory);
  const logFile = join(directory, 'hung.log');
  await assert.rejects(runProcess(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], {
    label: 'hung fixture', logFile, timeoutMs: 50, killGraceMs: 20,
  }), error => error.exitCode === 124);
  assert.match(readFileSync(logFile, 'utf8'), /hung fixture.*process bound/);
});

for (const detached of [false, true]) {
  test(`interruption closes a non-cooperative descendant (separate group: ${detached})`, { timeout: 90_000 }, async t => {
    const { runProcess } = await import('../../scripts/test.mjs');
    const { setTimeout: delay } = await import('node:timers/promises');
    const directory = mkdtempSync(join(tmpdir(), 'panepeek-test-interrupt-'));
    temporary.push(directory);
    const controller = new AbortController();
    let descendant;
    t.after(() => {
      controller.abort();
      if (descendant) {
        try { process.kill(descendant, 'SIGKILL'); }
        catch (error) { if (error.code !== 'ESRCH') { throw error; } }
      }
    });
    const outputMode = detached ? 'inherit' : 'ignore';
    const script = `
      const { spawn } = require('node:child_process');
      const child = spawn(process.execPath, ['-e', "process.on('SIGTERM', () => {}); process.send('ready'); setInterval(() => {}, 1000);"], { detached: ${detached}, stdio: ['ignore', '${outputMode}', '${outputMode}', 'ipc'] });
      child.once('message', () => console.log('READY ' + child.pid));
      setInterval(() => {}, 1000);
    `;
    let output = '';
    const run = runProcess(process.execPath, ['-e', script], {
      label: 'interrupted fixture', logFile: join(directory, 'interrupted.log'), timeoutMs: 60_000,
      signal: controller.signal, killGraceMs: 20,
      onStdout(chunk) {
        output += chunk;
        const ready = output.match(/READY (\d+)/);
        if (ready) {
          descendant = Number(ready[1]);
          controller.abort(Object.assign(new Error('fixture cancellation'), { exitCode: 130 }));
        }
      },
    });
    await assert.rejects(run, error => error.exitCode === 130);
    assert.ok(descendant, 'the descendant acknowledged its signal handler before cancellation');
    // A killed orphan can remain as a zombie until the OS reaps it.
    while (!t.signal.aborted) {
      const probe = spawnSync('ps', ['-o', 'stat=', '-p', String(descendant)], { encoding: 'utf8' });
      assert.ifError(probe.error);
      assert.equal(probe.stderr, '', 'process status must be readable');
      assert.ok([0, 1].includes(probe.status));
      if (!probe.stdout.trim() || probe.stdout.trim().startsWith('Z')) { return; }
      await delay(10, undefined, { signal: t.signal });
    }
    assert.fail('the descendant must terminate after interruption');
  });
}

test('an unavailable command fails with a useful diagnostic', async () => {
  const { runProcess } = await import('../../scripts/test.mjs');
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-test-missing-'));
  temporary.push(directory);
  await assert.rejects(runProcess(join(directory, 'missing-command'), [], {
    label: 'missing fixture', logFile: join(directory, 'missing.log'), timeoutMs: 1_000,
  }), /missing fixture.*ENOENT/);
});

test('explicit concurrency controls keep the caller invocation intact', () => {
  for (const args of [['--parallel', '--num-workers', '2'], ['--no-parallel'], ['-s=Suite/test']]) {
    const { result, calls } = run(args);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(calls, [['test', ...args]]);
  }
});

test('test-list query stdout remains machine-readable', () => {
  const { result } = run(['list']);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, discovered.join('\n') + '\n');
});
