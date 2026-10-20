import assert from 'node:assert/strict';
import { test } from 'node:test';
import { storeExportOptions, validateStoreProfile, validateStoreEntitlements, validateStoreInstallerSignature } from '../../scripts/app-store-signing.mjs';
import { parseStoreArguments } from '../../scripts/app-store.mjs';

const team = 'AB12CD34EF';
const entitlements = {
  'com.apple.security.app-sandbox': true,
  'com.apple.security.files.user-selected.read-write': true,
  'com.apple.security.files.bookmarks.app-scope': true,
  'com.apple.security.network.client': true,
  'com.apple.application-identifier': `${team}.com.bcinarli.PanePeek`,
  'com.apple.developer.team-identifier': team,
};

test('Store signing accepts the sandbox capabilities with its exact application and team identity', () => {
  assert.doesNotThrow(() => validateStoreEntitlements(entitlements, team));
});

test('Store signing rejects identity mismatches, missing capabilities and extra access', () => {
  const missing = { ...entitlements };
  delete missing['com.apple.security.files.user-selected.read-write'];
  for (const values of [missing,
    { ...entitlements, 'com.apple.application-identifier': `${team}.other.app` },
    { ...entitlements, 'com.apple.developer.team-identifier': 'OTHERTEAM1' },
    { ...entitlements, 'com.apple.security.get-task-allow': true },
    { ...entitlements, 'com.apple.security.network.client': false },
    { ...entitlements, 'com.apple.security.network.server': true },
  ]) {
    assert.throws(() => validateStoreEntitlements(values, team));
  }
});

const profile = {
  team, uuid: '12345678-1234-1234-1234-1234567890AB',
  applicationIdentifier: `${team}.com.bcinarli.PanePeek`,
  platforms: ['OSX'], expires: '2030-01-01T00:00:00Z', getTaskAllow: false,
};

test('manual export always stays local and retains assigned release metadata', () => {
  const options = storeExportOptions({ ...profile, applicationIdentity: 'A'.repeat(40), installerIdentity: 'B'.repeat(40) });
  assert.equal(options.method, 'app-store-connect');
  assert.equal(options.destination, 'export');
  assert.equal(options.signingStyle, 'manual');
  assert.equal(options.manageAppVersionAndBuildNumber, false);
  assert.equal(options.uploadSymbols, false);
  assert.deepEqual(options.provisioningProfiles, { 'com.bcinarli.PanePeek': profile.uuid });
  assert.throws(() => storeExportOptions({ ...profile, applicationIdentity: 'Apple Distribution', installerIdentity: 'B'.repeat(40) }));
});

test('Store profiles must be current and explicit, with no development or all-device access', () => {
  const now = new Date('2026-10-20T00:00:00Z');
  assert.equal(validateStoreProfile(profile, now), profile);
  for (const override of [
    { applicationIdentifier: `${team}.*` }, { applicationIdentifier: `${team}.other.app` },
    { expires: '2026-10-19T00:00:00Z' }, { expires: 'invalid' }, { getTaskAllow: true }, { getTaskAllow: 'false' },
    { provisionedDevices: [] }, { provisionsAllDevices: false }, { platforms: ['iOS'] }, { platforms: 'OSX' },
  ]) {
    assert.throws(() => validateStoreProfile({ ...profile, ...override }, now));
  }
});

test('archive and export reject uploads, ambiguous signing and arbitrary Xcode flags', () => {
  assert.deepEqual(parseStoreArguments(['archive']), { action: 'archive' });
  for (const args of [
    ['upload'], ['archive', '__proto__', 'value'], ['archive', '-allowProvisioningUpdates'], ['archive', '--profile', 'file'],
    ['export', 'app.xcarchive'], ['archive', '--installer-identity', 'B'.repeat(40)],
    ['archive', '--profile', 'first', '--profile', 'second', '--app-identity', 'A'.repeat(40)],
    ['export', '-archivePath'],
  ]) {
    assert.throws(() => parseStoreArguments(args), /Usage:/);
  }
});

const installerFingerprint = Array(32).fill('AB').join(':');
const installerResult = `Package "PanePeek.pkg":
   Status: signed by a developer certificate issued by Apple (Development)
   Certificate Chain:
    1. 3rd Party Mac Developer Installer: Example (AB12CD34EF)
       Expires: 2030-01-01 00:00:00 +0000
       SHA256 Fingerprint:
           ${Array(22).fill('AB').join(' ')}
           ${Array(10).fill('AB').join(' ')}
       ------------------------------------------------------------------------
    2. Apple Worldwide Developer Relations Certification Authority
       SHA256 Fingerprint:
           ${Array(32).fill('CD').join(' ')}
`;

test('Store installer verification accepts the native Store classification and exact leaf certificate', () => {
  assert.doesNotThrow(() => validateStoreInstallerSignature(installerResult, installerFingerprint));
});

test('Store installer verification rejects invalid trust, other certificate types and chain-only matches', () => {
  for (const result of [
    installerResult.replace('signed by a developer certificate issued by Apple (Development)', 'revoked signature'),
    installerResult.replace('signed by a developer certificate issued by Apple (Development)', 'no signature'),
    installerResult.replace('3rd Party Mac Developer Installer:', 'Developer ID Installer:'),
    installerResult.replaceAll('AB AB', 'EF EF'),
  ]) {
    assert.throws(() => validateStoreInstallerSignature(result, installerFingerprint));
  }
  assert.throws(() => validateStoreInstallerSignature(installerResult, Array(32).fill('CD').join(':')));
  assert.throws(() => validateStoreInstallerSignature(installerResult, undefined));
});
