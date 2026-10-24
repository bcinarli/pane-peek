import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import domino from '@mixmark-io/domino';
import TurndownService from 'turndown';
import { tables } from 'turndown-plugin-gfm';

const website = fileURLToPath(new URL('../../website/', import.meta.url));
const pages = [
  ['index.html', 'https://panepeek.app/'],
  ['support/index.html', 'https://panepeek.app/support/'],
  ['privacy/index.html', 'https://panepeek.app/privacy/']
];

/** Convert a canonical HTML page without fetching resources or executing scripts. */
export function convertPageToMarkdown(html, canonicalUrl) {
  const document = domino.createDocument(html);
  const metadata = {
    title: document.querySelector('title')?.textContent.trim(),
    description: document.querySelector('meta[name="description"]')?.getAttribute('content')?.trim(),
    url: document.querySelector('link[rel="canonical"]')?.getAttribute('href')
  };
  if (!metadata.title || !metadata.description || metadata.url !== canonicalUrl) {
    throw new Error('Missing title/description or mismatched canonical URL');
  }
  const content = document.querySelectorAll('main');
  if (content.length !== 1 || !content[0].querySelector('h1')?.textContent.trim()) {
    throw new Error('Expected one main element with a page heading');
  }
  const structuredData = Array.from(document.querySelectorAll('script[type="application/ld+json"]'))
    .map(script => JSON.parse(script.textContent));
  if (!structuredData.length) {
    throw new Error('Missing JSON-LD metadata');
  }
  const main = content[0];
  for (const node of Array.from(main.querySelectorAll('script, style, nav, footer, button, select, dialog, [hidden], [aria-hidden="true"], a .visually-hidden'))) {
    node.remove();
  }
  for (const heading of Array.from(main.querySelectorAll('h1, h2, h3, h4, h5, h6'))) {
    for (const br of Array.from(heading.querySelectorAll('br'))) {
      br.replaceWith(document.createTextNode(' '));
    }
  }
  for (const caption of Array.from(main.querySelectorAll('figcaption'))) {
    for (const child of Array.from(caption.children).slice(1)) {
      caption.insertBefore(document.createTextNode(' '), child);
    }
  }
  for (const [selector, attribute] of [['a[href]', 'href'], ['img[src]', 'src']]) {
    for (const node of Array.from(main.querySelectorAll(selector))) {
      node.setAttribute(attribute, new URL(node.getAttribute(attribute), canonicalUrl).href);
    }
  }
  for (const shortcuts of Array.from(main.querySelectorAll('dl.shortcuts'))) {
    const table = document.createElement('table');
    table.innerHTML = '<thead><tr><th>Action</th><th>Shortcut</th></tr></thead><tbody></tbody>';
    const tableBody = table.querySelector('tbody');
    for (const entry of Array.from(shortcuts.children)) {
      const row = document.createElement('tr');
      for (const selector of ['dt', 'dd']) {
        const cell = document.createElement('td');
        cell.innerHTML = entry.querySelector(selector).innerHTML;
        row.appendChild(cell);
      }
      tableBody.appendChild(row);
    }
    shortcuts.replaceWith(table);
  }

  const converter = new TurndownService({ headingStyle: 'atx', codeBlockStyle: 'fenced', bulletListMarker: '-' });
  converter.use(tables);
  converter.addRule('question', {
    filter: 'summary',
    replacement: content => `\n\n### ${content.trim()}\n\n`
  });
  const frontmatter = Object.entries(metadata).map(([key, value]) => `${key}: ${JSON.stringify(value)}`).join('\n');
  const body = converter.turndown(main);
  if (!body.trim()) {
    throw new Error('Main content produced empty Markdown');
  }
  const json = structuredData.length === 1 ? structuredData[0] : structuredData;
  const structuredBlock = `\n\n\`\`\`json\n${JSON.stringify(json, null, 2)}\n\`\`\``;
  return `---\n${frontmatter}\n---\n\n${body}${structuredBlock}\n`;
}

/** Validate all source pages before writing the mapped Markdown files. */
export function generateMarkdown(websiteDirectory = website) {
  const outputs = pages.map(([source, canonicalUrl]) => {
    try {
      const html = readFileSync(join(websiteDirectory, source), 'utf8');
      return [source.replace(/\.html$/, '.md'), convertPageToMarkdown(html, canonicalUrl)];
    } catch (error) {
      throw new Error(`${source}: ${error.message}`);
    }
  });
  for (const [file, markdown] of outputs) {
    writeFileSync(join(websiteDirectory, file), markdown);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if (process.argv.length > 3) {
      throw new Error('Usage: node scripts/website/generate-markdown.mjs [website-directory]');
    }
    generateMarkdown(process.argv[2]);
    console.log('Generated Markdown for Home, Support and Privacy.');
  } catch (error) {
    console.error(`Markdown generation failed: ${error.message}`);
    process.exitCode = 1;
  }
}
