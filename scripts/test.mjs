import { spawn, spawnSync } from 'node:child_process';
import { closeSync, existsSync, mkdirSync, mkdtempSync, openSync, realpathSync, writeSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));
const highlighting = '^PanePeekCoreTests\\.[^/]*HighlightingTests/';
const phases = [
  { name: 'highlighting', filter: highlighting },
  { name: 'core', filter: '^PanePeekCoreTests\\.', skip: highlighting },
  { name: 'native', filter: '^PanePeekTests\\.', serial: true },
];

export function planPhases(discovery) {
  const tests = discovery.trim().split(/\r?\n/).filter(Boolean);
  if (!tests.length || new Set(tests).size !== tests.length) {
    throw new Error('Test discovery is empty or contains duplicate specifiers.');
  }
  const plan = phases.map(phase => ({
    ...phase,
    tests: tests.filter(id => new RegExp(phase.filter).test(id) && (!phase.skip || !new RegExp(phase.skip).test(id))),
  }));
  for (const id of tests) {
    if (!/^[\w]+\.[^/]+\/.+$/.test(id) || plan.filter(phase => phase.tests.includes(id)).length !== 1) {
      throw new Error(`Test discovery has no unique phase for ${id}`);
    }
  }
  for (const phase of plan) {
    if (!phase.tests.length) { throw new Error(`Test discovery has an empty ${phase.name} phase.`); }
  }
  return plan;
}

function failure(message, exitCode = 1) {
  return Object.assign(new Error(message), { exitCode });
}

