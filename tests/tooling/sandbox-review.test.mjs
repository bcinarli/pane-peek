import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseBuildArguments } from '../../scripts/release-signing.mjs';

test('sandbox review keeps its own build mode and accepts an explicit stable signing identity', () => {
  assert.deepEqual(parseBuildArguments(['--sandbox-review']), { release: false, sandboxReview: true });
  assert.deepEqual(parseBuildArguments(['--sandbox-review', '--sign', 'a'.repeat(40)]), {
    release: false, sandboxReview: true, identity: 'A'.repeat(40),
  });
  assert.deepEqual(parseBuildArguments([]), { release: false });
  assert.deepEqual(parseBuildArguments(['--release']), { release: true });
  for (const args of [
    ['--sandbox-review', '--release'], ['--release', '--sandbox-review'],
    ['--sandbox-review', '--sign'], ['--sandbox-review', '--notarize', 'profile'],
    ['--sandbox-review', '--sign', 'a'.repeat(40), '--notarize', 'profile'],
    ['--sandbox-review', '--sign', 'a'.repeat(40), '--sign', 'b'.repeat(40)],
  ]) { assert.throws(() => parseBuildArguments(args), /Usage:/); }
});

test('review signing rejects names, ad hoc signing and malformed fingerprints', () => {
  for (const identity of ['-', 'Apple Development', 'a'.repeat(39), 'a'.repeat(41), 'g'.repeat(40), 'a'.repeat(40) + '\n']) {
    assert.throws(() => parseBuildArguments(['--sandbox-review', '--sign', identity]), /40-character SHA-1/);
  }
});
