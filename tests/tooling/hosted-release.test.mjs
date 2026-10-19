import assert from 'node:assert/strict';
import { appendFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, test } from 'node:test';
import { buildHostedRelease, cleanupHostedSigning } from '../../scripts/hosted-release.mjs';

const directories = [];
afterEach(() => {
  for (const directory of directories.splice(0)) { rmSync(directory, { recursive: true, force: true }); }
});
const secretNames = ['RELEASE_CERTIFICATE_BASE64', 'RELEASE_CERTIFICATE_PASSWORD', 'RELEASE_SIGNING_IDENTITY', 'RELEASE_APPLE_ID', 'RELEASE_TEAM_ID', 'RELEASE_NOTARY_PASSWORD'];
const output = 'package_directory=review\narchive=review.zip\nchecksum=review.zip.sha256\nversion=1.0.0\nbuild=5\n';
function fixture() {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-hosted-release-'));
  directories.push(directory);
  const env = {
    GITHUB_ACTIONS: 'true', RUNNER_OS: 'macOS', RUNNER_ENVIRONMENT: 'github-hosted', GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_REF: 'refs/heads/main',
    RUNNER_TEMP: directory, GITHUB_OUTPUT: join(directory, 'outputs'), RELEASE_COMMIT: 'b'.repeat(40),
    RELEASE_CERTIFICATE_BASE64: Buffer.from('synthetic certificate fixture').toString('base64'), RELEASE_CERTIFICATE_PASSWORD: 'fixture-certificate-password',
    RELEASE_SIGNING_IDENTITY: 'A'.repeat(40), RELEASE_APPLE_ID: 'release@example.invalid', RELEASE_TEAM_ID: 'T'.repeat(10), RELEASE_NOTARY_PASSWORD: 'fixture-notary-password',
  };
  writeFileSync(env.GITHUB_OUTPUT, 'earlier=value\n');
  const calls = [];
  const source = { directory, env, calls, searchList: ['/original/login.keychain-db'], fail: '' };
  source.options = {
    env,
    verifyIdentity(identity, keychain) {
      calls.push('verify identity');
      assert.equal(identity, env.RELEASE_SIGNING_IDENTITY);
      assert.ok(existsSync(keychain));
      if (source.fail === 'verify identity') { throw new Error(env.RELEASE_CERTIFICATE_PASSWORD); }
    },
    run(command, args, options = {}) {
      const action = command === 'git' ? 'source' : command.endsWith('node') ? 'build' : command === 'xcrun' ? 'store credentials' : args[0];
      calls.push(action);
      if (source.fail === action) { throw new Error(env.RELEASE_NOTARY_PASSWORD); }
      if (action === 'source') { return env.RELEASE_COMMIT; }
      if (action === 'list-keychains') {
        if (args.includes('-s')) { source.searchList = args.slice(args.indexOf('-s') + 1); }
        return source.searchList.map(path => JSON.stringify(path)).join('\n');
      }
      if (action === 'create-keychain') {
        writeFileSync(args.at(-1), 'synthetic keychain');
        source.searchList.push(args.at(-1));
      }
      if (action === 'import') {
        assert.equal(statSync(args[1]).mode & 0o777, 0o600);
        assert.equal(readFileSync(args[1], 'utf8'), 'synthetic certificate fixture');
      }
      if (action === 'build') {
        for (const name of secretNames) { assert.equal(options.env[name], undefined); }
        assert.ok(args.includes('--notarize') && args.includes('--sign'));
        assert.equal(options.env.PANEPEEK_NOTARY_KEYCHAIN, join(directory, 'panepeek-release-signing/signing.keychain-db'));
        assert.equal(readFileSync(env.GITHUB_OUTPUT, 'utf8'), 'earlier=value\n');
        appendFileSync(options.env.GITHUB_OUTPUT, output);
      }
      if (action === 'delete-keychain') {
        unlinkSync(args.at(-1));
        source.searchList = source.searchList.filter(path => path !== args.at(-1));
      }
      return '';
    },
  };
  return source;
}

