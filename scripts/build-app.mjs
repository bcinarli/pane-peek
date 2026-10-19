import { execFileSync } from 'node:child_process';
import { chmod, copyFile, mkdir, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readReleaseMetadata } from './release-metadata.mjs';
import { packageReleaseBundle } from './release-package.mjs';
import { notariseReleaseBundle } from './release-notarisation.mjs';
import { parseBuildArguments, signReleaseBundle, validateReleaseIdentity } from './release-signing.mjs';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));

try {
  const { release, identity, notaryProfile } = parseBuildArguments(process.argv.slice(2));
  const buildArguments = release ? ['--configuration', 'release', '--arch', 'arm64'] : [];
  const { version, build } = await readReleaseMetadata(join(projectRoot, 'version.json'));

  if (identity) { validateReleaseIdentity(identity); }

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
  const licence = await readFile(join(projectRoot, 'LICENSE'), 'utf8');
  const notice = await readFile(join(projectRoot, 'NOTICE'), 'utf8');
  const privacy = await readFile(join(projectRoot, 'PRIVACY.md'), 'utf8');
  const iconLicence = await readFile(join(resourcesPath, 'lucide-LICENSE.txt'), 'utf8');
  for (const name of ['LICENSE', 'NOTICE', 'PRIVACY.md']) {
    await copyFile(join(projectRoot, name), join(resourcesPath, name));
  }
  // Derive offline reading copies from the maintained documents and original notices.
  await writeFile(join(resourcesPath, 'Privacy.txt'), privacy
    .replace(/^#{1,6} /gm, '')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1 ($2)'));
  await writeFile(join(resourcesPath, 'Acknowledgements.txt'),
    `PanePeek acknowledgements\n\n${notice}\nApache License 2.0\n\n${licence}\nLucide and Feather icons\n\n${iconLicence}`);
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
  <key>CFBundleIdentifier</key><string>com.bcinarli.PanePeek</string>
  <key>CFBundleName</key><string>PanePeek</string>
  <key>CFBundleDisplayName</key><string>PanePeek</string>
  <key>CFBundleIconFile</key><string>PanePeek.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>CFBundleVersion</key><string>${build}</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Bilal Cinarli</string>
  <key>LSMinimumSystemVersion</key><string>${minimumVersion}</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAccentColorName</key><string>accent</string>
</dict>
</plist>
`);
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
        env: buildEnvironment, finalise: () => packageReleaseBundle(bundlePath, { version, build }),
      });
    } else {
      await packageReleaseBundle(bundlePath, { version, build });
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
