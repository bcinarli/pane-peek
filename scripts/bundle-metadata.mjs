import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';

const source = fileURLToPath(new URL('../xcode/Info.plist', import.meta.url));
const commonKeys = [
  'CFBundlePackageType', 'NSHumanReadableCopyright', 'NSPrincipalClass',
  'NSHighResolutionCapable', 'NSAccentColorName',
  'NSDesktopFolderUsageDescription', 'NSDocumentsFolderUsageDescription', 'NSDownloadsFolderUsageDescription',
  'CFBundleDocumentTypes', 'CFBundleURLTypes',
];

/** Read shared values without importing Xcode placeholders or channel settings. */
export function readCommonBundleMetadata() {
  const info = JSON.parse(execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', source], { encoding: 'utf8' }));
  return Object.fromEntries(commonKeys.map(key => {
    const value = info[key];
    const valid = key === 'CFBundleDocumentTypes'
      ? Array.isArray(value) && value.length === 1 && value[0].CFBundleTypeRole === 'Viewer'
        && value[0].LSHandlerRank === 'Alternate' && isDeepStrictEqual(value[0].LSItemContentTypes, ['public.item'])
      : key === 'CFBundleURLTypes'
      ? isDeepStrictEqual(value, [{ CFBundleURLName: 'com.bcinarli.PanePeek.launcher', CFBundleTypeRole: 'Viewer', CFBundleURLSchemes: ['panepeek'] }])
      : key === 'NSHighResolutionCapable' ? typeof value === 'boolean' : typeof value === 'string' && value.trim();
    if (!valid) { throw new Error(`Common bundle metadata requires a valid ${key}.`); }
    return [key, value];
  }));
}

/** Reject drift in metadata read from a produced bundle. */
export function verifyCommonBundleMetadata(info) {
  for (const [key, value] of Object.entries(readCommonBundleMetadata())) {
    if (!isDeepStrictEqual(info[key], value)) { throw new Error(`Bundle metadata differs from the shared ${key}.`); }
  }
}
