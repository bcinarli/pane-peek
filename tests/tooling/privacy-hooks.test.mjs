import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { afterEach, test } from 'node:test';

const root = fileURLToPath(new URL('../..', import.meta.url));
const temporary = [];
const environment = { ...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_TERMINAL_PROMPT: '0' };
const token = () => ['ghp', randomBytes(18).toString('hex')].join('_');
const privatePath = () => ['', 'Users', 'hook-fixture-person', 'private.md'].join('/');

afterEach(() => {
  for (const path of temporary.splice(0)) {
    rmSync(path, { recursive: true, force: true });
  }
});

function directory() {
  const path = mkdtempSync(join(tmpdir(), 'panepeek-hooks-test-'));
  temporary.push(path);
  return path;
}

function command(repo, args, options = {}) {
  return spawnSync('git', ['-C', repo, ...args], {
    encoding: 'utf8', timeout: 60_000, env: environment, ...options
  });
}

function git(repo, ...args) {
  const result = command(repo, args);
  assert.equal(result.status, 0, 'fixture Git operation must succeed');
  return result.stdout.trim();
}

function write(repo, name, text) {
  mkdirSync(dirname(join(repo, name)), { recursive: true });
  writeFileSync(join(repo, name), text);
}

function tooling(repo) {
  mkdirSync(join(repo, 'scripts'), { recursive: true });
  for (const name of ['privacy-hooks.mjs', 'check-privacy.mjs', 'privacy-rules.json', 'gitleaks.toml']) {
    copyFileSync(join(root, 'scripts', name), join(repo, 'scripts', name));
  }
}

function repository() {
  const repo = join(directory(), 'checkout with spaces');
  mkdirSync(repo);
  git(repo, 'init', '-q', '-b', 'main');
  git(repo, 'config', 'user.name', 'Hook Test');
  git(repo, 'config', 'user.email', 'hooks@example.invalid');
  write(repo, 'README.md', 'Public fixture.\n');
  git(repo, 'add', 'README.md');
  git(repo, 'commit', '-qm', 'Initial fixture');
  tooling(repo);
  return repo;
}

function runHooks(repo, args = ['install'], { env = {}, input } = {}) {
  return spawnSync(process.execPath, [join(repo, 'scripts/privacy-hooks.mjs'), ...args], {
    cwd: repo, input, encoding: 'utf8', timeout: 60_000, env: { ...environment, ...env }
  });
}

function remote(repo) {
  const target = directory();
  git(target, 'init', '--bare', '-q', '-b', 'main');
  git(repo, 'remote', 'add', 'origin', target);
  git(repo, 'push', '-q', 'origin', 'main');
  return target;
}

function removedSecret(repo) {
  const secret = token();
  write(repo, 'removed.md', `${secret}\n${privatePath()}\n`);
  git(repo, 'add', 'removed.md');
  git(repo, 'commit', '-qm', 'Synthetic sensitive fixture');
  git(repo, 'rm', '-q', 'removed.md');
  git(repo, 'commit', '-qm', 'Remove synthetic fixture');
  return secret;
}

test('installed pre-commit rejects the index even when the working copy is clean', () => {
  const repo = repository();
  assert.equal(runHooks(repo).status, 0);
  const before = git(repo, 'rev-parse', 'HEAD');
  const secret = token();
  write(repo, 'staged.md', `${secret}\n${privatePath()}\n`);
  git(repo, 'add', 'staged.md');
  write(repo, 'staged.md', 'Unstaged cleanup.\n');
  const result = command(repo, ['commit', '-qm', 'Must be blocked']);
  assert.notEqual(result.status, 0, 'a sensitive staged blob must prevent the commit');
  assert.equal(git(repo, 'rev-parse', 'HEAD'), before);
  const output = result.stdout + result.stderr;
  assert.match(output, /github-pat/);
  assert.match(output, /private-home-path/);
  assert.ok(!output.includes(secret) && !output.includes(privatePath()) && !output.includes(repo));
});

test('pre-commit permits clean staged content without inspecting unstaged secrets', () => {
  const repo = repository();
  assert.equal(runHooks(repo).status, 0);
  write(repo, 'README.md', 'Public staged change.\n');
  git(repo, 'add', 'README.md');
  write(repo, 'README.md', token());
  assert.equal(command(repo, ['commit', '-qm', 'Public change']).status, 0);
  assert.equal(git(repo, 'show', 'HEAD:README.md'), 'Public staged change.');
});

