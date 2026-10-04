import { readFile, writeFile } from 'node:fs/promises';

const logoUrl = new URL('./peeking-p.svg', import.meta.url);
const iconUrl = new URL('./app-icon-draft.svg', import.meta.url);
const logo = await readFile(logoUrl, 'utf8');
const artwork = logo.slice(logo.indexOf('  <defs>'), logo.lastIndexOf('</svg>'));

const icon = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1254 1254" role="img" aria-labelledby="icon-title icon-description">
  <title id="icon-title">PanePeek app icon draft</title>
  <desc id="icon-description">The reusable peeking-P vector on a dark square background, preserving the accepted concept's scale and placement. Production packaging and platform icon masking remain pending.</desc>
  <defs>
    <radialGradient id="icon-background" cx="52%" cy="48%" r="72%">
      <stop offset="0" stop-color="#24273A"/>
      <stop offset="1" stop-color="#292D3F"/>
    </radialGradient>
  </defs>
  <g id="background"><rect width="1254" height="1254" fill="url(#icon-background)"/></g>
${artwork}</svg>
`;

await writeFile(iconUrl, icon);
console.log('Updated app-icon-draft.svg from peeking-p.svg.');
