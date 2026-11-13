import { chmod, copyFile } from 'node:fs/promises';
import { join } from 'node:path';

/** Preserve the bundled entry's executable permission in both build paths. */
export async function copyBundledLauncher(projectRoot, resourcesPath) {
  const destination = join(resourcesPath, 'panepeek');
  await copyFile(join(projectRoot, 'assets', 'panepeek'), destination);
  await chmod(destination, 0o755);
}
