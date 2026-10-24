import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { convertPageToMarkdown, generateMarkdown } from '../../scripts/website/generate-markdown.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const generator = join(root, 'scripts/website/generate-markdown.mjs');
const canonical = 'https://panepeek.app/support/';
const structuredData = { '@context': 'https://schema.org', '@type': 'WebPage', url: canonical };

function page(url = canonical) {
  return `<!doctype html><html lang="en"><head>
    <title>Help: "files" &amp; folders</title>
    <meta name="description" content="Read, edit &amp; save.">
    <link rel="canonical" href="${url}">
    <script type="application/ld+json">${JSON.stringify(structuredData)}</script>
    </head><body><header>Site navigation</header><main>
    <header><h1>Help with<br><span>PanePeek.</span></h1><p>Last updated 19 October 2026</p></header>
    <nav>On this page navigation</nav><h2>Questions</h2>
    <details><summary>How do I save?</summary><p>Choose Save to keep changes.</p></details>
    <table><thead><tr><th>Action</th><th>Shortcut</th></tr></thead><tbody>
    <tr><th>Go to Folder</th><td><kbd><span aria-hidden="true">⌘ L</span><span class="visually-hidden">Command L</span></kbd></td></tr>
    </tbody></table>
    <p><a href="../privacy/#publisher-title">Privacy<span class="visually-hidden"> (opens in a new tab)</span></a></p>
    <p><a href="mailto:support@panepeek.app">Email support</a></p>
    <figure><img src="../assets/example.webp" alt="Example preview">
    <figcaption><span>File preview.</span><span>Sample files</span></figcaption></figure>
    <pre><code class="language-html">&lt;p&gt;Keep &amp; save&lt;/p&gt;</code></pre>
    <script>unwantedScript()</script><style>.unwanted-style {}</style>
    <button>Theme switch</button><p hidden>Hidden content</p>
    </main><footer>Site footer</footer></body></html>`;
}

function metadata(markdown) {
  const frontmatter = markdown.match(/^---\n([\s\S]*?)\n---\n/);
  assert.ok(frontmatter, 'YAML frontmatter is present');
  return Object.fromEntries(frontmatter[1].split('\n').map(line => {
    const separator = line.indexOf(': ');
    return [line.slice(0, separator), JSON.parse(line.slice(separator + 2))];
  }));
}

function jsonLd(markdown) {
  const block = markdown.match(/```json\n([\s\S]*?)\n```\n$/);
  assert.ok(block, 'structured data ends the document');
  return JSON.parse(block[1]);
}

function fixtureWebsite() {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-markdown-'));
  for (const [file, url] of [
    ['index.html', 'https://panepeek.app/'],
    ['support/index.html', canonical],
    ['privacy/index.html', 'https://panepeek.app/privacy/']
  ]) {
    mkdirSync(dirname(join(directory, file)), { recursive: true });
    writeFileSync(join(directory, file), page(url));
  }
  return directory;
}

