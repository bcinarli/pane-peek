import { execFileSync, spawnSync } from 'node:child_process';
import { X509Certificate } from 'node:crypto';
import { validateReleaseEntitlements } from './release-signing.mjs';

const bundleIdentifier = 'com.bcinarli.PanePeek';
const fingerprintPattern = /^[A-Fa-f0-9]{40}$/;
const uuidPattern = /^[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}$/;

/** Accept the sandbox capabilities plus the profile's exact Store identity. */
export function validateStoreEntitlements(values, team, applicationIdentifier = `${team}.${bundleIdentifier}`) {
  if (values?.['com.apple.application-identifier'] !== applicationIdentifier ||
      values?.['com.apple.developer.team-identifier'] !== team) {
    throw new Error('The Store signature does not match the selected application and team.');
  }
  const capabilities = { ...values };
  delete capabilities['com.apple.application-identifier'];
  delete capabilities['com.apple.developer.team-identifier'];
  validateReleaseEntitlements(capabilities);
}

/** Create manual, local-only export options without allocating a new build. */
export function storeExportOptions({ team, uuid, applicationIdentity, installerIdentity }) {
  if (!/^[A-Z0-9]{10}$/.test(team ?? '') || !uuidPattern.test(uuid ?? '') ||
      !fingerprintPattern.test(applicationIdentity ?? '') || !fingerprintPattern.test(installerIdentity ?? '')) {
    throw new Error('Store export requires a valid team, profile UUID and exact signing fingerprints.');
  }
  return {
    method: 'app-store-connect', destination: 'export', signingStyle: 'manual', teamID: team,
    provisioningProfiles: { [bundleIdentifier]: uuid },
    signingCertificate: applicationIdentity.toUpperCase(),
    installerSigningCertificate: installerIdentity.toUpperCase(),
    manageAppVersionAndBuildNumber: false, uploadSymbols: false,
  };
}

/** Reject expired, development, wildcard and other-app profiles before Xcode runs. */
export function validateStoreProfile(profile, now = new Date()) {
  if (!uuidPattern.test(profile.uuid ?? '') || !/^[A-Z0-9]{10}$/.test(profile.team ?? '') ||
      !/^[A-Z0-9]{10}\.com\.bcinarli\.PanePeek$/.test(profile.applicationIdentifier ?? '') ||
      !Array.isArray(profile.platforms) || !['OSX', 'macOS'].some(value => profile.platforms.includes(value)) ||
      !(new Date(profile.expires) > now) || (profile.getTaskAllow !== undefined && profile.getTaskAllow !== false) ||
      profile.provisionedDevices !== undefined || profile.provisionsAllDevices !== undefined) {
    throw new Error('A current, explicit Mac App Store distribution profile for PanePeek is required.');
  }
  return profile;
}

