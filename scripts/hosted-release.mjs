import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { appendFile, mkdir, readFile, rmdir, stat, unlink, writeFile } from 'node:fs/promises';
import { isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseBuildArguments, validateReleaseIdentity } from './release-signing.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const owner = 'PanePeek hosted signing\n';
const secretNames = ['RELEASE_CERTIFICATE_BASE64', 'RELEASE_CERTIFICATE_PASSWORD', 'RELEASE_SIGNING_IDENTITY', 'RELEASE_APPLE_ID', 'RELEASE_TEAM_ID', 'RELEASE_NOTARY_PASSWORD'];

function runTool(command, args, { env = process.env, cwd = root, timeout = 120_000 } = {}) {
  const result = spawnSync(command, args, { env, cwd, timeout, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  // Credential tools can include their arguments in errors; expose no raw diagnostics.
  if (result.status !== 0) { throw new Error('External tool failed.'); }
  return result.stdout;
}

function credentialDirectory(env) {
  if (env.GITHUB_ACTIONS !== 'true' || env.RUNNER_OS !== 'macOS' || env.RUNNER_ENVIRONMENT !== 'github-hosted' ||
      env.GITHUB_EVENT_NAME !== 'workflow_dispatch' || env.GITHUB_REF !== 'refs/heads/main') {
    throw new Error('Hosted release credentials require a manual main run on a GitHub-hosted Mac.');
  }
  if (!env.RUNNER_TEMP || !isAbsolute(env.RUNNER_TEMP) || /[\r\n\0]/.test(env.RUNNER_TEMP)) {
    throw new Error('A valid runner temporary directory is required.');
  }
  return join(env.RUNNER_TEMP, 'panepeek-release-signing');
}

async function present(path) {
  try { await stat(path); return true; } catch (error) {
    if (error.code === 'ENOENT') { return false; }
    throw error;
  }
}

/** Remove only the job-owned temporary identity, profile and credential files; safe to retry. */
export async function cleanupHostedSigning({ env = process.env, run = runTool } = {}) {
  const directory = credentialDirectory(env);
  if (!await present(directory)) { return; }
  const marker = join(directory, 'owner');
  if (await readFile(marker, 'utf8').catch(() => '') !== owner) {
    throw new Error('Refusing to clean an unowned signing directory.');
  }
  const keychain = join(directory, 'signing.keychain-db');
  let failed = false;
  if (await present(keychain)) {
    try { run('/usr/bin/security', ['delete-keychain', keychain]); } catch { failed = true; }
  }
  for (const name of ['certificate.p12', 'outputs']) {
    try { await unlink(join(directory, name)); } catch (error) { if (error.code !== 'ENOENT') { failed = true; } }
  }
  if (failed) { throw new Error('Temporary signing credential cleanup failed; review assets are withheld.'); }
  await unlink(marker);
  await rmdir(directory);
}

/** Build with temporary hosted credentials and publish workflow outputs only after cleanup. */
export async function buildHostedRelease({ env = process.env, run = runTool, verifyIdentity = validateReleaseIdentity } = {}) {
  const directory = credentialDirectory(env);
  for (const name of secretNames) {
    if (typeof env[name] !== 'string' || !env[name] || /[\r\n\0]/.test(env[name])) {
      throw new Error(`Configure the ${name} environment secret without line breaks.`);
    }
  }
  const { identity } = parseBuildArguments(['--release', '--sign', env.RELEASE_SIGNING_IDENTITY]);
  if (!/^[A-Z0-9]{10}$/.test(env.RELEASE_TEAM_ID) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(env.RELEASE_APPLE_ID)) {
    throw new Error('Configure valid Apple account and team environment secrets.');
  }
  const certificate = Buffer.from(env.RELEASE_CERTIFICATE_BASE64, 'base64');
  if (certificate.length === 0 || certificate.toString('base64') !== env.RELEASE_CERTIFICATE_BASE64) {
    throw new Error('The signing certificate secret must be canonical, single-line Base64.');
  }
  if (!env.GITHUB_OUTPUT || !isAbsolute(env.GITHUB_OUTPUT) || /[\r\n\0]/.test(env.GITHUB_OUTPUT) ||
      typeof env.RELEASE_COMMIT !== 'string' || env.RELEASE_COMMIT.length !== 40 || !/^[a-f0-9]+$/.test(env.RELEASE_COMMIT)) {
    throw new Error('A full reviewed source commit and GitHub output file are required.');
  }
  const childEnv = { ...env };
  for (const name of secretNames) { delete childEnv[name]; }
  if (run('git', ['rev-parse', 'HEAD'], { env: childEnv }).trim() !== env.RELEASE_COMMIT) {
    throw new Error('The source commit differs from the reviewed release commit.');
  }
  await mkdir(directory, { mode: 0o700 });
  const keychain = join(directory, 'signing.keychain-db');
  const certificatePath = join(directory, 'certificate.p12');
  const outputsPath = join(directory, 'outputs');
  const password = randomBytes(32).toString('base64url');
  let outputs;
  let stage = 'credential setup';
  try {
    await writeFile(join(directory, 'owner'), owner, { flag: 'wx', mode: 0o600 });
    await writeFile(certificatePath, certificate, { flag: 'wx', mode: 0o600 });
    const keychains = run('/usr/bin/security', ['list-keychains', '-d', 'user'], { env: childEnv })
      .split('\n').map(line => line.trim()).filter(Boolean).map(line => JSON.parse(line));
    run('/usr/bin/security', ['create-keychain', '-p', password, keychain], { env: childEnv });
    run('/usr/bin/security', ['set-keychain-settings', '-lut', '5400', keychain], { env: childEnv });
    run('/usr/bin/security', ['unlock-keychain', '-p', password, keychain], { env: childEnv });
    run('/usr/bin/security', ['import', certificatePath, '-P', env.RELEASE_CERTIFICATE_PASSWORD, '-T', '/usr/bin/codesign', '-T', '/usr/bin/security', '-t', 'cert', '-f', 'pkcs12', '-k', keychain], { env: childEnv });
    run('/usr/bin/security', ['set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, keychain], { env: childEnv });
    verifyIdentity(identity, keychain);
    run('/usr/bin/security', ['list-keychains', '-d', 'user', '-s', keychain, ...keychains], { env: childEnv });
    await unlink(certificatePath);
    stage = 'notarisation credential validation';
    run('xcrun', ['notarytool', 'store-credentials', 'panepeek-ci', '--keychain', keychain, '--apple-id', env.RELEASE_APPLE_ID, '--team-id', env.RELEASE_TEAM_ID, '--password', env.RELEASE_NOTARY_PASSWORD], { env: childEnv });
    stage = 'signed and notarised build';
    await writeFile(outputsPath, '', { flag: 'wx', mode: 0o600 });
    run(process.execPath, [join(root, 'scripts/build-app.mjs'), '--release', '--sign', identity, '--notarize', 'panepeek-ci'], {
      env: { ...childEnv, GITHUB_OUTPUT: outputsPath, PANEPEEK_NOTARY_KEYCHAIN: keychain }, timeout: 3_300_000,
    });
    outputs = await readFile(outputsPath, 'utf8');
    if (!outputs) { throw new Error('No package outputs.'); }
  } catch {
    throw new Error(`Hosted ${stage} failed; no review assets are published.`);
  } finally {
    await cleanupHostedSigning({ env, run });
  }
  await appendFile(env.GITHUB_OUTPUT, outputs);
  console.log('Signed and notarised package prepared; temporary signing credentials removed.');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const action = process.argv.slice(2);
  const operation = action.length === 0 ? buildHostedRelease : action.length === 1 && action[0] === 'cleanup' ? cleanupHostedSigning : undefined;
  if (!operation) {
    console.error('Usage: node scripts/hosted-release.mjs [cleanup]');
    process.exitCode = 1;
  } else {
    operation().catch(error => { console.error(error.message); process.exitCode = 1; });
  }
}
