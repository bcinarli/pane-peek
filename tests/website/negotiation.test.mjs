import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import worker from '../../website/_worker.js';

const pages = ['/', '/support/', '/privacy/'];
const policy = "default-src 'self'; object-src 'none'";

function assets(overrides = {}) {
  const calls = [];
  return {
    calls,
    async fetch(request) {
      calls.push(request);
      const path = new URL(request.url).pathname;
      if (overrides.fetch) {
        return overrides.fetch(request);
      }
      const markdown = path.endsWith('.md');
      return new Response(markdown ? '# Markdown' : '<h1>HTML</h1>', {
        headers: {
          'Content-Type': markdown ? 'text/markdown' : 'text/html; charset=utf-8',
          'Content-Security-Policy': policy,
          'X-Frame-Options': 'DENY',
          Vary: 'Accept-Encoding',
          ETag: markdown ? '"markdown"' : '"html"',
          'Cache-Control': 'public, max-age=14400',
          ...overrides.headers,
        },
      });
    },
  };
}

function request(path = '/', accept, options = {}) {
  const headers = new Headers(options.headers);
  if (accept !== undefined) {
    headers.set('Accept', accept);
  }
  return new Request(`https://panepeek.app${path}`, { ...options, headers });
}

test('selects a mapped Markdown asset for each canonical page', async () => {
  for (const page of pages) {
    const binding = assets();
    const response = await worker.fetch(request(`${page}?from=agent`, 'text/markdown'), { ASSETS: binding });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('Content-Type'), 'text/markdown; charset=utf-8');
    assert.equal(await response.text(), '# Markdown');
    assert.equal(new URL(binding.calls[0].url).pathname, `${page}index.md`);
  }
});

test('honours explicit preferences, quality and specificity while defaulting to HTML', async () => {
  const cases = [
    [undefined, false], ['', false], ['*/*', false], ['text/*', false],
    ['application/json', false],
    ['text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8', false],
    ['text/markdown', true], ['TEXT/MARKDOWN; Q=0.8, text/html;q=0.7', true],
    ['text/html, text/markdown', true], ['text/markdown, text/html', true],
    ['text/markdown;q=0.8, text/html;q=0.9', false],
    ['text/markdown;q=0.9, text/html;q=0.8', true],
    ['text/markdown;q=0, */*;q=1', false],
    ['text/markdown;q=0.5, text/*;q=0.9', false],
    ['text/markdown;q=0.5, text/html;q=0.2, text/*;q=1', true],
    ['text/markdown; charset="UTF-8";q=0.9, text/html;q=0.8', true],
    ['text/markdown;charset=utf-8;q=0, text/markdown;q=1', false],
    ['text/markdown; variant=unknown', false],
    ['text/markdown; charset=iso-8859-1', false],
    ['application/json; note="x, text/markdown"', false],
    ['text/markdown;q=invalid', false], ['text/markdown;q=1.1', false],
    ['text/markdown;q=0.1234', false], ['text/markdown;q=0;q=1', false],
  ];
  for (const [accept, markdown] of cases) {
    const response = await worker.fetch(request('/', accept), { ASSETS: assets() });
    assert.equal(await response.text(), markdown ? '# Markdown' : '<h1>HTML</h1>', String(accept));
  }
});

test('keeps security policy and varies both representations without shared caching', async () => {
  for (const accept of ['text/html', 'text/markdown', 'text/html', 'text/markdown']) {
    const response = await worker.fetch(request('/', accept), { ASSETS: assets() });
    assert.equal(response.headers.get('Content-Security-Policy'), policy);
    assert.equal(response.headers.get('X-Frame-Options'), 'DENY');
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
    assert.deepEqual(response.headers.get('Vary').toLowerCase().split(/,\s*/).sort(), ['accept', 'accept-encoding']);
    assert.equal(response.headers.get('ETag'), accept === 'text/markdown' ? '"markdown"' : '"html"');
  }
  for (const vary of ['accept, Origin', '*']) {
    const response = await worker.fetch(request('/', 'text/markdown'), { ASSETS: assets({ headers: { Vary: vary } }) });
    assert.equal(response.headers.get('Vary'), vary);
  }
});

test('HEAD selects the GET headers and never returns a body', async () => {
  for (const accept of ['text/html', 'text/markdown']) {
    const get = await worker.fetch(request('/', accept), { ASSETS: assets() });
    const head = await worker.fetch(request('/', accept, { method: 'HEAD' }), { ASSETS: assets() });
    assert.deepEqual([...head.headers], [...get.headers]);
    assert.equal(head.body, null);
    assert.equal(await head.text(), '');
  }
});

test('missing, failed or HTML-fallback Markdown assets retain correctly labelled HTML', async () => {
  for (const failure of ['missing', 'error', 'html']) {
    const binding = assets({ fetch: (assetRequest) => {
      if (new URL(assetRequest.url).pathname.endsWith('.md')) {
        if (failure === 'error') {
          throw new Error('Asset unavailable');
        }
        return new Response('<h1>Fallback</h1>', {
          status: failure === 'missing' ? 404 : 200,
          headers: { 'Content-Type': 'text/html' },
        });
      }
      return new Response('<h1>HTML</h1>', { headers: { 'Content-Type': 'text/html' } });
    } });
    const response = await worker.fetch(request('/support/', 'text/markdown'), { ASSETS: binding });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('Content-Type'), 'text/html');
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
    assert.equal(await response.text(), '<h1>HTML</h1>');
  }
});

test('aliases, static assets, unknown routes and other methods pass through unchanged', async () => {
  for (const [path, method] of [
    ['/index.html?x=1', 'GET'], ['/support?x=1', 'GET'], ['/privacy/index.html?x=1', 'GET'],
    ['/support/index.md', 'GET'], ['/assets/styles.css', 'GET'], ['/missing/', 'GET'],
    ['/', 'POST'], ['/privacy/', 'OPTIONS'],
  ]) {
    const original = request(path, 'text/markdown', { method });
    const response = new Response(null, { status: 301, headers: { Location: '/support/?x=1' } });
    const binding = assets({ fetch: () => response });
    assert.equal(await worker.fetch(original, { ASSETS: binding }), response);
    assert.equal(binding.calls[0], original);
  }
});

test('negotiation retrieves a full selected representation independently of client validators or ranges', async () => {
  const binding = assets();
  const response = await worker.fetch(request('/', 'text/markdown', { headers: {
    'If-None-Match': '"html"', 'If-Modified-Since': 'Wed, 21 Oct 2026 07:28:00 GMT',
    'If-Match': '"html"', 'If-Unmodified-Since': 'Wed, 21 Oct 2026 07:28:00 GMT',
    Range: 'bytes=0-1', 'If-Range': '"html"',
  } }), { ASSETS: binding });
  for (const header of ['If-None-Match', 'If-Modified-Since', 'If-Match', 'If-Unmodified-Since', 'Range', 'If-Range']) {
    assert.equal(binding.calls[0].headers.has(header), false, header);
  }
  assert.equal(response.status, 200);
  assert.equal(await response.text(), '# Markdown');
});

test('the invocation allowlist covers only the three canonical content paths', async () => {
  const routes = JSON.parse(await readFile(new URL('../../website/_routes.json', import.meta.url), 'utf8'));
  assert.equal(routes.version, 1);
  assert.deepEqual([...routes.include].sort(), [...pages].sort());
  assert.deepEqual(routes.exclude, []);
});
