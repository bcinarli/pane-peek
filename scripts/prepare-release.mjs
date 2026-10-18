import { randomUUID } from 'node:crypto';
import { open, rename, rm, stat, unlink } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readReleaseMetadata, validateReleaseMetadata } from './release-metadata.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const metadataPath = join(root, 'version.json');
const lockPath = `${metadataPath}.lock`;

try {
  const args = process.argv.slice(2);
  if (args.length !== 0 && (args.length !== 2 || args[0] !== '--version')) {
    throw new Error('Usage: node scripts/prepare-release.mjs [--version X.Y.Z]');
  }
  let lock;
  try {
    lock = await open(lockPath, 'wx', 0o600);
  } catch (error) {
    if (error.code === 'EEXIST') {
      throw new Error('A release preparation lock exists. Check for another preparation before removing version.json.lock.');
    }
    throw error;
  }
  const temporaryPath = `${metadataPath}.${randomUUID()}.tmp`;
  try {
    const current = await readReleaseMetadata(metadataPath);
    const next = validateReleaseMetadata({ ...current, version: args[1] ?? current.version, build: current.build + 1 });
    const mode = (await stat(metadataPath)).mode & 0o777;
    const temporary = await open(temporaryPath, 'wx', 0o600);
    try {
      await temporary.chmod(mode);
      await temporary.writeFile(`${JSON.stringify(next, null, 2)}\n`);
      await temporary.sync();
    } finally {
      await temporary.close();
    }
    await rename(temporaryPath, metadataPath);
    console.log(`Prepared ${next.version} (build ${next.build}).`);
    console.log('Build this candidate with node scripts/build-app.mjs --release. Rebuilds reuse this number.');
  } finally {
    await rm(temporaryPath, { force: true });
    await lock.close();
    await unlink(lockPath);
  }
} catch (error) {
  console.error(`Release preparation failed: ${error.message}`);
  process.exitCode = 1;
}
