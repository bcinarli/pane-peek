import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdir, open, readFile, unlink, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readReleaseMetadata } from './release-metadata.mjs';
import { packageReleaseBundle } from './release-package.mjs';
import { parseBuildArguments, verifyReleaseSignature } from './release-signing.mjs';

const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const digest = bytes => createHash('sha256').update(bytes).digest('hex');

function runTool(command, args, { env = process.env, timeout = 120_000, allowFailure = false } = {}) {
  const result = spawnSync(command, args, { env, encoding: 'utf8', timeout });
  if (!allowFailure && result.status !== 0) {
    throw new Error(result.error?.message || result.stderr.trim() || `${command} failed with status ${result.status}.`);
  }
  return result.stdout;
}

/** Notarise and staple the unchanged signed app; retain the submission for safe retries. */
export async function notariseReleaseBundle(bundlePath, identity, profile, { env = process.env, run = runTool, verify = verifyReleaseSignature, finalise } = {}) {
  const parsed = parseBuildArguments(['--release', '--sign', identity, '--notarize', profile]);
  identity = parsed.identity;
  const cdhash = verify(bundlePath, identity);
  const directory = join(dirname(bundlePath), 'notarisation');
  await mkdir(directory, { recursive: true });
  const lockPath = join(directory, 'job.lock');
  const lock = await open(lockPath, 'wx', 0o600).catch(error => {
    if (error.code === 'EEXIST') { throw new Error('A notarisation job lock exists. Check for an active process before removing it.'); }
    throw error;
  });
  try {
    const archivePath = join(directory, 'submission.zip');
    const receiptPath = join(directory, 'submission.json');
    let receipt;
    try {
      receipt = JSON.parse(await readFile(receiptPath, 'utf8'));
    } catch (error) {
      if (error.code !== 'ENOENT') { throw error; }
    }
    if (receipt) {
      if (typeof receipt.id !== 'string' || !uuid.test(receipt.id) || receipt.id.length !== 36 ||
          receipt.cdhash !== cdhash || receipt.identity !== identity || receipt.sha256 !== digest(await readFile(archivePath))) {
        throw new Error('The notarisation receipt, signed code or submission archive has changed or does not match.');
      }
    } else {
      try {
        await readFile(archivePath);
        throw new Error('A submission archive exists without a receipt. Check notarytool history before uploading again.');
      } catch (error) {
        if (error.code !== 'ENOENT') { throw error; }
      }
      run('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', bundlePath, archivePath], { env });
      const sha256 = digest(await readFile(archivePath));
      const submission = JSON.parse(run('xcrun', ['notarytool', 'submit', archivePath, '--keychain-profile', profile, '--output-format', 'json'], { env, timeout: 300_000 }));
      if (typeof submission.id !== 'string' || submission.id.length !== 36 || !uuid.test(submission.id)) {
        throw new Error('The notary service returned no valid submission ID. Check notarytool history before uploading again.');
      }
      receipt = { id: submission.id.toLowerCase(), cdhash, identity, sha256 };
      await writeFile(receiptPath, JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx', mode: 0o600 });
    }
    const credentials = ['--keychain-profile', profile];
    console.log(`Notarisation submission: ${receipt.id}. Waiting for Apple.`);
    run('xcrun', ['notarytool', 'wait', receipt.id, ...credentials, '--output-format', 'json', '--timeout', '20m'], { env, timeout: 1_210_000, allowFailure: true });
    const status = JSON.parse(run('xcrun', ['notarytool', 'info', receipt.id, ...credentials, '--output-format', 'json'], { env }));
    if (status.id?.toLowerCase() !== receipt.id || !['Accepted', 'Invalid', 'Rejected'].includes(status.status)) {
      throw new Error('Apple notarisation is not complete. The submission is saved; resume this package instead of uploading again.');
    }
    const logPath = join(directory, 'notary-log.json');
    run('xcrun', ['notarytool', 'log', receipt.id, ...credentials, logPath], { env });
    const log = JSON.parse(await readFile(logPath, 'utf8'));
    if (log.jobId?.toLowerCase() !== receipt.id || log.sha256 !== receipt.sha256 || log.status !== status.status) {
      throw new Error('The notarisation log does not match this submission.');
    }
    if (status.status !== 'Accepted') {
      throw new Error(`Apple notarisation was ${status.status}. Review ${logPath}.`);
    }
    if ((log.issues !== null && (!Array.isArray(log.issues) || log.issues.length > 0)) ||
        !Array.isArray(log.ticketContents) || !log.ticketContents.some(ticket => ticket.cdhash === cdhash && ticket.arch === 'arm64')) {
      throw new Error('The notarisation log has issues or no matching arm64 ticket. Review it before distribution.');
    }
    run('xcrun', ['stapler', 'staple', bundlePath], { env });
    run('xcrun', ['stapler', 'validate', bundlePath], { env });
    if (verify(bundlePath, identity) !== cdhash) {
      throw new Error('The signed code changed during notarisation or stapling.');
    }
    await finalise?.();
    console.log('Apple accepted the app; its stapled ticket and signature are verified.');
    return receipt;
  } finally {
    await lock.close();
    await unlink(lockPath);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  (async () => {
    const packagePath = resolve(process.argv[2] || '.');
    if (/[\r\n]/.test(packagePath)) { throw new Error('The package path must not contain line breaks.'); }
    const { identity, notaryProfile } = parseBuildArguments(['--release', ...process.argv.slice(3)]);
    if (!identity || !notaryProfile) {
      throw new Error('Usage: node scripts/release-notarisation.mjs PACKAGE_DIRECTORY --sign IDENTITY_SHA1 --notarize KEYCHAIN_PROFILE');
    }
    const metadata = await readReleaseMetadata(fileURLToPath(new URL('../version.json', import.meta.url)));
    const bundlePath = join(packagePath, 'PanePeek.app');
    const plist = JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', join(bundlePath, 'Contents/Info.plist')], { encoding: 'utf8' }));
    if (plist.CFBundleShortVersionString !== metadata.version || plist.CFBundleVersion !== String(metadata.build)) {
      throw new Error('The resumed app metadata differs from version.json.');
    }
    await notariseReleaseBundle(bundlePath, identity, notaryProfile, {
      finalise: () => packageReleaseBundle(bundlePath, metadata),
    });
  })().catch(error => {
    console.error(`Notarisation failed: ${error.message}`);
    process.exitCode = 1;
  });
}
