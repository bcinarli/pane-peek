import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { appendFile, readFile, writeFile } from 'node:fs/promises';
import { basename, dirname, join } from 'node:path';
import { buildReleaseDiskImage } from './release-dmg.mjs';
import { validateReleaseMetadata } from './release-metadata.mjs';

/** Package the final bundle, then expose its checksum and workflow outputs. */
export async function packageReleaseBundle(bundlePath, metadata, { env = process.env, identity, notaryProfile, buildDiskImage = buildReleaseDiskImage, run = execFileSync } = {}) {
  const { version, build } = validateReleaseMetadata(metadata);
  const { diskImage, diskImageChecksum } = await buildDiskImage(bundlePath, metadata, { env, identity, notaryProfile });
  const archivePath = join(dirname(bundlePath), `PanePeek-${version}-build${build}-macos-arm64.zip`);
  run('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', bundlePath, archivePath], { env });
  const checksum = createHash('sha256').update(await readFile(archivePath)).digest('hex');
  await writeFile(`${archivePath}.sha256`, `${checksum}  ${basename(archivePath)}\n`);
  console.log(`Package: ${archivePath}\nChecksum: ${archivePath}.sha256`);
  if (env.GITHUB_OUTPUT) {
    await appendFile(env.GITHUB_OUTPUT,
      `package_directory=${dirname(bundlePath)}\narchive=${archivePath}\nchecksum=${archivePath}.sha256\ndisk_image=${diskImage}\ndisk_image_checksum=${diskImageChecksum}\nversion=${version}\nbuild=${build}\n`);
  }
}
