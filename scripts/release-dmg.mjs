import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { access, copyFile, lstat, mkdir, mkdtemp, readFile, readdir, readlink, symlink, writeFile } from 'node:fs/promises';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { diskImageLayout } from './dmg-layout.mjs';
import { readReleaseMetadata, validateReleaseMetadata } from './release-metadata.mjs';
import { notariseReleaseDiskImage } from './release-notarisation.mjs';
import { parseBuildArguments, signReleaseDiskImage, validateReleaseIdentity, verifyDiskImageSignature, verifyReleaseSignature } from './release-signing.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));

function runTool(command, args, { env = process.env } = {}) {
  const result = execFileSync(command, args, { env, timeout: 120_000, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  if (args.includes('-plist')) {
    return execFileSync('plutil', ['-convert', 'json', '-o', '-', '-'], { input: result, encoding: 'utf8', timeout: 10_000 });
  }
  return result;
}

/** Mount only for the callback, then detach the device returned by that attachment. */
export async function withMountedDiskImage(imagePath, inspect, { env = process.env, run = runTool, readOnly = true } = {}) {
  const result = JSON.parse(run('hdiutil', ['attach', '-plist', '-nobrowse', '-noautoopen', readOnly ? '-readonly' : '-readwrite', imagePath], { env }));
  const entities = result['system-entities'] ?? [];
  const device = entities.find(entity => /^\/dev\/disk\d+(s\d+)*$/.test(entity['dev-entry']))?.['dev-entry'];
  if (!device) { throw new Error('The disk image returned no owned device to inspect.'); }
  try {
    const volume = entities.find(entity => entity['mount-point'])?.['mount-point'];
    if (!volume) { throw new Error('The attached disk image has no mounted volume.'); }
    return await inspect(volume);
  } finally {
    run('hdiutil', ['detach', device], { env });
  }
}

/** Verify the read-only volume and its unchanged app before making it a release asset. */
export async function verifyReleaseDiskImage(imagePath, bundlePath, { env = process.env, identity, notarised = false, run = runTool } = {}) {
  run('hdiutil', ['verify', imagePath], { env });
  const information = JSON.parse(run('hdiutil', ['imageinfo', '-plist', imagePath], { env }));
  if (information.Format !== 'UDZO') { throw new Error('The DMG must be a compressed read-only UDZO image.'); }
  if (identity) { verifyDiskImageSignature(imagePath, identity); }
  await withMountedDiskImage(imagePath, async volume => {
    const names = await readdir(volume);
    for (const name of ['PanePeek.app', 'Applications', '.DS_Store', '.background', '.VolumeIcon.icns']) {
      if (!names.includes(name)) { throw new Error(`The DMG is missing ${name}.`); }
    }
    if (names.some(name => !['PanePeek.app', 'Applications', '.DS_Store', '.background', '.VolumeIcon.icns', '.fseventsd', '.Trashes', '.Spotlight-V100'].includes(name))) {
      throw new Error('The DMG contains unexpected files.');
    }
    for (const name of ['PanePeek.app', '.background']) {
      if (!(await lstat(join(volume, name))).isDirectory()) { throw new Error(`The DMG ${name} must be an embedded directory.`); }
    }
    for (const name of ['.DS_Store', '.VolumeIcon.icns', '.background/installer.tiff']) {
      if (!(await lstat(join(volume, name))).isFile()) { throw new Error(`The DMG ${name} must be an embedded file.`); }
    }
    if (await readlink(join(volume, 'Applications')) !== '/Applications') { throw new Error('The Applications shortcut has an unexpected destination.'); }
    const packaged = join(volume, 'PanePeek.app');
    run('diff', ['-rq', bundlePath, packaged], { env });
    await access(join(packaged, 'Contents/MacOS/PanePeek'), 1);
    const store = await readFile(join(volume, '.DS_Store'));
    const marker = store.indexOf(Buffer.from('pBBkblob'));
    if (marker < 0 || marker + 12 > store.length) { throw new Error('The DMG background bookmark is missing.'); }
    const bookmark = store.subarray(marker + 12, marker + 12 + store.readUInt32BE(marker + 8));
    if (!store.equals(diskImageLayout(bookmark))) { throw new Error('The DMG Finder layout differs from the release layout.'); }
    run('xcrun', ['swift', join(root, 'scripts/dmg-artwork.swift'), 'verify', volume, join(volume, '.background/installer.tiff')], { env });
    if (identity) { verifyReleaseSignature(packaged, identity); }
    if (notarised) {
      run('xcrun', ['stapler', 'validate', packaged], { env });
      run('/usr/sbin/spctl', ['--assess', '--type', 'execute', packaged], { env });
    }
  }, { env, run });
  if (notarised) {
    run('xcrun', ['stapler', 'validate', imagePath], { env });
    run('/usr/sbin/spctl', ['--assess', '--type', 'open', '--context', 'context:primary-signature', imagePath], { env });
  }
}

/** Build the Finder presentation once, then sign/notarise and verify both container and app. */
export async function buildReleaseDiskImage(bundlePath, metadata, { env = process.env, identity, notaryProfile } = {}) {
  const { version, build } = validateReleaseMetadata(metadata);
  if (identity) { validateReleaseIdentity(identity); verifyReleaseSignature(bundlePath, identity); }
  const directory = dirname(bundlePath);
  const imagePath = join(directory, `PanePeek-${version}-build${build}-macos-arm64.dmg`);
  let existing = false;
  try { existing = (await lstat(imagePath)).isFile(); } catch (error) { if (error.code !== 'ENOENT') { throw error; } }
  if (!existing) {
    const staging = await mkdtemp(join(directory, '.dmg-layout-'));
    await mkdir(join(staging, '.background'));
    runTool('ditto', [bundlePath, join(staging, 'PanePeek.app')], { env });
    await symlink('/Applications', join(staging, 'Applications'));
    await copyFile(join(root, 'assets/PanePeek.icns'), join(staging, '.VolumeIcon.icns'));
    runTool('xcrun', ['swift', join(root, 'scripts/dmg-artwork.swift'), 'render', join(root, 'assets/dmg/background.svg'), join(staging, '.background/installer.tiff')], { env });
    const writable = join(directory, `${basename(staging)}.dmg`);
    runTool('hdiutil', ['create', '-fs', 'HFS+', '-format', 'UDRW', '-volname', 'PanePeek', '-srcfolder', staging, writable], { env });
    await withMountedDiskImage(writable, async volume => {
      const bookmarkPath = join(staging, 'background.bookmark');
      runTool('xcrun', ['swift', join(root, 'scripts/dmg-artwork.swift'), 'bookmark', volume, bookmarkPath], { env });
      await writeFile(join(volume, '.DS_Store'), diskImageLayout(await readFile(bookmarkPath)));
      runTool('xcrun', ['SetFile', '-a', 'C', volume], { env });
    }, { env, readOnly: false });
    runTool('hdiutil', ['convert', writable, '-format', 'UDZO', '-o', imagePath], { env });
    if (identity) { signReleaseDiskImage(imagePath, identity); }
  }
  await verifyReleaseDiskImage(imagePath, bundlePath, { env, identity });
  if (notaryProfile) {
    await notariseReleaseDiskImage(imagePath, identity, notaryProfile, {
      env, finalise: () => verifyReleaseDiskImage(imagePath, bundlePath, { env, identity, notarised: true }),
    });
  }
  const checksum = createHash('sha256').update(await readFile(imagePath)).digest('hex');
  await writeFile(`${imagePath}.sha256`, `${checksum}  ${basename(imagePath)}\n`);
  return { diskImage: imagePath, diskImageChecksum: `${imagePath}.sha256` };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  (async () => {
    const directory = resolve(process.argv[2] || '.');
    if (/[\r\n]/.test(directory)) { throw new Error('The package path must not contain line breaks.'); }
    const { identity, notaryProfile } = parseBuildArguments(['--release', ...process.argv.slice(3)]);
    const metadata = await readReleaseMetadata(join(root, 'version.json'));
    const bundlePath = join(directory, 'PanePeek.app');
    const plist = JSON.parse(runTool('plutil', ['-convert', 'json', '-o', '-', join(bundlePath, 'Contents/Info.plist')]));
    if (plist.CFBundleShortVersionString !== metadata.version || plist.CFBundleVersion !== String(metadata.build)) {
      throw new Error('The DMG app metadata differs from version.json.');
    }
    const result = await buildReleaseDiskImage(bundlePath, metadata, { identity, notaryProfile });
    console.log(`Disk image: ${result.diskImage}\nChecksum: ${result.diskImageChecksum}`);
  })().catch(error => { console.error(`DMG packaging failed: ${error.message}`); process.exitCode = 1; });
}
