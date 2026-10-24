import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

async function pagesPreview(context) {
  if (process.env.PANEPEEK_PAGES_URL) {
    return process.env.PANEPEEK_PAGES_URL;
  }
  const root = fileURLToPath(new URL('../../', import.meta.url));
  const server = spawn(`${root}scripts/website/node_modules/.bin/wrangler`, [
    'pages', 'dev', 'website', '--ip', '127.0.0.1', '--port', '0', '--inspector-port', '0',
    '--compatibility-date', '2026-10-24', '--persist-to', '.build/website-pages-state',
  ], { cwd: root, env: { ...process.env, WRANGLER_SEND_METRICS: 'false' }, stdio: ['ignore', 'pipe', 'pipe'] });
  context.after(async () => {
    if (server.exitCode === null && server.signalCode === null) {
      const stopped = once(server, 'close');
      server.kill('SIGTERM');
      await stopped;
    }
  });
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Local Pages startup timed out')), 30000);
    context.after(() => clearTimeout(timeout));
    const ready = chunk => {
      const match = /Ready on (http:\/\/127\.0\.0\.1:\d+)/.exec(chunk.toString());
      if (match) {
        clearTimeout(timeout);
        resolve(match[1]);
      }
    };
    server.stdout.on('data', ready);
    server.stderr.on('data', ready);
    server.once('error', reject);
    server.once('exit', code => {
      clearTimeout(timeout);
      reject(new Error(`Local Pages exited with code ${code}`));
    });
  });
}

test('Pages serves negotiated content while preserving static routing and security', { timeout: 60000 }, async context => {
  const baseUrl = await pagesPreview(context);
  const policy = await readFile(new URL('../../website/_headers', import.meta.url), 'utf8');
  const csp = /Content-Security-Policy: (.+)/.exec(policy)[1];
  for (const path of ['/', '/support/', '/privacy/']) {
    for (const accept of ['text/html', 'text/markdown', '*/*', 'text/markdown;q=0, text/html', 'text/markdown']) {
      const markdown = accept === 'text/markdown';
      const headers = { Accept: accept, 'Accept-Encoding': 'identity' };
      const response = await fetch(new URL(`${path}?review=1`, baseUrl), { headers });
      const source = await readFile(new URL(`../../website${path}index.${markdown ? 'md' : 'html'}`, import.meta.url), 'utf8');
      assert.equal(response.status, 200);
      assert.equal(await response.text(), source);
      assert.equal(response.headers.get('Content-Type'), `${markdown ? 'text/markdown' : 'text/html'}; charset=utf-8`);
      assert.equal(response.headers.get('Cache-Control'), 'no-store');
      assert.match(response.headers.get('Vary'), /\bAccept\b/i);
      assert.equal(response.headers.get('Content-Security-Policy'), csp);
      assert.equal(response.headers.get('X-Frame-Options'), 'DENY');
      if (!markdown) {
        assert.equal(response.headers.get('Link'), `<https://panepeek.app${path}index.md>; rel="alternate"; type="text/markdown"`);
      }
      const head = await fetch(new URL(path, baseUrl), { method: 'HEAD', headers });
      assert.equal(await head.text(), '');
      for (const name of ['Content-Type', 'Cache-Control', 'Vary', 'Content-Security-Policy', 'X-Frame-Options', 'Link', 'ETag', 'Content-Length']) {
        assert.equal(head.headers.get(name), response.headers.get(name), `${path} ${accept} ${name}`);
      }
      const conditional = await fetch(new URL(path, baseUrl), {
        headers: { ...headers, 'If-None-Match': response.headers.get('ETag'), Range: 'bytes=0-1' },
      });
      assert.equal(conditional.status, 200);
      assert.equal(await conditional.text(), source);
    }
  }
  for (const [alias, canonical] of [
    ['/index.html', '/'], ['/support', '/support/'], ['/support/index.html', '/support/'],
    ['/privacy', '/privacy/'], ['/privacy/index.html', '/privacy/'],
  ]) {
    const response = await fetch(new URL(`${alias}?review=1`, baseUrl), {
      redirect: 'manual', headers: { Accept: 'text/markdown' },
    });
    assert.ok([301, 308].includes(response.status), `${alias} ${response.status}`);
    assert.equal(new URL(response.headers.get('Location'), baseUrl).pathname, canonical);
    assert.equal(new URL(response.headers.get('Location'), baseUrl).search, '?review=1');
    assert.doesNotMatch(response.headers.get('Vary') ?? '', /\bAccept\b/i);
  }
  for (const path of ['/index.md', '/support/index.md', '/privacy/index.md', '/robots.txt', '/llms.txt', '/styles.css']) {
    const response = await fetch(new URL(path, baseUrl), { headers: { Accept: 'text/markdown' } });
    assert.equal(response.status, 200, path);
    assert.doesNotMatch(response.headers.get('Vary') ?? '', /\bAccept\b/i, path);
    assert.notEqual(response.headers.get('Cache-Control'), 'no-store', path);
    if (path.endsWith('.md')) {
      assert.equal(response.headers.get('Content-Type'), 'text/markdown; charset=utf-8');
      assert.equal(await response.text(), await readFile(new URL(`../../website${path}`, import.meta.url), 'utf8'));
    }
  }
  const missing = await fetch(new URL('/unknown/nested/path/', baseUrl), { headers: { Accept: 'text/markdown' } });
  assert.equal(missing.status, 404);
  assert.equal(await missing.text(), await readFile(new URL('../../website/404.html', import.meta.url), 'utf8'));
  const post = await fetch(new URL('/', baseUrl), { method: 'POST', headers: { Accept: 'text/markdown' } });
  assert.doesNotMatch(post.headers.get('Vary') ?? '', /\bAccept\b/i);
  assert.doesNotMatch(post.headers.get('Content-Type') ?? '', /text\/markdown/);
});
