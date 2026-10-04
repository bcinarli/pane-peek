import { execFileSync } from 'node:child_process';
import { chmod, copyFile, mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));

try {
  execFileSync('swift', ['build', '--product', 'PanePeek'], {
    cwd: projectRoot,
    stdio: 'inherit',
  });

  const binaryDirectory = execFileSync('swift', ['build', '--show-bin-path'], {
    cwd: projectRoot,
    encoding: 'utf8',
  }).trim();
  const manifest = JSON.parse(execFileSync('swift', ['package', 'dump-package'], {
    cwd: projectRoot,
    encoding: 'utf8',
  }));
  const minimumVersion = manifest.platforms.find(platform => platform.platformName === 'macos').version;
  const bundlePath = join(projectRoot, '.build', 'PanePeek.app');
  const contentsPath = join(bundlePath, 'Contents');
  const executablePath = join(contentsPath, 'MacOS', 'PanePeek');
  const resourcesPath = join(contentsPath, 'Resources');

  await mkdir(join(contentsPath, 'MacOS'), { recursive: true });
  await mkdir(resourcesPath, { recursive: true });
  await copyFile(join(binaryDirectory, 'PanePeek'), executablePath);
  await copyFile(join(projectRoot, 'Assets', 'PanePeek.icns'), join(resourcesPath, 'PanePeek.icns'));
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
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>${minimumVersion}</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
`);
  console.log(`Built ${bundlePath}`);
} catch (error) {
  console.error(`App build failed: ${error.message}`);
  process.exitCode = 1;
}
