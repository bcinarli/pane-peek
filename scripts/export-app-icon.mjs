import { execFileSync } from 'node:child_process';
import { copyFile, mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));
const designDirectory = join(projectRoot, 'agent-paper-trail', 'design', '001-mvp');
const outputDirectory = join(projectRoot, '.build', 'app-icon');
const iconsetDirectory = join(outputDirectory, 'PanePeek.iconset');
const rasterPath = join(outputDirectory, 'PanePeek.png');
const assetsDirectory = join(projectRoot, 'assets');
const catalogDirectory = join(assetsDirectory, 'app-icon.xcassets');
const appIconDirectory = join(catalogDirectory, 'AppIcon.appiconset');
const images = [];
const info = { version: 1, author: 'xcode' };

await mkdir(iconsetDirectory, { recursive: true });
await mkdir(appIconDirectory, { recursive: true });
execFileSync(process.execPath, [join(designDirectory, 'export-icon.mjs')], { stdio: 'inherit' });
execFileSync('qlmanage', [
  '-t', '-s', '1024', '-o', outputDirectory, join(designDirectory, 'app-icon-draft.svg'),
], { stdio: 'inherit' });
execFileSync('swift', [
  join(projectRoot, 'scripts', 'render-app-icon.swift'),
  join(outputDirectory, 'app-icon-draft.svg.png'), rasterPath,
], { stdio: 'inherit' });

for (const size of [16, 32, 128, 256, 512]) {
  for (const scale of [1, 2]) {
    const pixels = size * scale;
    const suffix = scale === 2 ? '@2x' : '';
    const filename = `icon_${size}x${size}${suffix}.png`;
    execFileSync('sips', [
      '-z', String(pixels), String(pixels), rasterPath,
      '--out', join(iconsetDirectory, filename),
    ], { stdio: 'ignore' });
    await copyFile(join(iconsetDirectory, filename), join(appIconDirectory, filename));
    images.push({ size: `${size}x${size}`, idiom: 'mac', filename, scale: `${scale}x` });
  }
}

const iconPath = join(assetsDirectory, 'PanePeek.icns');
execFileSync('iconutil', ['-c', 'icns', iconsetDirectory, '-o', iconPath], { stdio: 'inherit' });
console.log(`Exported ${iconPath}`);

await writeFile(join(catalogDirectory, 'Contents.json'), `${JSON.stringify({ info }, null, 2)}\n`);
await writeFile(join(appIconDirectory, 'Contents.json'), `${JSON.stringify({ images, info }, null, 2)}\n`);
