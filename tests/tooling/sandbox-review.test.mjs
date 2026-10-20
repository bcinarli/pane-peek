import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseBuildArguments } from '../../scripts/release-signing.mjs';

test('sandbox review is separate from release signing and notarisation', () => {
  assert.deepEqual(parseBuildArguments(['--sandbox-review']), { release: false, sandboxReview: true });
  assert.deepEqual(parseBuildArguments([]), { release: false });
  assert.deepEqual(parseBuildArguments(['--release']), { release: true });
  for (const args of [
    ['--sandbox-review', '--release'], ['--release', '--sandbox-review'],
    ['--sandbox-review', '--sign', 'a'.repeat(40)], ['--sandbox-review', '--notarize', 'profile'],
  ]) { assert.throws(() => parseBuildArguments(args), /Usage:/); }
});
