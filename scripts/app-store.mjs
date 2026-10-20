import { execFileSync } from 'node:child_process';
import { closeSync, openSync } from 'node:fs';
import { cp, mkdir, mkdtemp, readFile, readdir, stat, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { copyAppDocuments } from './app-documents.mjs';
import { readReleaseMetadata, validateReleaseMetadata } from './release-metadata.mjs';
import { signLocalSandboxBundle } from './release-signing.mjs';
import { readStoreProfile, requireStoreIdentity, storeExportOptions, verifyStoreInstaller, verifyStoreSignature } from './app-store-signing.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const resourceNames = ['Assets.car', 'AppIcon.icns', 'LICENSE', 'NOTICE', 'PRIVACY.md', 'lucide-LICENSE.txt', 'Privacy.txt', 'Acknowledgements.txt'];
const usage = 'Usage: node scripts/app-store.mjs archive [--profile PATH --app-identity SHA1] | export ARCHIVE --profile PATH --app-identity SHA1 --installer-identity SHA1';

export function parseStoreArguments(args) {
  const [action, ...rest] = args;
  if (!['archive', 'export'].includes(action)) { throw new Error(usage); }
  const result = { action };
  if (action === 'export') {
    result.archive = rest.shift();
    if (!result.archive || result.archive.startsWith('-')) { throw new Error(usage); }
  }
  const names = { '--profile': 'profile', '--app-identity': 'applicationIdentity', '--installer-identity': 'installerIdentity' };
  while (rest.length) {
    const flag = rest.shift();
    const name = Object.hasOwn(names, flag) ? names[flag] : undefined;
    const value = rest.shift();
    if (!name || result[name] || !value || value.startsWith('-')) { throw new Error(usage); }
    result[name] = value;
  }
  if (Boolean(result.profile) !== Boolean(result.applicationIdentity) ||
      (action === 'archive' && result.installerIdentity) ||
      (action === 'export' && (!result.profile || !result.installerIdentity))) { throw new Error(usage); }
  return result;
}

function plist(path, key) {
  return JSON.parse(execFileSync('/usr/bin/plutil', key
    ? ['-extract', key, 'json', '-o', '-', path] : ['-convert', 'json', '-o', '-', path], { encoding: 'utf8' }));
}

async function writePlist(path, values) {
  await writeFile(path, JSON.stringify(values));
  execFileSync('/usr/bin/plutil', ['-convert', 'xml1', path]);
}

/** Verify the native archive layout and return its production app metadata. */
export async function inspectArchive(archive) {
  const properties = plist(join(archive, 'Info.plist'), 'ApplicationProperties');
  if (properties.ApplicationPath !== 'Applications/PanePeek.app' ||
      (await readdir(join(archive, 'Products'))).join() !== 'Applications' ||
      (await readdir(join(archive, 'Products', 'Applications'))).join() !== 'PanePeek.app') {
    throw new Error('A native single-app PanePeek archive is required.');
  }
  const app = join(archive, 'Products', properties.ApplicationPath);
  const info = plist(join(app, 'Contents', 'Info.plist'));
  validateReleaseMetadata({ version: info.CFBundleShortVersionString, build: Number(info.CFBundleVersion) });
  if (typeof info.CFBundleVersion !== 'string' || !/^[1-9][0-9]*$/.test(info.CFBundleVersion)) {
    throw new Error('The archive build number must retain the assigned integer format.');
  }
  if (info.CFBundleIdentifier !== 'com.bcinarli.PanePeek' || info.CFBundleExecutable !== 'PanePeek' || info.CFBundlePackageType !== 'APPL' ||
      info.PanePeekSandboxed !== true || info.PanePeekSandboxReview ||
      properties.CFBundleIdentifier !== info.CFBundleIdentifier || properties.CFBundleVersion !== info.CFBundleVersion ||
      properties.CFBundleShortVersionString !== info.CFBundleShortVersionString) {
    throw new Error('Archive identity or release metadata does not match the production app.');
  }
  if (info.CFBundleIconName !== 'AppIcon' || info.CFBundleIconFile !== 'AppIcon') {
    throw new Error('The archive must include the compiled macOS App Store icon.');
  }
  const architecture = execFileSync('xcrun', ['lipo', '-archs', join(app, 'Contents', 'MacOS', 'PanePeek')], { encoding: 'utf8' }).trim();
  if (architecture !== 'arm64') { throw new Error('The archive requires arm64 code.'); }
  if (((await stat(join(app, 'Contents', 'MacOS', 'PanePeek'))).mode & 0o111) === 0) { throw new Error('The app is not executable.'); }
  for (const name of resourceNames) {
    const file = await stat(join(app, 'Contents', 'Resources', name));
    if (!file.isFile() || file.size === 0) { throw new Error(`Missing archive resource: ${name}.`); }
  }
  return { app, info };
}

function xcode(args, log, env) {
  const output = openSync(log, 'wx', 0o600);
  try {
    execFileSync('xcodebuild', args, { env, cwd: root, stdio: ['ignore', output, output], timeout: 30 * 60_000 });
  } catch {
    throw new Error(`Xcode failed; inspect the local log at ${log}.`);
  } finally { closeSync(output); }
}

async function run() {
  const options = parseStoreArguments(process.argv.slice(2));
  const env = { ...process.env };
  if (!env.DEVELOPER_DIR && execFileSync('xcode-select', ['--print-path'], { encoding: 'utf8' }).trim() === '/Library/Developer/CommandLineTools') {
    env.DEVELOPER_DIR = '/Applications/Xcode.app/Contents/Developer';
  }
  let profile;
  if (options.profile) {
    requireStoreIdentity(options.applicationIdentity);
    profile = readStoreProfile(resolve(options.profile), options.applicationIdentity);
  }
  if (options.installerIdentity) { requireStoreIdentity(options.installerIdentity, true); }
  const outputRoot = join(root, '.build', 'app-store');
  await mkdir(outputRoot, { recursive: true });
  if (options.action === 'export') {
    const archive = resolve(options.archive);
    const original = await inspectArchive(archive);
    const output = await mkdtemp(join(outputRoot, 'export-'));
    const settings = join(output, 'ExportOptions.plist');
    await writePlist(settings, storeExportOptions({ ...profile, ...options }));
    xcode(['-exportArchive', '-archivePath', archive, '-exportPath', join(output, 'package'), '-exportOptionsPlist', settings], join(output, 'export.log'), env);
    const packages = (await readdir(join(output, 'package'))).filter(name => name.endsWith('.pkg'));
    if (packages.length !== 1) { throw new Error('Xcode did not produce one App Store installer package.'); }
    const installer = join(output, 'package', packages[0]);
    verifyStoreInstaller(installer, options.installerIdentity);
    const expanded = join(output, 'expanded');
    execFileSync('/usr/sbin/pkgutil', ['--expand-full', installer, expanded], { stdio: 'pipe', timeout: 120_000 });
    const apps = [];
    async function locateApp(directory, depth = 0) {
      if (depth > 8) { throw new Error('Unexpected installer layout.'); }
      for (const entry of await readdir(directory, { withFileTypes: true })) {
        if (!entry.isDirectory()) { continue; }
        const path = join(directory, entry.name);
        if (entry.name.endsWith('.app')) { apps.push(path); } else { await locateApp(path, depth + 1); }
      }
    }
    await locateApp(expanded);
    if (apps.length !== 1) { throw new Error('The installer must contain exactly one app.'); }
    verifyStoreSignature(apps[0], profile, options.applicationIdentity);
    const embedded = readStoreProfile(join(apps[0], 'Contents', 'embedded.provisionprofile'), options.applicationIdentity);
    if (embedded.uuid !== profile.uuid) { throw new Error('The exported app has a different provisioning profile.'); }
    const originalInfo = original.info;
    const exportedInfo = plist(join(apps[0], 'Contents', 'Info.plist'));
    if (exportedInfo.CFBundleIdentifier !== 'com.bcinarli.PanePeek' || exportedInfo.PanePeekSandboxed !== true ||
        originalInfo.CFBundleIconName !== exportedInfo.CFBundleIconName || originalInfo.CFBundleIconFile !== exportedInfo.CFBundleIconFile ||
        originalInfo.LSMinimumSystemVersion !== exportedInfo.LSMinimumSystemVersion ||
        originalInfo.CFBundleShortVersionString !== exportedInfo.CFBundleShortVersionString || originalInfo.CFBundleVersion !== exportedInfo.CFBundleVersion) {
      throw new Error('Xcode changed the assigned release metadata.');
    }
    for (const name of resourceNames) {
      const before = await readFile(join(original.app, 'Contents', 'Resources', name));
      const after = await readFile(join(apps[0], 'Contents', 'Resources', name));
      if (!before.equals(after)) { throw new Error(`Xcode changed the app resource: ${name}.`); }
    }
    const uuid = app => execFileSync('xcrun', ['dwarfdump', '--uuid', join(app, 'Contents', 'MacOS', 'PanePeek')], { encoding: 'utf8', env }).match(/UUID: ([A-F0-9-]+)/i)?.[1];
    const originalUUID = uuid(original.app);
    if (!originalUUID || originalUUID !== uuid(apps[0])) { throw new Error('The exported app does not match the archived executable.'); }
    console.log(`Exported locally: ${join(output, 'package', packages[0])}`);
    return;
  }
  const metadata = await readReleaseMetadata(join(root, 'version.json'));
  const manifest = JSON.parse(execFileSync('xcrun', ['swift', 'package', 'dump-package'], { cwd: root, env, encoding: 'utf8' }));
  const minimum = manifest.platforms.find(platform => platform.platformName === 'macos').version;
  const output = await mkdtemp(join(outputRoot, `${metadata.version}-build${metadata.build}-`));
  const documents = join(output, 'documents');
  await mkdir(documents);
  await copyAppDocuments(root, documents);
  const archive = join(output, 'PanePeek.xcarchive');
  const signing = profile ? [`CODE_SIGN_IDENTITY=${options.applicationIdentity}`, `DEVELOPMENT_TEAM=${profile.team}`, `PROVISIONING_PROFILE_SPECIFIER=${profile.uuid}`] : ['CODE_SIGNING_ALLOWED=NO'];
  console.log('Creating the local Xcode archive…');
  xcode(['archive', '-project', join(root, 'xcode', 'panepeek.xcodeproj'), '-scheme', 'PanePeek', '-configuration', 'Release',
    '-destination', 'generic/platform=macOS', '-archivePath', archive, '-derivedDataPath', join(output, 'derived-data'),
    `MARKETING_VERSION=${metadata.version}`, `CURRENT_PROJECT_VERSION=${metadata.build}`, `MACOSX_DEPLOYMENT_TARGET=${minimum}`,
    `PANEPEEK_DOCUMENTS_DIR=${documents}`, ...signing], join(output, 'archive.log'), env);
  const { app, info } = await inspectArchive(archive);
  if (info.CFBundleShortVersionString !== metadata.version || info.CFBundleVersion !== String(metadata.build) || info.LSMinimumSystemVersion !== minimum) {
    throw new Error('The archive does not match the maintained version/build and deployment target.');
  }
  if (profile) { verifyStoreSignature(app, profile, options.applicationIdentity); }
  const review = join(output, 'review', 'PanePeek Sandbox Review.app');
  if (!profile) {
    await cp(app, review, { recursive: true, errorOnExist: true, force: false });
    await writePlist(join(review, 'Contents', 'Info.plist'), {
      ...info, CFBundleIdentifier: 'com.bcinarli.PanePeek.SandboxReview',
      CFBundleName: 'PanePeek Sandbox Review', CFBundleDisplayName: 'PanePeek Sandbox Review', PanePeekSandboxReview: true,
    });
    signLocalSandboxBundle(review);
  }
  await writeFile(join(output, 'preparation.json'), JSON.stringify({ archive, review: profile ? null : review, ...metadata, signedForStore: Boolean(profile) }, null, 2));
  console.log(`Archive verified locally: ${archive}`);
  if (!profile) { console.log(`Ad hoc sandbox review app: ${review}`); }
  console.log('Local preparation only. No upload or submission was performed.');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  run().catch(error => { console.error(`App Store preparation failed: ${error.message}`); process.exitCode = 1; });
}
