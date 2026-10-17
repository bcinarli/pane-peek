import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, unlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, test } from 'node:test';
import { inspectFile } from '../../scripts/check-privacy.mjs';

const root = fileURLToPath(new URL('../..', import.meta.url));
const checker = join(root, 'scripts/check-privacy.mjs');
const temporary = [];
const homePath = (...parts) => ['', 'Users', 'fixture-person', ...parts].join('/');
const token = () => ['ghp', randomBytes(18).toString('hex')].join('_');

afterEach(() => {
  for (const directory of temporary.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function directory() {
  const result = mkdtempSync(join(tmpdir(), 'panepeek-privacy-test-'));
  temporary.push(result);
  return result;
}

function git(repo, ...args) {
  const result = spawnSync('git', ['-C', repo, ...args], { encoding: 'utf8' });
  assert.equal(result.status, 0, 'fixture Git operation failed');
  return result.stdout.trim();
}

function write(repo, file, contents) {
  mkdirSync(dirname(join(repo, file)), { recursive: true });
  writeFileSync(join(repo, file), contents);
}

function repository() {
  const repo = directory();
  git(repo, 'init', '-q', '-b', 'main');
  git(repo, 'config', 'user.name', 'Privacy Test');
  git(repo, 'config', 'user.email', 'privacy@example.invalid');
  write(repo, 'README.md', 'Disposable public fixture.\n');
  git(repo, 'add', '.');
  git(repo, 'commit', '-qm', 'Initial fixture');
  return repo;
}

function run(repo, args = [], extraEnv = {}) {
  return spawnSync(process.execPath, [checker, '--repo', repo, ...args], {
    encoding: 'utf8', env: { ...process.env, ...extraEnv }, timeout: 60_000
  });
}

test('detects personal POSIX, Windows, encoded and private-vault paths with source line numbers', () => {
  const paths = [homePath('notes.md'), ['', 'home', 'fixture-person', 'notes.md'].join('/'),
    ['C:', 'Users', 'fixture-person', 'notes.md'].join('\\'),
    ['c:', 'users', 'fixture-person', 'notes.md'].join('\\'),
    ['C:', 'Users', 'fixture-person', 'notes.md'].join('\\\\'),
    encodeURIComponent(homePath('notes.md')), homePath('notes.md').replaceAll('/', '&#47;'),
    ['obsidian:', '//open?vault=private'].join(''),
    ['', 'private', 'var', 'folders', 'ab', 'private-cache'].join('/')];
  for (const value of paths) {
    const findings = inspectFile('docs/notes.md', Buffer.from(`Public heading\n${value}\n`));
    assert.ok(findings.some(f => f.line === 2), 'sensitive path must be detected on its source line');
    assert.ok(findings.every(f => !JSON.stringify(f).includes(value)), 'findings must omit matched values');
  }
});

test('preserves the actual dummy drafts but does not exempt other paths or files', () => {
  const drafts = ['agent-paper-trail/design/001-mvp/app-draft.html', 'agent-paper-trail/design/001-mvp/app-draft.fragment.html'];
  for (const file of drafts) {
    assert.deepEqual(inspectFile(file, readFileSync(join(root, file))), []);
    assert.ok(inspectFile(file, Buffer.from(homePath('private.md'))).length > 0);
    const previous = ['', 'Users', 'bilal', 'Code', 'website', 'src'].join('/');
    assert.ok(inspectFile(file, Buffer.from(previous)).length > 0);
    const dummy = ['', 'Users', 'demo', 'unreviewed-private-document.md'].join('/');
    assert.ok(inspectFile(file, Buffer.from(dummy)).length > 0);
  }
  const dummy = ['', 'Users', 'demo', 'Code', 'website', 'src'].join('/');
  assert.ok(inspectFile('docs/new.md', Buffer.from(dummy)).length > 0);
});

test('preserves fictional usage examples only in the reviewed document', () => {
  const file = 'docs/usage.md';
  assert.deepEqual(inspectFile(file, readFileSync(join(root, file))), []);
  const example = ['', 'Users', 'demo', 'Documents', 'Project', 'project-brief.md'].join('/');
  assert.ok(inspectFile('docs/new.md', Buffer.from(example)).length > 0);
  assert.ok(inspectFile(file, Buffer.from(homePath('private.md'))).length > 0);
  const unreviewed = ['', 'Users', 'demo', 'Documents', 'private.md'].join('/');
  assert.ok(inspectFile(file, Buffer.from(unreviewed)).length > 0);
});

test('allows portable fixtures, system paths, public identity and unrelated home prose', () => {
  const text = 'dual/home/compact\nfile:///tmp/good\n/Applications/Xcode.app/Contents/Developer\n/usr/bin/env\nCopyright Bilal Cinarli\n';
  assert.deepEqual(inspectFile('docs/usage.md', Buffer.from(text)), []);
  assert.deepEqual(inspectFile('.env.example', Buffer.from('PORT=3000\n')), []);
});

test('preserves the existing synthetic Windows raw-string fixture with a file-specific exception', () => {
  const file = 'agent-paper-trail/validation/t06-read-only-preview-highlighting.md';
  assert.deepEqual(inspectFile(file, readFileSync(join(root, file))), []);
  const dummy = ['C:', 'Users', 'name'].join('\\\\');
  assert.ok(inspectFile('docs/new.md', Buffer.from(dummy)).length > 0);
  assert.ok(inspectFile(file, Buffer.from(homePath('notes.md'))).length > 0);
});

test('exception declarations pass their own policy while new paths in the policy remain blocked', () => {
  const file = 'scripts/privacy-rules.json';
  assert.deepEqual(inspectFile(file, readFileSync(join(root, file))), []);
  assert.ok(inspectFile(file, Buffer.from(homePath('notes.md'))).length > 0);
});

test('blocks sensitive filenames even with empty or binary contents', () => {
  for (const file of ['.env', 'config/.env.production', 'identity.p12', 'signing.pfx', '.aws/credentials', '.netrc', 'id_ed25519']) {
    assert.ok(inspectFile(file, Buffer.from([0, 1, 2])).some(f => f.rule === 'sensitive-file'));
  }
});

test('staged mode reads the index, not a cleaner working copy, and redacts diagnostics', () => {
  const repo = repository();
  const secret = token();
  const sensitive = homePath('private-note.md');
  write(repo, 'new file.md', `${secret}\n${sensitive}\n`);
  git(repo, 'add', 'new file.md');
  write(repo, 'new file.md', 'Unstaged cleanup.\n');
  const result = run(repo, ['--staged']);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /private-home-path/);
  assert.match(result.stdout, /github-pat/);
  assert.ok(!`${result.stdout}${result.stderr}`.includes(secret));
  assert.ok(!`${result.stdout}${result.stderr}`.includes(sensitive));
  assert.ok(!`${result.stdout}${result.stderr}`.includes(repo));
});

test('unstaged secrets do not contaminate a clean staged change', () => {
  const repo = repository();
  write(repo, 'README.md', 'A staged public change.\n');
  git(repo, 'add', 'README.md');
  write(repo, 'README.md', token());
  const result = run(repo, ['--staged']);
  assert.equal(result.status, 0);
});

test('staged type changes are scanned and unusual filenames are safely quoted', () => {
  const repo = repository();
  const file = 'changed\nfile.md';
  symlinkSync('README.md', join(repo, file));
  git(repo, 'add', '.');
  git(repo, 'commit', '-qm', 'Add synthetic link');
  unlinkSync(join(repo, file));
  write(repo, file, token());
  git(repo, 'add', '.');
  const result = run(repo, ['--staged']);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /github-pat/);
  assert.ok(result.stdout.includes(JSON.stringify(file)));
  assert.ok(!result.stdout.includes(file));
});

test('tree mode ignores working files and checks the requested commit', () => {
  const repo = repository();
  write(repo, 'private.md', `${token()}\n${homePath('notes.md')}\n`);
  git(repo, 'add', '.');
  git(repo, 'commit', '-qm', 'Synthetic sensitive fixture');
  write(repo, 'private.md', 'Working copy is clean.\n');
  assert.equal(run(repo, ['--tree', 'HEAD']).status, 1);
  assert.equal(run(repo, ['--tree', 'HEAD~1']).status, 0);
});

test('range mode catches secrets and private paths removed before the tip', () => {
  const repo = repository();
  const base = git(repo, 'rev-parse', 'HEAD');
  write(repo, 'removed.md', `${token()}\n${homePath('notes.md')}\n`);
  git(repo, 'add', '.');
  git(repo, 'commit', '-qm', 'Add synthetic finding');
  const introduced = git(repo, 'rev-parse', 'HEAD');
  git(repo, 'rm', '-q', 'removed.md');
  git(repo, 'commit', '-qm', 'Remove synthetic finding');
  assert.equal(run(repo, ['--tree', 'HEAD']).status, 0);
  const result = run(repo, ['--range', base, 'HEAD']);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /private-home-path/);
  assert.match(result.stdout, /github-pat/);
  assert.ok(result.stdout.includes(introduced.slice(0, 12)));
});

