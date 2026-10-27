import { execFileSync } from 'node:child_process';
import { chmod, copyFile, mkdir, mkdtemp, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readReleaseMetadata } from './release-metadata.mjs';
import { copyAppDocuments } from './app-documents.mjs';
import { packageReleaseBundle } from './release-package.mjs';
import { notariseReleaseBundle } from './release-notarisation.mjs';
import { parseBuildArguments, signLocalSandboxBundle, signReleaseBundle, validateReleaseIdentity, validateReviewIdentity } from './release-signing.mjs';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));

try {
  const { release, sandboxReview, identity, notaryProfile, githubUpdates } = parseBuildArguments(process.argv.slice(2));
  const buildArguments = release ? ['--configuration', 'release', '--arch', 'arm64'] : [];
  const { version, build } = await readReleaseMetadata(join(projectRoot, 'version.json'));

  if (identity) {
    if (sandboxReview) { validateReviewIdentity(identity); }
    else { validateReleaseIdentity(identity); }
  }

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
  await writeFile(join(contentsPath, 'Info.plist'), `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>PanePeek</string>
  <key>CFBundleIdentifier</key><string>${sandboxReview ? "com.bcinarli.PanePeek.SandboxReview" : "com.bcinarli.PanePeek"}</string>
  ${release || githubUpdates ? "<key>PanePeekUpdateChannel</key><string>github</string>" : ""}
  <key>LSFileQuarantineEnabled</key><true/>
  <key>CFBundleName</key><string>${sandboxReview ? "PanePeek Sandbox Review" : "PanePeek"}</string>
  <key>CFBundleDisplayName</key><string>${sandboxReview ? "PanePeek Sandbox Review" : "PanePeek"}</string>
  ${release || sandboxReview ? "<key>PanePeekSandboxed</key><true/>" : ""}
  ${sandboxReview ? "<key>PanePeekSandboxReview</key><true/>" : ""}
  <key>CFBundleIconFile</key><string>PanePeek.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>CFBundleVersion</key><string>${build}</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Bilal Cinarli</string>
  <key>LSMinimumSystemVersion</key><string>${minimumVersion}</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAccentColorName</key><string>accent</string>
  <key>NSDesktopFolderUsageDescription</key><string>PanePeek accesses your Desktop folder to preview and organise files, such as moving a screenshot into another folder.</string>
  <key>NSDocumentsFolderUsageDescription</key><string>PanePeek accesses your Documents folder to preview and edit documents, such as opening a text file and saving your changes.</string>
  <key>NSDownloadsFolderUsageDescription</key><string>PanePeek accesses your Downloads folder to preview and organise downloaded files, such as moving a downloaded PDF into Documents.</string>
</dict>
</plist>
`);
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
