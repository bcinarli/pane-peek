import { execFileSync, spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';
import { fileURLToPath } from 'node:url';

const sandboxEntitlementsPath = fileURLToPath(new URL('./sandbox.entitlements', import.meta.url));

function signingFingerprint(identity) {
  if (typeof identity !== 'string' || identity.length !== 40 || !/^[a-f0-9]+$/i.test(identity)) {
    throw new Error('Signing requires the 40-character SHA-1 fingerprint of a Developer ID Application identity.');
  }
  return identity.toUpperCase();
}

export function parseBuildArguments(args) {
  if (args.length === 0) { return { release: false }; }
  if (args.length === 1 && args[0] === '--sandbox-review') { return { release: false, sandboxReview: true }; }
  if (args.length === 1 && args[0] === '--release') { return { release: true }; }
  if ([3, 5].includes(args.length) && args[0] === '--release' && args[1] === '--sign' &&
      (args.length === 3 || args[3] === '--notarize')) {
    const identity = signingFingerprint(args[2]);
    if (args.length === 3) { return { release: true, identity }; }
    const notaryProfile = args[4];
    if (typeof notaryProfile !== 'string' || notaryProfile.match(/[A-Za-z0-9][A-Za-z0-9._-]{0,63}/)?.[0] !== notaryProfile) {
      throw new Error('The notary profile must contain 1–64 letters, digits, dots, underscores or hyphens, starting with a letter or digit.');
    }
    return { release: true, identity, notaryProfile };
  }
  throw new Error('Usage: node scripts/build-app.mjs [--sandbox-review | --release [--sign IDENTITY_SHA1 [--notarize KEYCHAIN_PROFILE]]]');
}

export function validateReleaseIdentity(identity, keychainPath) {
  const fingerprint = signingFingerprint(identity);
  const identities = execFileSync('/usr/bin/security', ['find-identity', '-v', '-p', 'codesigning', ...(keychainPath ? [keychainPath] : [])], {
    encoding: 'utf8', timeout: 15_000,
  });
  const valid = identities.split('\n').some(line => {
    const match = line.match(/^\s*\d+\) ([A-F0-9]{40}) "(.*)"$/i);
    return match?.[1].toUpperCase() === fingerprint && match[2].startsWith('Developer ID Application: ');
  });
  if (!valid) {
    throw new Error('The selected fingerprint is not a valid Developer ID Application signing identity with a private key.');
  }
}

function codesign(args) {
  const result = spawnSync('/usr/bin/codesign', args, { encoding: 'utf8', timeout: 120_000 });
  if (result.status !== 0) {
    throw new Error(result.error?.message || result.stderr.trim() || `codesign failed with status ${result.status}.`);
  }
  return result;
}

export function validateReleaseEntitlements(values) {
  const required = {
    'com.apple.security.app-sandbox': true,
    'com.apple.security.files.user-selected.read-write': true,
    'com.apple.security.files.bookmarks.app-scope': true,
  };
  if (!isDeepStrictEqual(values, required)) {
    throw new Error('The app requires exactly the approved enabled sandbox entitlements.');
  }
}

function verifyBundleEntitlements(bundlePath) {
  const entitlements = codesign(['--display', '--entitlements', '-', '--xml', bundlePath]).stdout.trim();
  const values = entitlements ? JSON.parse(execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', '-'], {
    input: entitlements, encoding: 'utf8', timeout: 10_000,
  })) : {};
  validateReleaseEntitlements(values);
}

/** Sign a local sandbox package without a distribution identity or timestamp. */
export function signLocalSandboxBundle(bundlePath) {
  codesign(['--force', '--sign', '-', '--options', 'runtime', '--entitlements', sandboxEntitlementsPath, bundlePath]);
  codesign(['--verify', '--deep', '--strict', bundlePath]);
  verifyBundleEntitlements(bundlePath);
}

export function verifyReleaseSignature(bundlePath, identity) {
  const fingerprint = signingFingerprint(identity);
  const requirement = `=anchor apple generic and certificate leaf = H"${fingerprint}" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists`;
  codesign(['--verify', '--deep', '--strict', '--test-requirement', requirement, bundlePath]);
  const details = codesign(['--display', '--verbose=4', bundlePath]).stderr;
  const flags = details.match(/\bflags=0x([a-f0-9]+)/i);
  if (!flags || (Number.parseInt(flags[1], 16) & 0x10000) === 0) {
    throw new Error('The signed release does not enable Hardened Runtime.');
  }
  if (!/^Timestamp=.+$/m.test(details)) {
    throw new Error('The signed release has no secure timestamp.');
  }
  verifyBundleEntitlements(bundlePath);
  const cdhash = details.match(/^CDHash=([a-f0-9]{40})$/mi)?.[1].toLowerCase();
  if (!cdhash) { throw new Error('The signed release has no CodeDirectory hash.'); }
  return cdhash;
}

/** Verify the Apple-issued container signature and secure timestamp; return its code hash. */
export function verifyDiskImageSignature(imagePath, identity) {
  const fingerprint = signingFingerprint(identity);
  const requirement = `=anchor apple generic and certificate leaf = H"${fingerprint}" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists`;
  codesign(['--verify', '--strict', '--test-requirement', requirement, imagePath]);
  const details = codesign(['--display', '--verbose=4', imagePath]).stderr;
  const cdhash = details.match(/^CDHash=([a-f0-9]{40})$/mi)?.[1].toLowerCase();
  if (!cdhash || !/^Timestamp=.+$/m.test(details)) {
    throw new Error('The disk image has no verified code hash or secure timestamp.');
  }
  return cdhash;
}

export function signReleaseDiskImage(imagePath, identity) {
  codesign(['--sign', signingFingerprint(identity), '--timestamp', '--identifier', 'com.bcinarli.PanePeek.diskimage', imagePath]);
  verifyDiskImageSignature(imagePath, identity);
}

export function signReleaseBundle(bundlePath, identity) {
  codesign(['--sign', signingFingerprint(identity), '--force', '--options', 'runtime', '--timestamp',
    '--entitlements', sandboxEntitlementsPath, bundlePath]);
  verifyReleaseSignature(bundlePath, identity);
}
