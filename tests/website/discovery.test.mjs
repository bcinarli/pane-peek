import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const require = createRequire(new URL('../../scripts/website/package.json', import.meta.url));
const { createDocument } = require('@mixmark-io/domino');
const root = fileURLToPath(new URL('../../', import.meta.url));
const pages = [
  ['index.html', 'https://panepeek.app/'],
  ['support/index.html', 'https://panepeek.app/support/'],
  ['privacy/index.html', 'https://panepeek.app/privacy/'],
];

function fixtureWebsite() {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-website-build-'));
  for (const [file] of pages) {
    mkdirSync(dirname(join(directory, file)), { recursive: true });
    writeFileSync(join(directory, file), readFileSync(join(root, 'website', file)));
  }
  return directory;
}

function build(directory) {
  return spawnSync('npm', ['run', 'build', '--prefix', 'scripts/website', '--', directory], {
    cwd: root, encoding: 'utf8', timeout: 15000,
  });
}

test('each canonical HTML page advertises its Markdown equivalent without changing canonical discovery', () => {
  const index = readFileSync(join(root, 'website/llms.txt'), 'utf8');
  const sitemap = readFileSync(join(root, 'website/sitemap.xml'), 'utf8');
  for (const [file, canonical] of pages) {
    const document = createDocument(readFileSync(join(root, 'website', file), 'utf8'));
    const alternates = document.querySelectorAll('head link[rel="alternate"][type="text/markdown"]');
    assert.equal(alternates.length, 1, file);
    assert.equal(alternates[0].getAttribute('href'), `${canonical}index.md`, file);
    assert.equal(document.querySelector('link[rel="canonical"]').getAttribute('href'), canonical);
    assert.equal(document.querySelector('link[rel="describedby"]').getAttribute('href'), 'https://panepeek.app/llms.txt');
    assert.ok(index.includes(`](${canonical}index.md)`), `${file} Markdown is in llms.txt`);
    assert.ok(index.includes(`](${canonical})`), `${file} HTML remains in llms.txt`);
  }
  assert.deepEqual([...sitemap.matchAll(/<loc>(.*?)<\/loc>/g)].map(match => match[1]), pages.map(([, canonical]) => canonical));
  const missing = createDocument(readFileSync(join(root, 'website/404.html'), 'utf8'));
  assert.equal(missing.querySelectorAll('link[rel="alternate"][type="text/markdown"]').length, 0);
});

test('the publication build generates fresh Markdown and fails for invalid sources or unavailable output', () => {
  const directory = fixtureWebsite();
  const success = build(directory);
  assert.equal(success.status, 0, success.stderr);
  for (const [file, canonical] of pages) {
    const markdown = readFileSync(join(directory, file.replace(/\.html$/, '.md')), 'utf8');
    assert.ok(markdown.includes(`url: "${canonical}"`));
    assert.match(markdown, /^# .+/m);
  }
  writeFileSync(join(directory, 'privacy/index.html'), '<main><h1>Invalid metadata</h1></main>');
  const invalid = build(directory);
  assert.notEqual(invalid.status, 0);
  assert.match(invalid.stderr, /privacy\/index\.html/);
  const blocked = fixtureWebsite();
  mkdirSync(join(blocked, 'privacy/index.md'));
  assert.notEqual(build(blocked).status, 0);
});