test('symlinks are inspected as link text without reading targets outside Git', () => {
  const repo = repository();
  const outside = join(directory(), 'outside.md');
  writeFileSync(outside, token());
  symlinkSync(relative(repo, outside), join(repo, 'external.md'));
  git(repo, 'add', 'external.md');
  assert.equal(run(repo, ['--staged']).status, 0);
});

test('unsupported submodules fail closed instead of being silently omitted', () => {
  const repo = repository();
  git(repo, 'update-index', '--add', '--cacheinfo', `160000,${git(repo, 'rev-parse', 'HEAD')},nested`);
  assert.equal(run(repo, ['--staged']).status, 2);
});

test('binary files are explicitly reported as needing manual privacy review', () => {
  const repo = repository();
  write(repo, 'image.bin', Buffer.from([0, 1, 2, 3]));
  git(repo, 'add', '.');
  const result = run(repo, ['--staged']);
  assert.equal(result.status, 0);
  assert.match(result.stdout, /1 binary file/);
});

test('scanner absence and invalid refs fail closed without raw errors', () => {
  const repo = repository();
  const fake = join(directory(), 'scanner');
  const marker = 'PRIVATE_SCANNER_ERROR';
  writeFileSync(fake, `#!/bin/sh\necho ${marker} >&2\nexit 2\n`, { mode: 0o700 });
  const cases = [
    [[], { GITLEAKS_BIN: join(dirname(fake), 'missing') }],
    [[], { GITLEAKS_BIN: fake }],
    [['--tree', '--not-a-ref'], {}],
    [['--staged', '--tree', 'HEAD'], {}]
  ];
  for (const [args, env] of cases) {
    const result = run(repo, args, env);
    assert.equal(result.status, 2);
    assert.ok(!`${result.stdout}${result.stderr}`.includes(marker));
    assert.ok(!`${result.stdout}${result.stderr}`.includes(repo));
  }
});