test('preserves content headers, closed FAQ answers, readable shortcuts and code without page chrome', () => {
  const markdown = convertPageToMarkdown(page(), canonical);
  assert.match(markdown, /^# Help with PanePeek\.$/m);
  assert.match(markdown, /Last updated 19 October 2026/);
  assert.match(markdown, /### How do I save\?/);
  assert.match(markdown, /Choose Save to keep changes\./);
  assert.match(markdown, /\| Go to Folder \| Command L \|/);
  assert.match(markdown, /File preview\. Sample files/);
  assert.match(markdown, /```html\n<p>Keep & save<\/p>\n```/);
  assert.doesNotMatch(markdown, /Site navigation|On this page navigation|Site footer|unwantedScript|unwanted-style|Theme switch|Hidden content|opens in a new tab|⌘ L/);
});

test('resolves content links and images while preserving email destinations', () => {
  const markdown = convertPageToMarkdown(page(), canonical);
  assert.match(markdown, /\[Privacy\]\(https:\/\/panepeek\.app\/privacy\/#publisher-title\)/);
  assert.match(markdown, /!\[Example preview\]\(https:\/\/panepeek\.app\/assets\/example\.webp\)/);
  assert.match(markdown, /\[Email support\]\(mailto:support@panepeek\.app\)/);
});

test('writes source metadata with safe YAML quoting and preserves every JSON-LD block', () => {
  const html = page().replace('</head>', '<script type="application/ld+json">{"@type":"SoftwareApplication"}</script></head>');
  const markdown = convertPageToMarkdown(html, canonical);
  assert.deepEqual(metadata(markdown), {
    title: 'Help: "files" & folders',
    description: 'Read, edit & save.',
    url: canonical
  });
  assert.deepEqual(jsonLd(markdown), [structuredData, { '@type': 'SoftwareApplication' }]);
  assert.equal(markdown, convertPageToMarkdown(html, canonical));
});

test('rejects absent required content, metadata, canonical mismatches and malformed structured data', () => {
  for (const html of [
    page().replace(/<main>[\s\S]*?<\/main>/, ''),
    page().replace(/<h1>[\s\S]*?<\/h1>/, ''),
    page().replace(/<h1>[\s\S]*?<\/h1>/, '<h1> </h1>'),
    page().replace(/<title>[\s\S]*?<\/title>/, ''),
    page().replace(/<meta name="description"[^>]+>/, ''),
    page().replace(/<link rel="canonical"[^>]+>/, ''),
    page().replace('rel="canonical" href="https://panepeek.app/support/"', 'rel="canonical" href="https://panepeek.app/"'),
    page().replace(/<script type="application\/ld\+json">[\s\S]*?<\/script>/, ''),
    page().replace(JSON.stringify(structuredData), '{invalid JSON}')
  ]) {
    assert.throws(() => convertPageToMarkdown(html, canonical));
  }
});

test('generates only the three mapped outputs reproducibly without changing HTML', () => {
  const directory = fixtureWebsite();
  const original = readFileSync(join(directory, 'index.html'), 'utf8');
  generateMarkdown(directory);
  const outputs = ['index.md', 'support/index.md', 'privacy/index.md'];
  const first = outputs.map(file => readFileSync(join(directory, file), 'utf8'));
  generateMarkdown(directory);
  assert.deepEqual(outputs.map(file => readFileSync(join(directory, file), 'utf8')), first);
  assert.equal(readFileSync(join(directory, 'index.html'), 'utf8'), original);
  assert.deepEqual(readdirSync(directory).sort(), ['index.html', 'index.md', 'privacy', 'support']);
});

test('validates every source before replacing any existing generated document', () => {
  const directory = fixtureWebsite();
  writeFileSync(join(directory, 'index.md'), 'Previous generated document\n');
  writeFileSync(join(directory, 'privacy/index.html'), '<html><body>Missing required content</body></html>');
  assert.throws(() => generateMarkdown(directory));
  assert.equal(readFileSync(join(directory, 'index.md'), 'utf8'), 'Previous generated document\n');
  assert.ok(!readdirSync(join(directory, 'support')).includes('index.md'));
});

test('the command generates documents and returns failure for an invalid source', () => {
  const directory = fixtureWebsite();
  const result = spawnSync(process.execPath, [generator, directory], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.ok(readFileSync(join(directory, 'support/index.md'), 'utf8').startsWith('---\n'));
  writeFileSync(join(directory, 'privacy/index.html'), '<html><body>Invalid source</body></html>');
  const failure = spawnSync(process.execPath, [generator, directory], { encoding: 'utf8' });
  assert.notEqual(failure.status, 0);
  assert.match(failure.stderr, /privacy\/index\.html/);
});

test('homepage shortcuts keep each action paired with its key in a Markdown table', () => {
  const source = readFileSync(join(root, 'website/index.html'), 'utf8');
  const markdown = convertPageToMarkdown(source, 'https://panepeek.app/');
  assert.ok(markdown.includes('| Action | Shortcut |\n| --- | --- |'), 'Shortcuts have a two-column table header');
  for (const [action, shortcut] of [
    ['Go to Folder', 'Command L'],
    ['Quick Look', 'Space'],
    ['New Text File', 'Option Command N'],
    ['Copy absolute paths', 'Option Command C'],
    ['Show hidden files', 'Shift Command full stop'],
    ['Resize Details', 'Control Command Left arrow or Control Command Right arrow']
  ]) {
    assert.ok(markdown.includes(`| ${action} | ${shortcut} |`), `${action} stays paired with its shortcut`);
  }
});

test('the current website retains its product, support and privacy content and structured data', () => {
  const pages = [
    ['index.html', 'https://panepeek.app/', /# Edit text files as you browse\./, /You can drag files between PanePeek and Finder/],
    ['support/index.html', canonical, /# Help with PanePeek\./, /Copy relative paths \| Shift Option Command C/],
    ['privacy/index.html', 'https://panepeek.app/privacy/', /# Your privacy in PanePeek\./, /Support emails and attachments are deleted three months after receipt/]
  ];
  for (const [file, url, heading, content] of pages) {
    const source = readFileSync(join(root, 'website', file), 'utf8');
    const markdown = convertPageToMarkdown(source, url);
    assert.match(markdown, heading);
    assert.match(markdown, content);
    assert.equal(metadata(markdown).url, url);
    assert.deepEqual(jsonLd(markdown), JSON.parse(source.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)[1]));
  }
});