function extract(xml, key, format = 'raw', optional = false) {
  try {
    return execFileSync('/usr/bin/plutil', ['-extract', key, format, '-o', '-', '-'], {
      input: xml, encoding: 'utf8', timeout: 10_000, stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
  } catch {
    if (optional) { return undefined; }
    throw new Error('The selected provisioning profile is missing required metadata.');
  }
}

export function readStoreProfile(path, applicationIdentity) {
  const xml = execFileSync('/usr/bin/security', ['cms', '-D', '-i', path], {
    encoding: 'utf8', timeout: 15_000, stdio: ['ignore', 'pipe', 'pipe'],
  });
  const entitlements = JSON.parse(extract(xml, 'Entitlements', 'json'));
  const certificate = extract(xml, 'DeveloperCertificates.0');
  // Apple's legacy fingerprint selects the local identity; validate the complete certificate bytes.
  if (extract(xml, 'DeveloperCertificates.1', 'raw', true) !== undefined || !fingerprintPattern.test(applicationIdentity ?? '') ||
      !storeIdentityCertificate(applicationIdentity).raw.equals(Buffer.from(certificate, 'base64'))) {
    throw new Error('The application signing identity must match the distribution profile.');
  }
  return validateStoreProfile({
    uuid: extract(xml, 'UUID'), team: JSON.parse(extract(xml, 'TeamIdentifier', 'json'))[0],
    applicationIdentifier: entitlements['com.apple.application-identifier'],
    platforms: JSON.parse(extract(xml, 'Platform', 'json')), expires: extract(xml, 'ExpirationDate'),
    getTaskAllow: entitlements['get-task-allow'],
    provisionedDevices: extract(xml, 'ProvisionedDevices', 'json', true),
    provisionsAllDevices: extract(xml, 'ProvisionsAllDevices', 'raw', true),
  });
}

export function requireStoreIdentity(fingerprint, installer = false) {
  if (!fingerprintPattern.test(fingerprint ?? '')) { throw new Error('An exact signing fingerprint is required.'); }
  const identities = execFileSync('/usr/bin/security', ['find-identity', '-v', ...(!installer ? ['-p', 'codesigning'] : [])], {
    encoding: 'utf8', timeout: 15_000, stdio: ['ignore', 'pipe', 'pipe'],
  });
  const types = installer ? ['3rd Party Mac Developer Installer:'] : ['Apple Distribution:', '3rd Party Mac Developer Application:'];
  const found = identities.split('\n').map(line => {
    const match = line.match(/^\s*\d+\) ([A-F0-9]{40}) "(.*)"$/i);
    return match?.[1].toUpperCase() === fingerprint.toUpperCase() && types.some(type => match[2].startsWith(type)) ? match[2] : undefined;
  }).find(Boolean);
  if (!found) { throw new Error(`The selected ${installer ? 'installer' : 'application'} identity is not a valid local App Store identity with its private key.`); }
  return found;
}

function storeIdentityCertificate(identity, installer = false) {
  const name = requireStoreIdentity(identity, installer);
  const pem = execFileSync('/usr/bin/security', ['find-certificate', '-a', '-c', name, '-p'], {
    encoding: 'utf8', timeout: 15_000, stdio: ['ignore', 'pipe', 'pipe'],
  });
  const certificates = (pem.match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g) ?? []).map(value => new X509Certificate(value));
  const selected = certificates.find(value => value.fingerprint.replaceAll(':', '').toUpperCase() === identity.toUpperCase());
  if (!selected) { throw new Error('The selected signing certificate is not available in the local Keychain.'); }
  return selected;
}

export function verifyStoreInstaller(path, identity) {
  const selected = storeIdentityCertificate(identity, true);
  const result = execFileSync('/usr/sbin/pkgutil', ['--check-signature', path], {
    encoding: 'utf8', timeout: 30_000, env: { ...process.env, LC_ALL: 'C' }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  validateStoreInstallerSignature(result, selected.fingerprint256);
}

/** Verify the Store installer result against the selected public certificate. */
export function validateStoreInstallerSignature(result, fingerprint256) {
  const leaf = result.split(/^\s*2\./m)[0];
  const actual = leaf.match(/SHA256 Fingerprint:([\sA-Fa-f0-9]+)/)?.[1].replace(/\s/g, '').toUpperCase();
  const expected = fingerprint256?.replaceAll(':', '').toUpperCase();
  // Store submission certificates receive this classification before Apple distributes the app.
  if (!/^[A-F0-9]{64}$/.test(expected ?? '') || actual !== expected ||
      !/^\s*1\. 3rd Party Mac Developer Installer:/m.test(leaf) ||
      !/^\s*Status: signed by a developer certificate issued by Apple \(Development\)\s*$/m.test(result)) {
    throw new Error('The installer is not trusted with the selected Store certificate.');
  }
}

export function verifyStoreSignature(app, profile, identity) {
  execFileSync('/usr/bin/codesign', ['--verify', '--deep', '--strict', '--test-requirement',
    `=anchor apple generic and certificate leaf = H"${identity.toUpperCase()}"`, app], { stdio: 'pipe', timeout: 120_000 });
  const details = spawnSync('/usr/bin/codesign', ['--display', '--verbose=4', app], { encoding: 'utf8', timeout: 15_000 });
  const flags = details.stderr?.match(/\bflags=0x([a-f0-9]+)/i);
  if (details.status !== 0 || !flags || (Number.parseInt(flags[1], 16) & 0x10000) === 0) {
    throw new Error('The Store app does not retain Hardened Runtime.');
  }
  const xml = execFileSync('/usr/bin/codesign', ['--display', '--entitlements', '-', '--xml', app], {
    encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 15_000,
  });
  const values = JSON.parse(execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', '-'], { input: xml, encoding: 'utf8' }));
  validateStoreEntitlements(values, profile.team, profile.applicationIdentifier);
}