test('pre-push blocks removed secrets in an existing branch before remote mutation', () => {
  const repo = repository();
  const target = remote(repo);
  const before = git(target, 'rev-parse', 'main');
  const secret = removedSecret(repo);
  assert.equal(runHooks(repo).status, 0);
  const result = command(repo, ['push', 'origin', 'main']);
  assert.notEqual(result.status, 0, 'outgoing history must be checked before upload');
  assert.equal(git(target, 'rev-parse', 'main'), before);
  assert.match(result.stdout + result.stderr, /github-pat/);
  assert.ok(!(result.stdout + result.stderr).includes(secret));
});

test('pre-push checks new-branch ancestry rather than only its clean tip', () => {
  const repo = repository();
  const target = remote(repo);
  git(repo, 'switch', '-qc', 'new-branch');
  removedSecret(repo);
  git(repo, 'update-ref', 'refs/remotes/origin/new-branch', 'HEAD');
  assert.equal(runHooks(repo).status, 0);
  const result = command(repo, ['push', 'origin', 'new-branch']);
  assert.notEqual(result.status, 0, 'a clean new-branch tip must not conceal earlier sensitive commits');
  assert.notEqual(command(target, ['rev-parse', '--verify', 'refs/heads/new-branch']).status, 0);
});

test('a clean new branch excludes history already present at the destination', () => {
  const repo = repository();
  removedSecret(repo);
  const target = remote(repo);
  git(repo, 'switch', '-qc', 'public-branch');
  write(repo, 'public.md', 'Public outgoing content.\n');
  git(repo, 'add', 'public.md');
  git(repo, 'commit', '-qm', 'Public change');
  assert.equal(runHooks(repo).status, 0);
  const result = command(repo, ['push', 'origin', 'public-branch']);
  assert.equal(result.status, 0, 'existing destination history is outside the outgoing range');
  assert.equal(git(target, 'rev-parse', 'public-branch'), git(repo, 'rev-parse', 'HEAD'));
});

