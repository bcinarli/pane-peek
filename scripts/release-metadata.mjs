import { readFile } from 'node:fs/promises';

export const prereleaseSuffixKey = 'PanePeekPrereleaseSuffix';

/** Validate the candidate inputs and return the display suffix for a prerelease. */
export function prereleaseSuffix(kind = 'stable', sequence) {
  if (!['stable', 'beta', 'rc'].includes(kind)) {
    throw new Error('Release kind must be stable, beta or rc.');
  }
  if (kind === 'stable') {
    if (sequence !== undefined) { throw new Error('Stable releases do not accept a sequence.'); }
    return undefined;
  }
  if (typeof sequence !== 'string' || sequence.match(/[1-9][0-9]*/)?.[0] !== sequence || !Number.isSafeInteger(Number(sequence))) {
    throw new Error('Prerelease sequence must be a positive safe integer without leading zeros.');
  }
  return `${kind}.${sequence}`;
}

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
