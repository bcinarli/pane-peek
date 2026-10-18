import { readFile } from 'node:fs/promises';

/** Validate the shared release version/build contract without changing metadata. */
export function validateReleaseMetadata(metadata) {
  const version = metadata?.version;
  if (typeof version !== 'string' || version.match(/[0-9]+\.[0-9]+\.[0-9]+/)?.[0] !== version) {
    throw new Error('version.json: version must contain three dot-separated integers, such as 0.1.0.');
  }
  if (!Number.isSafeInteger(metadata.build) || metadata.build < 1) {
    throw new Error('version.json: build must be a positive safe integer.');
  }
  return metadata;
}

/** Read validated metadata from the maintained version file. */
export async function readReleaseMetadata(path) {
  return validateReleaseMetadata(JSON.parse(await readFile(path, 'utf8')));
}
