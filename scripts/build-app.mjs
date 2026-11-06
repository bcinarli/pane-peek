import { execFileSync } from 'node:child_process';
import { chmod, copyFile, mkdir, mkdtemp, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { prereleaseSuffix, prereleaseSuffixKey, readReleaseMetadata } from './release-metadata.mjs';
import { readCommonBundleMetadata, verifyCommonBundleMetadata } from './bundle-metadata.mjs';
import { copyAppDocuments } from './app-documents.mjs';
import { packageReleaseBundle } from './release-package.mjs';
import { notariseReleaseBundle } from './release-notarisation.mjs';
import { parseBuildArguments, signLocalSandboxBundle, signReleaseBundle, validateReleaseIdentity, validateReviewIdentity } from './release-signing.mjs';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));

try {
  const { release, sandboxReview, identity, notaryProfile, githubUpdates } = parseBuildArguments(process.argv.slice(2));
  const buildArguments = release ? ['--configuration', 'release', '--arch', 'arm64'] : [];
  const { version, build } = await readReleaseMetadata(join(projectRoot, 'version.json'));
  const suffix = release || sandboxReview
    ? prereleaseSuffix(process.env.RELEASE_KIND, process.env.RELEASE_SEQUENCE || undefined)
    : undefined;

  if (identity) {
    if (sandboxReview) { validateReviewIdentity(identity); }
    else { validateReleaseIdentity(identity); }
  }

  const commonMetadata = readCommonBundleMetadata();

  const buildEnvironment = { ...process.env };
  if (!buildEnvironment.DEVELOPER_DIR) {
    const selectedDeveloperDirectory = execFileSync('xcode-select', ['--print-path'], { encoding: 'utf8' }).trim();
    if (selectedDeveloperDirectory === '/Library/Developer/CommandLineTools') {
      buildEnvironment.DEVELOPER_DIR = '/Applications/Xcode.app/Contents/Developer';
    }
  }

  execFileSync('xcrun', ['swift', 'build', ...buildArguments, '--product', 'PanePeek'], {
    cwd: projectRoot,
    env: buildEnvironment,
    stdio: 'inherit',
  });

  const binaryDirectory = execFileSync('xcrun', ['swift', 'build', ...buildArguments, '--show-bin-path'], {
    cwd: projectRoot,
    env: buildEnvironment,
    encoding: 'utf8',
  }).trim();
  const manifest = JSON.parse(execFileSync('xcrun', ['swift', 'package', 'dump-package'], {
    cwd: projectRoot,
    env: buildEnvironment,
    encoding: 'utf8',
  }));
  const minimumVersion = manifest.platforms.find(platform => platform.platformName === 'macos').version;
  let bundlePath = join(projectRoot, '.build', 'PanePeek.app');
  if (sandboxReview) {
    const reviewRoot = join(projectRoot, '.build', 'sandbox-review');
    await mkdir(reviewRoot, { recursive: true });
    bundlePath = join(await mkdtemp(join(reviewRoot, 'review-')), 'PanePeek Sandbox Review.app');
  }
  if (release) {
    const packagesPath = join(projectRoot, '.build', 'packages');
    await mkdir(packagesPath, { recursive: true });
    const packagePath = await mkdtemp(join(packagesPath, `${version}-build${build}-`));
    bundlePath = join(packagePath, 'PanePeek.app');
  }
  const contentsPath = join(bundlePath, 'Contents');
  const executablePath = join(contentsPath, 'MacOS', 'PanePeek');
  const resourcesPath = join(contentsPath, 'Resources');

  await mkdir(join(contentsPath, 'MacOS'), { recursive: true });
  await mkdir(resourcesPath, { recursive: true });
  await copyFile(join(binaryDirectory, 'PanePeek'), executablePath);
  await copyFile(join(projectRoot, 'assets', 'PanePeek.icns'), join(resourcesPath, 'PanePeek.icns'));
  await copyFile(join(projectRoot, 'assets', 'lucide-LICENSE.txt'), join(resourcesPath, 'lucide-LICENSE.txt'));
  await copyAppDocuments(projectRoot, resourcesPath);
  execFileSync('xcrun', [
    'actool', join(projectRoot, 'assets', 'ui.xcassets'),
    '--compile', resourcesPath,
    '--platform', 'macosx',
    '--minimum-deployment-target', minimumVersion,
    '--accent-color', 'accent',
  ], { env: buildEnvironment, stdio: 'inherit' });
  await chmod(executablePath, 0o755);
  const infoPath = join(contentsPath, 'Info.plist');
  await writeFile(infoPath, JSON.stringify({
    ...commonMetadata,
    CFBundleExecutable: 'PanePeek',
    CFBundleIdentifier: sandboxReview ? 'com.bcinarli.PanePeek.SandboxReview' : 'com.bcinarli.PanePeek',
    CFBundleName: sandboxReview ? 'PanePeek Sandbox Review' : 'PanePeek',
    CFBundleDisplayName: sandboxReview ? 'PanePeek Sandbox Review' : 'PanePeek',
    CFBundleIconFile: 'PanePeek.icns',
    CFBundleShortVersionString: version,
    CFBundleVersion: String(build),
    [prereleaseSuffixKey]: suffix,
    LSMinimumSystemVersion: minimumVersion,
    LSFileQuarantineEnabled: true,
    ...(release || githubUpdates ? { PanePeekUpdateChannel: 'github' } : {}),
    ...(release || sandboxReview ? { PanePeekSandboxed: true } : {}),
    ...(sandboxReview ? { PanePeekSandboxReview: true } : {}),
  }));
  execFileSync('/usr/bin/plutil', ['-convert', 'xml1', infoPath]);
  verifyCommonBundleMetadata(JSON.parse(execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', infoPath], { encoding: 'utf8' })));
  if (sandboxReview || (release && !identity)) {
    signLocalSandboxBundle(bundlePath, sandboxReview ? identity : undefined);
    if (sandboxReview && identity) { console.log('Certificate-signed sandbox review app verified.'); }
  }
  console.log(`Built ${bundlePath}`);
  if (release) {
    execFileSync('plutil', ['-lint', join(contentsPath, 'Info.plist')], { stdio: 'inherit' });
    const architecture = execFileSync('xcrun', ['lipo', '-archs', executablePath], {
      env: buildEnvironment, encoding: 'utf8',
    }).trim();
    if (architecture !== 'arm64') {
      throw new Error(`Release package requires arm64; executable contains ${architecture}.`);
    }
    if (identity) {
      signReleaseBundle(bundlePath, identity);
      console.log('Developer ID signature, Hardened Runtime and secure timestamp verified.');
    }
    if (notaryProfile) {
      await notariseReleaseBundle(bundlePath, identity, notaryProfile, {
        env: buildEnvironment, finalise: () => packageReleaseBundle(bundlePath, { version, build }, { env: buildEnvironment, identity, notaryProfile }),
      });
    } else {
      await packageReleaseBundle(bundlePath, { version, build }, { env: buildEnvironment, identity, notaryProfile });
    }
    console.log(notaryProfile
      ? 'Notarised local package. Browser download and installation checks remain pending.'
      : identity
      ? 'Signed local package. Notarisation and download installation checks remain pending.'
      : 'Local review package. Developer ID signing and notarisation remain pending.');
  }
} catch (error) {
  console.error(`App build failed: ${error.message}`);
  process.exitCode = 1;
}