test('setup refuses existing hooks or custom hook managers without partial writes', () => {
  for (const customConfig of [false, true]) {
    const repo = repository();
    const hooks = git(repo, 'rev-parse', '--path-format=absolute', '--git-path', 'hooks');
    if (customConfig) {
      git(repo, 'config', 'core.hooksPath', 'custom hooks');
    } else {
      writeFileSync(join(hooks, 'pre-push'), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
    }
    const result = runHooks(repo);
    assert.equal(result.status, 2, 'setup must preserve existing hook ownership');
    assert.ok(!existsSync(join(hooks, 'pre-commit')));
    if (!customConfig) {
      assert.equal(readFileSync(join(hooks, 'pre-push'), 'utf8'), '#!/bin/sh\nexit 0\n');
    } else {
      assert.equal(git(repo, 'config', '--get', 'core.hooksPath'), 'custom hooks');
    }
  }
});

test('installation is idempotent and uninstall removes only unchanged owned hooks', () => {
  const repo = repository();
  assert.equal(runHooks(repo).status, 0);
  const hooks = git(repo, 'rev-parse', '--path-format=absolute', '--git-path', 'hooks');
  assert.ok(existsSync(join(hooks, 'pre-commit')), 'explicit setup must install a pre-commit hook');
  const original = readFileSync(join(hooks, 'pre-commit'));
  assert.equal(runHooks(repo).status, 0);
  assert.deepEqual(readFileSync(join(hooks, 'pre-commit')), original);
  assert.ok(lstatSync(join(hooks, 'pre-commit')).mode & 0o111);
  writeFileSync(join(hooks, 'post-commit'), 'unrelated hook\n');
  writeFileSync(join(hooks, 'pre-push'), 'modified by another owner\n');
  assert.equal(runHooks(repo, ['uninstall']).status, 2);
  assert.deepEqual(readFileSync(join(hooks, 'pre-commit')), original);
  assert.equal(readFileSync(join(hooks, 'pre-push'), 'utf8'), 'modified by another owner\n');
});

test('hooks installed from a linked worktree check that worktree’s index', () => {
  const repo = repository();
  const linked = join(directory(), 'linked checkout');
  git(repo, 'worktree', 'add', '-qb', 'linked', linked);
  tooling(linked);
  assert.equal(runHooks(linked).status, 0);
  write(linked, 'linked.md', token());
  git(linked, 'add', 'linked.md');
  const result = command(linked, ['commit', '-qm', 'Must be blocked']);
  assert.notEqual(result.status, 0, 'the linked index must be protected by the common hook');
  write(repo, 'README.md', 'Independent public index.\n');
  git(repo, 'add', 'README.md');
  assert.equal(command(repo, ['commit', '-qm', 'Independent public change']).status, 0);
});

test('an empty destination requires checking all ancestry before its first upload', () => {
  const repo = repository();
  removedSecret(repo);
  const target = directory();
  git(target, 'init', '--bare', '-q', '-b', 'main');
  assert.equal(runHooks(repo).status, 0);
  assert.notEqual(command(repo, ['push', target, 'main']).status, 0);
  assert.notEqual(command(target, ['rev-parse', '--verify', 'main']).status, 0);
});

test('all ref updates are checked before any branch is pushed', () => {
  const repo = repository();
  const target = remote(repo);
  git(repo, 'switch', '-qc', 'clean');
  write(repo, 'public.md', 'Public change.\n');
  git(repo, 'add', 'public.md');
  git(repo, 'commit', '-qm', 'Public change');
  git(repo, 'switch', '-qc', 'sensitive', 'main');
  removedSecret(repo);
  assert.equal(runHooks(repo).status, 0);
  assert.notEqual(command(repo, ['push', 'origin', 'clean', 'sensitive']).status, 0);
  assert.notEqual(command(target, ['rev-parse', '--verify', 'clean']).status, 0);
  assert.notEqual(command(target, ['rev-parse', '--verify', 'sensitive']).status, 0);
});

test('force pushes cannot conceal removed sensitive commits', () => {
  const repo = repository();
  const target = remote(repo);
  const fork = git(repo, 'rev-parse', 'HEAD');
  write(repo, 'public.md', 'Remote advance.\n');
  git(repo, 'add', 'public.md');
  git(repo, 'commit', '-qm', 'Remote advance');
  git(repo, 'push', '-q', 'origin', 'main');
  const before = git(target, 'rev-parse', 'main');
  git(repo, 'switch', '-qc', 'rewrite', fork);
  removedSecret(repo);
  assert.equal(runHooks(repo).status, 0);
  assert.notEqual(command(repo, ['push', '--force', 'origin', 'rewrite:main']).status, 0);
  assert.equal(git(target, 'rev-parse', 'main'), before);
});

test('deletion-only and empty pushes need no scanner while malformed input fails closed', () => {
  const repo = repository();
  const head = git(repo, 'rev-parse', 'HEAD');
  const zeros = '0'.repeat(head.length);
  const env = { GITLEAKS_BIN: join(directory(), 'missing-scanner') };
  assert.equal(runHooks(repo, ['pre-push', 'origin', 'unused'], { env, input: '' }).status, 0);
  assert.equal(runHooks(repo, ['pre-push', 'origin', 'unused'], {
    env, input: `(delete) ${zeros} refs/heads/old ${head}\n`
  }).status, 0);
  assert.equal(runHooks(repo, ['pre-push', 'origin', 'unused'], {
    input: `refs/heads/main invalid-object refs/heads/main ${head}\n`
  }).status, 2);
});

test('missing remote bases and failed remote metadata queries fail without raw diagnostics', () => {
  const repo = repository();
  const head = git(repo, 'rev-parse', 'HEAD');
  const missing = randomBytes(head.length / 2).toString('hex');
  assert.equal(runHooks(repo, ['pre-push', 'origin', 'unused'], {
    input: `refs/heads/main ${head} refs/heads/main ${missing}\n`
  }).status, 2);
  const destination = join(directory(), 'PRIVATE_REMOTE_MARKER');
  const failed = runHooks(repo, ['pre-push', 'origin', destination], {
    input: `refs/heads/main ${head} refs/heads/new ${'0'.repeat(head.length)}\n`
  });
  assert.equal(failed.status, 2);
  assert.ok(!(failed.stdout + failed.stderr).includes(destination));
  assert.ok(!(failed.stdout + failed.stderr).includes('PRIVATE_REMOTE_MARKER'));
});

test('missing scanners stop setup and commits without removing existing owned hooks', () => {
  const repo = repository();
  const hooks = git(repo, 'rev-parse', '--path-format=absolute', '--git-path', 'hooks');
  const missing = { GITLEAKS_BIN: join(directory(), 'missing') };
  assert.equal(runHooks(repo, ['install'], { env: missing }).status, 2);
  assert.ok(!existsSync(join(hooks, 'pre-commit')));
  assert.equal(runHooks(repo).status, 0);
  write(repo, 'README.md', 'Public change.\n');
  git(repo, 'add', 'README.md');
  const result = command(repo, ['commit', '-qm', 'Blocked without scanner'], { env: { ...environment, ...missing } });
  assert.notEqual(result.status, 0);
  assert.ok(existsSync(join(hooks, 'pre-commit')));
});

test('setup never follows an existing hook symlink', () => {
  const repo = repository();
  const target = join(directory(), 'unrelated');
  writeFileSync(target, 'Unrelated owner.\n');
  const hooks = git(repo, 'rev-parse', '--path-format=absolute', '--git-path', 'hooks');
  symlinkSync(target, join(hooks, 'pre-push'));
  assert.equal(runHooks(repo).status, 2);
  assert.ok(lstatSync(join(hooks, 'pre-push')).isSymbolicLink());
  assert.equal(readFileSync(target, 'utf8'), 'Unrelated owner.\n');
  assert.ok(!existsSync(join(hooks, 'pre-commit')));
});

test('uninstall removes only its two unchanged wrappers and leaves configuration untouched', () => {
  const repo = repository();
  assert.equal(runHooks(repo).status, 0);
  const hooks = git(repo, 'rev-parse', '--path-format=absolute', '--git-path', 'hooks');
  writeFileSync(join(hooks, 'post-commit'), 'Unrelated hook.\n');
  assert.equal(runHooks(repo, ['uninstall']).status, 0);
  assert.ok(!existsSync(join(hooks, 'pre-commit')) && !existsSync(join(hooks, 'pre-push')));
  assert.equal(readFileSync(join(hooks, 'post-commit'), 'utf8'), 'Unrelated hook.\n');
  assert.equal(command(repo, ['config', '--get', 'core.hooksPath']).status, 1);
});

test('a linked checkout without tooling fails closed with a portable message', () => {
  const repo = repository();
  const linked = join(directory(), 'older linked checkout');
  git(repo, 'worktree', 'add', '-qb', 'older', linked);
  assert.equal(runHooks(repo).status, 0);
  write(linked, 'public.md', 'Public change.\n');
  git(linked, 'add', 'public.md');
  const result = command(linked, ['commit', '-qm', 'Missing tooling']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /tooling is missing/);
  assert.ok(!result.stderr.includes(repo) && !result.stderr.includes(linked));
});

test('unexpected setup errors never echo policy bytes or private filesystem paths', () => {
  const repo = repository();
  const marker = 'ZLEAK42';
  write(repo, 'scripts/privacy-rules.json', marker);
  const result = runHooks(repo);
  assert.equal(result.status, 2);
  assert.ok(!(result.stdout + result.stderr).includes(marker), 'raw parser diagnostics must be withheld');
  assert.ok(!(result.stdout + result.stderr).includes(repo));
});

test('shallow history fails closed before a new destination can receive it', () => {
  const repo = repository();
  removedSecret(repo);
  const source = remote(repo);
  const shallow = join(directory(), 'shallow');
  git(repo, 'clone', '-q', '--depth', '1', pathToFileURL(source).href, shallow);
  tooling(shallow);
  const target = directory();
  git(target, 'init', '--bare', '-q', '-b', 'main');
  const head = git(shallow, 'rev-parse', 'HEAD');
  const result = runHooks(shallow, ['pre-push', 'new-destination', target], {
    input: `refs/heads/main ${head} refs/heads/main ${'0'.repeat(head.length)}\n`
  });
  assert.equal(result.status, 2, 'incomplete ancestry cannot establish a clean outgoing scan');
});

test('annotated commit tags are scanned and can be pushed when clean', () => {
  const repo = repository();
  const target = remote(repo);
  git(repo, 'tag', '-am', 'Public tag', 'v0.0.1');
  assert.equal(runHooks(repo).status, 0);
  assert.equal(command(repo, ['push', 'origin', 'v0.0.1']).status, 0);
  assert.equal(git(target, 'rev-parse', 'refs/tags/v0.0.1'), git(repo, 'rev-parse', 'v0.0.1'));
});

test('a missing checker blocks the commit without exposing the checkout path', () => {
  const repo = repository();
  assert.equal(runHooks(repo).status, 0);
  const checker = join(repo, 'scripts/check-privacy.mjs');
  renameSync(checker, `${checker}.disabled`);
  write(repo, 'README.md', 'Public change.\n');
  git(repo, 'add', 'README.md');
  const result = command(repo, ['commit', '-qm', 'Must be blocked']);
  assert.notEqual(result.status, 0);
  assert.ok(!(result.stdout + result.stderr).includes(repo), 'runtime startup errors must not expose local paths');
});

test('a push from a linked worktree checks its outgoing commits against the destination', () => {
  const repo = repository();
  const target = remote(repo);
  const linked = join(directory(), 'linked push checkout');
  git(repo, 'worktree', 'add', '-qb', 'linked-push', linked);
  tooling(linked);
  removedSecret(linked);
  assert.equal(runHooks(linked).status, 0);
  const result = command(linked, ['push', 'origin', 'linked-push']);
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /github-pat/);
  assert.notEqual(command(target, ['rev-parse', '--verify', 'linked-push']).status, 0);
});