test('credentials are temporary, child builds receive no secret values, and outputs follow cleanup', async () => {
  const source = fixture();
  await buildHostedRelease(source.options);
  assert.ok(source.calls.includes('store credentials') && source.calls.includes('verify identity'));
  assert.ok(source.calls.indexOf('build') < source.calls.indexOf('delete-keychain'));
  assert.deepEqual(source.searchList, ['/original/login.keychain-db']);
  assert.deepEqual(readdirSync(source.directory), ['outputs']);
  assert.equal(readFileSync(source.env.GITHUB_OUTPUT, 'utf8'), 'earlier=value\n' + output);
});

test('non-hosted, PR, non-main and missing or invalid credentials fail before credential mutation', async () => {
  for (const change of [{ GITHUB_EVENT_NAME: 'pull_request' }, { GITHUB_REF: 'refs/heads/topic' }, { RUNNER_ENVIRONMENT: 'self-hosted' }, { GITHUB_ACTIONS: 'false' }, { RELEASE_CERTIFICATE_BASE64: 'invalid!' }, { RELEASE_TEAM_ID: '--help' }, { RELEASE_SIGNING_IDENTITY: 'name' }, ...secretNames.map(name => ({ [name]: '' }))]) {
    const source = fixture(); Object.assign(source.env, change);
    await assert.rejects(buildHostedRelease(source.options));
    assert.ok(!source.calls.includes('create-keychain'));
    assert.deepEqual(readdirSync(source.directory), ['outputs']);
  }
});

test('source mismatch is rejected before importing any signing material', async () => {
  const source = fixture(); const run = source.options.run;
  source.options.run = (command, args, options) => command === 'git' ? 'c'.repeat(40) : run(command, args, options);
  await assert.rejects(buildHostedRelease(source.options), /source|commit/i);
  assert.ok(!source.calls.includes('create-keychain'));
});

test('setup, signing and notarisation errors are redacted and always clean their credentials', async () => {
  for (const fail of ['create-keychain', 'import', 'verify identity', 'store credentials', 'build']) {
    const source = fixture(); source.fail = fail;
    await assert.rejects(buildHostedRelease(source.options), error => {
      assert.ok(!error.message.includes(source.env.RELEASE_NOTARY_PASSWORD) && !error.message.includes(source.env.RELEASE_CERTIFICATE_PASSWORD));
      return true;
    });
    assert.deepEqual(source.searchList, ['/original/login.keychain-db']);
    assert.deepEqual(readdirSync(source.directory), ['outputs']);
    assert.equal(readFileSync(source.env.GITHUB_OUTPUT, 'utf8'), 'earlier=value\n');
  }
});

test('failed cleanup withholds outputs and a later cleanup can finish after cancellation or failure', async () => {
  const source = fixture(); source.fail = 'delete-keychain';
  await assert.rejects(buildHostedRelease(source.options));
  assert.equal(readFileSync(source.env.GITHUB_OUTPUT, 'utf8'), 'earlier=value\n');
  assert.ok(!existsSync(join(source.directory, 'panepeek-release-signing/certificate.p12')));
  source.fail = '';
  await cleanupHostedSigning(source.options);
  await cleanupHostedSigning(source.options);
  assert.deepEqual(readdirSync(source.directory), ['outputs']);
  assert.deepEqual(source.searchList, ['/original/login.keychain-db']);
});

test('a pre-existing unowned credential directory is preserved', async () => {
  const source = fixture(); const directory = join(source.directory, 'panepeek-release-signing');
  mkdirSync(directory); writeFileSync(join(directory, 'keep.txt'), 'owned by another operation');
  await assert.rejects(buildHostedRelease(source.options));
  await assert.rejects(cleanupHostedSigning(source.options));
  assert.equal(readFileSync(join(directory, 'keep.txt'), 'utf8'), 'owned by another operation');
  assert.ok(!source.calls.includes('create-keychain'));
});
