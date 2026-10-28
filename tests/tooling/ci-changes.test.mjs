import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, test } from 'node:test';

const script = fileURLToPath(new URL('../../scripts/ci-changes.mjs', import.meta.url));
const temporary = [];
const none = { swift: false, javascript: false, actions: false };
const swift = { ...none, swift: true };
const javascript = { ...none, javascript: true };
const both = { ...swift, javascript: true };
const all = { swift: true, javascript: true, actions: true };

afterEach(() => {
  for (const directory of temporary.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function git(directory, ...args) {
  return execFileSync('git', args, { cwd: directory, encoding: 'utf8', timeout: 10_000 }).trim();
}

function write(directory, path, content = 'fixture\n') {
  mkdirSync(dirname(join(directory, path)), { recursive: true });
  writeFileSync(join(directory, path), content);
}

function commit(directory) {
  git(directory, 'add', '.');
  git(directory, 'commit', '--quiet', '-m', 'Fixture changes');
  return git(directory, 'rev-parse', 'HEAD');
}

function fixture(files = ['README.md']) {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-ci-changes-'));
  temporary.push(directory);
  git(directory, 'init', '--quiet');
  git(directory, 'config', 'user.name', 'CI fixture');
  git(directory, 'config', 'user.email', 'fixture@example.invalid');
  git(directory, 'config', 'commit.gpgsign', 'false');
  git(directory, 'config', 'core.hooksPath', '/dev/null');
  for (const path of files) {
    write(directory, path);
  }
  return { directory, base: commit(directory) };
}

function run(directory, base, head, event = 'pull_request') {
  const outputDirectory = mkdtempSync(join(tmpdir(), 'panepeek-ci-output-'));
  temporary.push(outputDirectory);
  const output = join(outputDirectory, 'output');
  const summary = join(outputDirectory, 'summary');
  const result = spawnSync(process.execPath, [script], {
    cwd: directory,
    encoding: 'utf8',
    timeout: 10_000,
    env: {
      ...process.env,
      GITHUB_EVENT_NAME: event,
      CODEQL_BASE_SHA: base ?? '',
      CODEQL_HEAD_SHA: head ?? '',
      GITHUB_OUTPUT: output,
      GITHUB_STEP_SUMMARY: summary,
    },
  });
  assert.equal(result.status, 0, result.stderr);
  const scans = Object.fromEntries(readFileSync(output, 'utf8').trim().split('\n').map(line => {
    const [name, value] = line.split('=');
    assert.ok(value === 'true' || value === 'false', line);
    return [name, value === 'true'];
  }));
  return { scans, summary: readFileSync(summary, 'utf8'), stderr: result.stderr };
}

function expectSelection(files, expected) {
  for (const path of files) {
    const { directory, base } = fixture();
    write(directory, path, 'Changed input\n');
    assert.deepEqual(run(directory, base, commit(directory)).scans, expected, path);
  }
}

test('prose-only changes skip every CodeQL language', () => {
  const { directory, base } = fixture();
  for (const path of ['README.md', 'docs/usage.md', 'agent-paper-trail/specs/example/spec.md', '.github/copilot-instructions.md', 'NOTICE']) {
    write(directory, path, 'Updated prose\n');
  }
  const result = run(directory, base, commit(directory));
  assert.deepEqual(result.scans, none);
  assert.match(result.summary, /Swift.*Skip/);
  assert.match(result.summary, /JavaScript\/TypeScript.*Skip/);
});

test('website code, dependencies, tooling and tests select only JavaScript', () => {
  expectSelection(['website/_worker.js', 'website/index.html', 'website/theme.css', 'scripts/website/package-lock.json', 'scripts/website/generate-markdown.mjs', 'tests/website/pages.test.mjs'], javascript);
});

test('executable paper-trail designs retain JavaScript coverage', () => {
  expectSelection(['agent-paper-trail/design/001-mvp/app-draft.html', 'agent-paper-trail/design/001-mvp/export-icon.mjs'], javascript);
});

test('Swift, package and Xcode inputs select Swift without JavaScript', () => {
  expectSelection(['sources/panepeek/BrowserWindow.swift', 'tests/panepeek/FileInformationTests.swift', 'Package.swift', 'Package.resolved', 'xcode/Info.plist', 'xcode/panepeek.xcodeproj/project.pbxproj', 'scripts/sandbox.entitlements', 'version.json'], swift);
});

test('native build/release scripts select Swift and JavaScript', () => {
  expectSelection(['scripts/build-app.mjs', 'scripts/test.mjs', 'scripts/release-signing.mjs'], both);
});

test('other JavaScript tooling and test changes do not select Swift', () => {
  expectSelection(['scripts/check-privacy.mjs', 'scripts/privacy-hooks.mjs', 'tests/tooling/release-review.test.mjs', 'package.json', 'pnpm-lock.yaml'], javascript);
});

test('workflow, scanner and classifier changes select every language', () => {
  expectSelection(['.github/workflows/ci.yml', '.github/codeql/config.yml', '.github/actions/check/action.yml', 'scripts/ci-changes.mjs', 'tests/tooling/ci-changes.test.mjs', '.tool-versions'], all);
});

test('mixed inputs select the union and unknown inputs select every language', () => {
  const { directory, base } = fixture();
  write(directory, 'sources/panepeek/App.swift');
  write(directory, 'website/theme.js');
  assert.deepEqual(run(directory, base, commit(directory)).scans, both);
  write(directory, 'new-build-system.conf');
  assert.deepEqual(run(directory, base, commit(directory)).scans, all);
});

test('PR selection includes earlier commits and excludes unrelated base-branch changes', () => {
  const { directory, base } = fixture();
  write(directory, 'website/theme.js');
  commit(directory);
  write(directory, 'docs/usage.md');
  const head = commit(directory);
  git(directory, 'switch', '--quiet', '--detach', base);
  write(directory, 'sources/panepeek/Unrelated.swift');
  const advancedBase = commit(directory);
  assert.deepEqual(run(directory, advancedBase, head).scans, javascript);
});

test('deletions and both rename paths retain their language coverage', () => {
  for (const [oldPath, newPath, expected] of [
    ['sources/panepeek/Old.swift', null, swift],
    ['website/old.js', null, javascript],
    ['website/old.js', 'docs/retired.md', javascript],
    ['docs/example.md', 'sources/panepeek/New.swift', swift],
  ]) {
    const { directory, base } = fixture([oldPath]);
    if (newPath) {
      mkdirSync(dirname(join(directory, newPath)), { recursive: true });
      renameSync(join(directory, oldPath), join(directory, newPath));
    } else {
      rmSync(join(directory, oldPath));
    }
    assert.deepEqual(run(directory, base, commit(directory)).scans, expected, oldPath);
  }
});

test('large PRs and filenames containing whitespace are not truncated or split', () => {
  const { directory, base } = fixture();
  for (let index = 0; index < 3100; index += 1) {
    write(directory, `docs/${index}.md`);
  }
  write(directory, 'website/last file\nwith space.ts');
  assert.deepEqual(run(directory, base, commit(directory)).scans, javascript);
});

test('missing or invalid PR history falls back to full scanning', () => {
  const { directory, base } = fixture();
  for (const [baseSHA, headSHA] of [[undefined, undefined], ['--help', base], [base, 'f'.repeat(40)]]) {
    const result = run(directory, baseSHA, headSHA);
    assert.deepEqual(result.scans, all);
    assert.match(result.summary, /Unable to determine/);
  }
});

test('main pushes, weekly schedules and manual runs always select every language', () => {
  const { directory, base } = fixture();
  write(directory, 'docs/usage.md');
  const head = commit(directory);
  for (const event of ['push', 'schedule', 'workflow_dispatch', '']) {
    assert.deepEqual(run(directory, base, head, event).scans, all, event);
  }
});