test('wrong scanner versions, execution failures and malformed reports cannot produce a clean result', () => {
  const repo = repository();
  const fake = join(directory(), 'scanner');
  const marker = 'PRIVATE_SCANNER_ERROR';
  const cases = [
    `echo 0.0.0; exit 0`,
    `if [ "$1" = version ]; then echo 8.30.1; exit 0; fi\necho ${marker} >&2; exit 2`,
    `if [ "$1" = version ]; then echo 8.30.1; exit 0; fi\nexit 0`,
    `if [ "$1" = version ]; then echo 8.30.1; exit 0; fi\nfor arg do\n  if [ "$previous" = --report-path ]; then echo '{}' > "$arg"; fi\n  previous="$arg"\ndone\nexit 0`
  ];
  for (const script of cases) {
    writeFileSync(fake, `#!/bin/sh\n${script}\n`, { mode: 0o700 });
    const result = run(repo, [], { GITLEAKS_BIN: fake });
    assert.equal(result.status, 2);
    assert.ok(!`${result.stdout}${result.stderr}`.includes(marker));
    assert.ok(!`${result.stdout}${result.stderr}`.includes(repo));
  }
});

test('multiline private keys in an ordinary document are detected without echoing key bytes', () => {
  const repo = repository();
  const { privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 1024,
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    publicKeyEncoding: { type: 'spki', format: 'pem' }
  });
  write(repo, 'docs/setup.md', privateKey);
  git(repo, 'add', '.');
  const result = run(repo, ['--staged']);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /private-key/);
  assert.ok(!`${result.stdout}${result.stderr}`.includes(privateKey.split('\n')[1]));
});

test('force-added ignored files and an unborn index are scanned', () => {
  const repo = directory();
  git(repo, 'init', '-q', '-b', 'main');
  write(repo, '.gitignore', 'hidden/\n');
  write(repo, 'hidden/token.txt', token());
  git(repo, 'add', '-f', '.');
  const result = run(repo, ['--staged']);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /github-pat/);
});

test('a secret inside an environment example is scanned and inline allow comments cannot suppress it', () => {
  const repo = repository();
  write(repo, '.env.example', `TOKEN=${token()} # gitleaks:allow\n`);
  write(repo, '.gitleaksignore', '*\n');
  git(repo, 'add', '.');
  const result = run(repo, ['--staged']);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /github-pat/);
});
