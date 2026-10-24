import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseBuildArguments } from '../../scripts/release-signing.mjs';

test('GitHub updates in review builds require an explicit review-only flag', () => {
  assert.equal(parseBuildArguments(['--sandbox-review']).githubUpdates, undefined);
  assert.equal(parseBuildArguments(['--sandbox-review', '--github-updates']).githubUpdates, true);
  assert.equal(parseBuildArguments(['--sandbox-review', '--sign', 'a'.repeat(40), '--github-updates']).githubUpdates, true);
  for (const args of [['--github-updates'], ['--release', '--github-updates'], ['--sandbox-review', '--github-updates', '--github-updates']]) {
    assert.throws(() => parseBuildArguments(args), /Usage:/);
  }
});
