import assert from 'node:assert/strict';
import childProcess from 'node:child_process';
import { X509Certificate } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, before, test } from 'node:test';
import { readStoreProfile } from '../../scripts/app-store-signing.mjs';

const team = 'AB12CD34EF';
const identityName = `Apple Distribution: Fixture (${team})`;
const uuid = '12345678-1234-1234-1234-1234567890AB';
let directory, selected, other;

before(() => {
  directory = mkdtempSync(join(tmpdir(), 'panepeek-store-certificates-'));
  [selected, other] = [0, 1].map(index => {
    const certificate = join(directory, `${index}.pem`);
    childProcess.execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-sha256', '-nodes',
      '-keyout', join(directory, `${index}.key`), '-out', certificate, '-days', '1', '-subj', `/CN=${identityName}`],
    { stdio: 'pipe', timeout: 15_000 });
    return new X509Certificate(readFileSync(certificate));
  });
});

after(() => rmSync(directory, { recursive: true, force: true }));

function mockProfile(t, certificates = [other, selected], extra = {}) {
  const fingerprint = selected.fingerprint.replaceAll(':', '');
  const fields = {
    Entitlements: JSON.stringify({ 'com.apple.application-identifier': `${team}.com.bcinarli.PanePeek` }),
    'DeveloperCertificates.0': selected.raw.toString('base64'),
    UUID: uuid, TeamIdentifier: JSON.stringify([team]), Platform: JSON.stringify(['OSX']),
    ExpirationDate: '2030-01-01T00:00:00Z', ...extra,
  };
  t.mock.method(childProcess, 'execFileSync', (command, args) => {
    if (command === '/usr/bin/security') {
      if (args[0] === 'cms') { return '<plist>fixture</plist>'; }
      if (args[0] === 'find-identity') { return `  1) ${fingerprint} "${identityName}"\n`; }
      if (args[0] === 'find-certificate') {
        assert.deepEqual(args, ['find-certificate', '-a', '-c', identityName, '-p']);
        return certificates.map(value => value.toString()).join('\n');
      }
    }
    if (command === '/usr/bin/plutil' && args[1] in fields) { return fields[args[1]]; }
    throw new Error('Fixture metadata or command unavailable.');
  });
  syncBuiltinESMExports();
  t.after(() => {
    t.mock.restoreAll();
    syncBuiltinESMExports();
  });
  return fingerprint.toLowerCase();
}

test('Store profiles match the complete selected certificate among same-name identities', t => {
  const fingerprint = mockProfile(t);
  const profile = readStoreProfile('fixture.provisionprofile', fingerprint);
  assert.equal(profile.uuid, uuid);
  assert.equal(profile.team, team);
});

test('Store profiles reject a different certificate even when its legacy fingerprint matches', t => {
  const fingerprint = mockProfile(t, [other]);
  t.mock.getter(X509Certificate.prototype, 'fingerprint', () => fingerprint);
  assert.throws(() => readStoreProfile('fixture.provisionprofile', fingerprint), /must match the distribution profile/);
});

test('Store profiles reject a missing local certificate', t => {
  const fingerprint = mockProfile(t, []);
  assert.throws(() => readStoreProfile('fixture.provisionprofile', fingerprint), /certificate/i);
});

test('Store profiles still reject multiple distribution certificates', t => {
  const fingerprint = mockProfile(t, [selected], { 'DeveloperCertificates.1': other.raw.toString('base64') });
  assert.throws(() => readStoreProfile('fixture.provisionprofile', fingerprint), /must match the distribution profile/);
});