// SwiftPM puts its workers in separate groups. Capture them before signalling
// the parent, while ancestry still identifies the processes owned by this run.
function ownedProcessGroups(parent) {
  const result = spawnSync('ps', ['-axo', 'pid=,ppid=,pgid='], {
    encoding: 'utf8', timeout: 1_000, maxBuffer: 4 * 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    throw new Error(`Cannot inspect test descendants: ${result.error?.message ?? result.stderr}`);
  }
  const processes = result.stdout.trim().split('\n').map(line => line.trim().split(/\s+/).map(Number));
  const owned = new Set([parent]);
  let previousSize;
  do {
    previousSize = owned.size;
    for (const [pid, ppid] of processes) {
      if (owned.has(ppid)) { owned.add(pid); }
    }
  } while (owned.size !== previousSize);
  return new Set([parent, ...processes.filter(([pid, , group]) => owned.has(pid) && group > 0 && owned.has(group)).map(([, , group]) => group)]);
}

/** Run a bounded command, retaining output and cleaning up owned process groups. */
export async function runProcess(command, args, {
  cwd = projectRoot, label, logFile, timeoutMs, signal, killGraceMs = 2_000,
  onStdout = chunk => process.stdout.write(chunk),
}) {
  if (signal?.aborted) { throw signal.reason; }
  const log = openSync(logFile, 'wx');
  const child = spawn(command, args, { cwd, detached: true, stdio: ['ignore', 'pipe', 'pipe'] });
  const closed = new Promise(resolve => child.once('close', (code, signal) => resolve({ code, signal })));
  let completeStop;
  const stopped = new Promise(resolve => { completeStop = resolve; });
  let reason;
  let spawnError;
  const diagnostic = message => {
    try { writeSync(log, message); } catch { /* Cleanup must still run if the log cannot be written. */ }
    if (!process.stderr.destroyed) { process.stderr.write(message); }
  };
  const signalGroups = (groups, signal) => {
    for (const group of groups) {
      try { process.kill(-group, signal); }
      catch (error) {
        if (error.code !== 'ESRCH') { diagnostic(`${label}: group ${group}: ${error.message}\n`); }
      }
    }
  };
  const stop = error => {
    if (reason) { return; }
    reason = error;
    diagnostic(`${label}: ${error.message}\n`);
    let groups = new Set(child.pid ? [child.pid] : []);
    if (child.pid) {
      try { groups = ownedProcessGroups(child.pid); }
      catch (error) { diagnostic(`${label}: ${error.message}\n`); }
    }
    signalGroups(groups, 'SIGTERM');
    // Retain every captured group even if its parent exits during shutdown.
    setTimeout(() => {
      signalGroups(groups, 'SIGKILL');
      // An inherited pipe must not extend the process bound after escalation.
      child.stdout.destroy();
      child.stderr.destroy();
      child.unref();
      completeStop();
    }, killGraceMs);
  };
  const interrupted = () => stop(signal.reason ?? failure(`${label} interrupted`, 130));
  const deadline = setTimeout(() => stop(failure(`${label} exceeded its ${timeoutMs} ms process bound`, 124)), timeoutMs);
  signal?.addEventListener('abort', interrupted, { once: true });
  child.on('error', error => { spawnError = error; });
  child.stdout.on('data', chunk => {
    try { writeSync(log, chunk); onStdout(chunk); }
    catch (error) { stop(failure(`${label}: ${error.message}`)); }
  });
  child.stderr.on('data', chunk => {
    try { writeSync(log, chunk); process.stderr.write(chunk); }
    catch (error) { stop(failure(`${label}: ${error.message}`)); }
  });
  try {
    const result = await Promise.race([closed, stopped]);
    if (reason) { await stopped; throw reason; }
    if (child.pid) { signalGroups([child.pid], 'SIGKILL'); }
    if (spawnError) { throw failure(`${label}: ${spawnError.message}`); }
    if (result.code !== 0) { throw failure(`${label} failed (${result.signal ?? result.code})`, result.code ?? 1); }
  } finally {
    clearTimeout(deadline);
    signal?.removeEventListener('abort', interrupted);
    closeSync(log);
  }
}

export async function main(extraArgs = process.argv.slice(2)) {
  const runs = join(projectRoot, '.build/test-runs');
  mkdirSync(runs, { recursive: true });
  const logs = mkdtempSync(join(runs, 'run-'));
  console.error(`Test logs: ${relative(projectRoot, logs)}`);
  const controller = new AbortController();
  const interrupt = signal => controller.abort(failure(`Test run interrupted by ${signal}`, signal === 'SIGINT' ? 130 : 143));
  const onInterrupt = () => interrupt('SIGINT');
  const onTerminate = () => interrupt('SIGTERM');
  process.once('SIGINT', onInterrupt);
  process.once('SIGTERM', onTerminate);
  const overall = setTimeout(() => controller.abort(failure('Test run exceeded its 18 minute process bound', 124)), 18 * 60_000);
  const run = async (name, command, args, timeoutMs, capture = false) => {
    const output = [];
    await runProcess(command, args, {
      label: name, cwd: projectRoot, logFile: join(logs, `${name}.log`), timeoutMs, signal: controller.signal,
      ...(capture ? { onStdout: chunk => { output.push(chunk); } } : {}),
    });
    return Buffer.concat(output).toString('utf8');
  };
  try {
    const swiftc = (await run('toolchain', 'xcrun', ['--find', 'swiftc'], 30_000, true)).trim();
    const testingPlugins = resolve(dirname(swiftc), '..', 'lib', 'swift', 'host', 'plugins', 'testing');
    const args = ['test'];
    if (existsSync(testingPlugins)) { args.push('-Xswiftc', '-plugin-path', '-Xswiftc', testingPlugins); }
    args.push(...extraArgs);
    const customInvocation = extraArgs.some(arg =>
      /^(--filter|--skip|--specifier|--test-product|--num-workers)(=|$)/.test(arg) ||
      (arg.startsWith('-s') && !arg.startsWith('--')) ||
      ['--parallel', '--no-parallel', 'list', 'last', '--list-tests', '-l', '--help', '-help', '-h', '--version', '--show-codecov-path', '--show-code-coverage-path', '--show-coverage-path'].includes(arg)
    );
    if (customInvocation) {
      await run('selection', 'swift', args, 15 * 60_000);
      return;
    }
    console.log('Discovering tests and validating phase coverage…');
    const plan = planPhases(await run('discovery', 'swift', [...args, 'list'], 10 * 60_000, true));
    for (const phase of plan) {
      console.log(`Running ${phase.name}: ${phase.tests.length} tests${phase.serial ? ' (serial)' : ''}`);
      const selection = ['--skip-build', '--filter', phase.filter];
      if (phase.skip) { selection.push('--skip', phase.skip); }
      if (phase.serial) { selection.push('--no-parallel'); }
      await run(phase.name, 'swift', [...args, ...selection], 5 * 60_000);
    }
  } finally {
    clearTimeout(overall);
    process.removeListener('SIGINT', onInterrupt);
    process.removeListener('SIGTERM', onTerminate);
  }
}

if (process.argv[1] && existsSync(process.argv[1]) && fileURLToPath(import.meta.url) === realpathSync(process.argv[1])) {
  main().catch(error => {
    console.error(`Tests failed: ${error.message}`);
    process.exitCode = error.exitCode ?? 1;
  });
}
