import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { chmod, copyFile, mkdir, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));

try {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== '--release')) {
    throw new Error('Usage: node scripts/build-app.mjs [--release]');
  }
  const release = args[0] === '--release';
  const buildArguments = release ? ['--configuration', 'release', '--arch', 'arm64'] : [];
  const metadata = JSON.parse(await readFile(join(projectRoot, 'version.json'), 'utf8'));
  const version = metadata?.version;
  const build = metadata?.build;
  if (typeof version !== 'string' || version.match(/[0-9]+\.[0-9]+\.[0-9]+/)?.[0] !== version) {
    throw new Error('version.json: version must contain three dot-separated integers, such as 0.1.0.');
  }
  if (!Number.isSafeInteger(build) || build < 1) {
    throw new Error('version.json: build must be a positive safe integer.');
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
    const archivePath = join(dirname(bundlePath), `PanePeek-${version}-build${build}-macos-arm64.zip`);
    execFileSync('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', bundlePath, archivePath]);
    const checksum = createHash('sha256').update(await readFile(archivePath)).digest('hex');
    await writeFile(`${archivePath}.sha256`, `${checksum}  ${basename(archivePath)}\n`);
    console.log(`Package: ${archivePath}\nChecksum: ${archivePath}.sha256`);
    console.log('Local package only. Developer ID signing and notarisation remain pending.');
  }
} catch (error) {
  console.error(`App build failed: ${error.message}`);
  process.exitCode = 1;
}
