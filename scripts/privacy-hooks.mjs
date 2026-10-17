import { spawnSync } from 'node:child_process';
import { chmodSync, lstatSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const hookNames = ['pre-commit', 'pre-push'];
const objectName = /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/;
const zeroObject = /^0+$/;
class HookError extends Error {}

function git(args) {
  return spawnSync('git', args, {
    encoding: 'utf8', timeout: 30_000, maxBuffer: 16 * 1024 * 1024,
    env: { ...process.env, GIT_OPTIONAL_LOCKS: '0', GIT_NO_REPLACE_OBJECTS: '1' }
  });
}

function readGit(args) {
  const result = git(args);
  if (result.error || result.status !== 0) {
    throw new HookError('Git content or remote metadata is unavailable. Fetch the destination and retry.');
  }
  return result.stdout.trim();
}

function hookSource(name) {
  return `#!/bin/sh
# PanePeek privacy hook, managed by scripts/privacy-hooks.mjs.
if ! command -v node >/dev/null 2>&1; then
  echo 'Privacy hooks require Node.js 24 or later on Git’s PATH.' >&2
  exit 2
fi
if [ ! -f scripts/privacy-hooks.mjs ]; then
  echo 'Privacy hook tooling is missing from this checkout. Update it before retrying.' >&2
  exit 2
fi
exec node scripts/privacy-hooks.mjs ${name} "$@"
`;
}

function entry(path) {
  try {
    return lstatSync(path);
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error;
    }
    return null;
  }
}

function setup(mode) {
  readGit(['rev-parse', '--show-toplevel']);
  const configured = git(['config', '--get', 'core.hooksPath']);
  if (configured.status === 0) {
    throw new HookError('Custom core.hooksPath is configured. Integrate the documented checker commands with that hook manager.');
  }
  if (configured.error || configured.status !== 1) {
    throw new HookError('Hook configuration could not be read.');
  }
  const directory = readGit(['rev-parse', '--path-format=absolute', '--git-path', 'hooks']);
  const directoryEntry = entry(directory);
  if (directoryEntry && !directoryEntry.isDirectory()) {
    throw new HookError('The hooks directory is managed elsewhere. Existing hooks were preserved.');
  }
  const hooks = hookNames.map(name => ({ path: join(directory, name), source: hookSource(name) }));
  // Check both destinations before creating or removing either hook.
  for (const hook of hooks) {
    const existing = entry(hook.path);
    hook.exists = Boolean(existing);
    if (existing && (!existing.isFile() || readFileSync(hook.path, 'utf8') !== hook.source)) {
      throw new HookError('Existing or modified hooks were preserved. Integrate the documented commands manually.');
    }
  }
  if (mode === 'install') {
    const version = JSON.parse(readFileSync(join(scriptDirectory, 'privacy-rules.json'), 'utf8')).gitleaksVersion;
    const scanner = spawnSync(process.env.GITLEAKS_BIN || 'gitleaks', ['version'], { encoding: 'utf8', timeout: 5_000 });
    if (scanner.error || scanner.status !== 0 || scanner.stdout.trim() !== version) {
      throw new HookError('Install the pinned Gitleaks version before setting up hooks.');
    }
    mkdirSync(directory, { recursive: true });
    for (const hook of hooks) {
      if (!hook.exists) {
        writeFileSync(hook.path, hook.source, { flag: 'wx', mode: 0o755 });
      }
      chmodSync(hook.path, 0o755);
    }
  } else {
    for (const hook of hooks) {
      if (hook.exists) {
        unlinkSync(hook.path);
      }
    }
  }
  console.log(mode === 'install' ? 'Privacy hooks installed in this clone’s default hooks directory.' : 'Owned privacy hooks removed.');
}

async function check(options) {
  // Import inside the error boundary so missing or broken tooling stays redacted.
  const { checkRepository, reportResult } = await import('./check-privacy.mjs');
  return reportResult(checkRepository({ repo: process.cwd(), ...options }));
}

async function push(destination) {
  const input = readFileSync(0, 'utf8').trim();
  const updates = input ? input.split('\n').map(line => line.trim().split(/\s+/)) : [];
  for (const fields of updates) {
    if (fields.length !== 4 || !objectName.test(fields[1]) || !objectName.test(fields[3])) {
      throw new HookError('Invalid pre-push input. Privacy checks could not complete.');
    }
  }
  if (updates.some(([, local]) => !zeroObject.test(local)) && readGit(['rev-parse', '--is-shallow-repository']) !== 'false') {
    throw new HookError('Complete Git history is required. Unshallow the checkout before pushing.');
  }
  let remoteCommits;
  const checkedTrees = new Set();
  for (const [, local, , remote] of updates) {
    if (zeroObject.test(local)) {
      continue;
    }
    if (!zeroObject.test(remote)) {
      const status = await check({ mode: 'range', from: remote, to: local });
      if (status !== 0) {
        return status;
      }
      continue;
    }
    // Fresh destination refs avoid trusting stale local remote-tracking refs.
    remoteCommits ??= readGit(['ls-remote', '--refs', '--', destination]).split('\n').filter(Boolean).map(line => {
      const oid = line.split('\t')[0];
      if (!objectName.test(oid)) {
        throw new HookError('Invalid destination metadata. Privacy checks could not complete.');
      }
      return oid;
    }).filter(oid => git(['rev-parse', '--verify', '--end-of-options', `${oid}^{commit}`]).status === 0);
    const head = readGit(['rev-parse', '--verify', '--end-of-options', `${local}^{commit}`]);
    const introduced = readGit(['rev-list', '--reverse', head, '--not', ...remoteCommits]).split('\n').filter(Boolean);
    for (const revision of [...introduced, head]) {
      if (!checkedTrees.has(revision)) {
        const status = await check({ mode: 'tree', ref: revision });
        if (status !== 0) {
          return status;
        }
        checkedTrees.add(revision);
      }
    }
  }
  return 0;
}

try {
  if (Number(process.versions.node.split('.')[0]) < 24) {
    throw new HookError('Privacy hooks require Node.js 24 or later.');
  }
  const [mode, ...args] = process.argv.slice(2);
  if (['install', 'uninstall'].includes(mode) && args.length === 0) {
    setup(mode);
  } else if (mode === 'pre-commit' && args.length === 0) {
    process.exitCode = await check({ mode: 'staged' });
  } else if (mode === 'pre-push' && args.length === 2) {
    process.exitCode = await push(args[1]);
  } else {
    throw new HookError('Usage: privacy-hooks.mjs install | uninstall | pre-commit | pre-push remote destination');
  }
} catch (error) {
  console.error(error instanceof HookError ? error.message : 'Privacy hook setup or check could not complete. Check tool availability, policy and Git history.');
  process.exitCode = 2;
}
