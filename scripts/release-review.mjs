import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { appendFile, readFile, writeFile } from 'node:fs/promises';
import { isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readReleaseMetadata, validateReleaseMetadata } from './release-metadata.mjs';

function git(root, args) {
  return execFileSync('git', args, {
    cwd: root, encoding: 'utf8', timeout: 15_000, stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, GIT_NO_REPLACE_OBJECTS: '1', GIT_OPTIONAL_LOCKS: '0' },
  }).trim();
}

/** Check a main commit and both latest CI runs before selecting its source in a clean checkout. */
export async function verifyReleaseSource({ root, commit, repository, token, request = fetch }) {
  if (typeof commit !== 'string' || commit.match(/[0-9a-f]{40}/)?.[0] !== commit) {
    throw new Error('Select a full lowercase 40-character commit SHA.');
  }
  if (typeof repository !== 'string' || repository.match(/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+/)?.[0] !== repository || !token) {
    throw new Error('A repository and read-only GitHub token are required.');
  }
  if (git(root, ['status', '--porcelain'])) {
    throw new Error('Release preparation requires a clean source tree.');
  }
  try {
    git(root, ['merge-base', '--is-ancestor', commit, 'refs/remotes/origin/main']);
  } catch {
    throw new Error('The selected commit must be on origin/main with complete history.');
  }
  const urls = [];
  for (const workflow of ['ci.yml', 'privacy.yml']) {
    const url = new URL(`https://api.github.com/repos/${repository}/actions/workflows/${workflow}/runs`);
    url.search = new URLSearchParams({ head_sha: commit, branch: 'main', event: 'push', per_page: '1' });
    const response = await request(url, {
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' },
      redirect: 'error', signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      throw new Error(`Cannot verify ${workflow}: HTTP ${response.status}.`);
    }
    const run = (await response.json()).workflow_runs?.[0];
    if (!run || run.head_sha !== commit || run.head_branch !== 'main' || run.event !== 'push' || run.status !== 'completed' || run.conclusion !== 'success') {
      throw new Error(`The latest ${workflow} main run must be successful for the selected commit.`);
    }
    urls.push(run.html_url);
  }
  return urls;
}

/** Derive candidate labels without changing metadata; prerelease sequences are canonical integer strings. */
export function releaseCandidate({ metadata, kind = 'stable', sequence }) {
  const { version, build } = validateReleaseMetadata(metadata);
  if (!['stable', 'beta', 'rc'].includes(kind)) {
    throw new Error('Release kind must be stable, beta or rc.');
  }
  const prerelease = kind !== 'stable';
  if (prerelease) {
    if (typeof sequence !== 'string' || sequence.match(/[1-9][0-9]*/)?.[0] !== sequence || !Number.isSafeInteger(Number(sequence))) {
      throw new Error('Prerelease sequence must be a positive safe integer without leading zeros.');
    }
  } else if (sequence !== undefined) {
    throw new Error('Stable releases do not accept a sequence.');
  }
  const label = `${version}${prerelease ? `-${kind}.${sequence}` : ''}`;
  return {
    tag: `v${label}`, title: `PanePeek ${label} (build ${build})`, prerelease,
    artifactName: `PanePeek-${label}-build${build}-review`,
  };
}

/** Reuse one changelog section in a review draft without assigning a publication date. */
export function releaseNotes({ metadata, commit, repository, minimumVersion, changelog, kind, sequence }) {
  const candidate = releaseCandidate({ metadata, kind, sequence });
  const { version, build } = metadata;
  const sections = changelog.replace(/\r\n/g, '\n').split(/^## /m).slice(1).map(section => {
    const newline = section.indexOf('\n');
    return { title: section.slice(0, newline).trim(), body: section.slice(newline + 1).trim() };
  });
  const released = candidate.prerelease ? undefined : sections.find(section => section.title.startsWith(`[${version}] - `));
  const selected = released ?? sections.find(section => section.title === 'Unreleased');
  if (!selected?.body) {
    throw new Error(candidate.prerelease ? 'The changelog needs a non-empty Unreleased section.' : 'The changelog needs a non-empty matching release or Unreleased section.');
  }
  const instructions = candidate.prerelease
    ? `This is a ${kind === 'beta' ? 'beta testing build' : 'release candidate'}. App version: ${version} (build ${build}).\n\n` +
      'Install manually from the DMG. To return to an older stable version, download and reinstall it manually.\n\n'
    : '';
  return `# Draft: ${candidate.title}\n\n` +
    `Requires macOS ${minimumVersion}+ on Apple Silicon.\n\n` +
    `Tag: \`${candidate.tag}\`\n\n` +
    `Source: [${commit}](https://github.com/${repository}/commit/${commit}).\n\n` +
    instructions +
    `## ${released ? `Changelog for ${version}` : 'Unreleased changelog draft'}\n\n${selected.body}\n`;
}

async function main(args) {
  const root = fileURLToPath(new URL('..', import.meta.url));
  if (!((args[0] === 'verify' && args.length === 2) || (args[0] === 'candidate' && args.length <= 3) ||
        (args[0] === 'notes' && args.length >= 2 && args.length <= 4))) {
    throw new Error('Usage: node scripts/release-review.mjs verify COMMIT | candidate [KIND [SEQUENCE]] | notes PACKAGE_DIRECTORY [KIND [SEQUENCE]]');
  }
  if (args[0] === 'verify') {
    const urls = await verifyReleaseSource({ root, commit: args[1], repository: process.env.GITHUB_REPOSITORY, token: process.env.GITHUB_TOKEN });
    console.log(`Source and CI verified:\n${urls.join('\n')}`);
    return;
  }
  const metadata = await readReleaseMetadata(join(root, 'version.json'));
  if (args[0] === 'candidate') {
    const candidate = releaseCandidate({ metadata, kind: args[1], sequence: args[2] });
    const output = process.env.GITHUB_OUTPUT;
    if (output !== undefined) {
      if (!isAbsolute(output) || /[\r\n\0]/.test(output)) {
        throw new Error('A valid absolute GitHub output file is required.');
      }
      await appendFile(output, `artifact_name=${candidate.artifactName}\n`);
    }
    console.log(JSON.stringify(candidate, null, 2));
    return;
  }
  const kind = args[2];
  const sequence = args[3];
  releaseCandidate({ metadata, kind, sequence });
  const packagePath = resolve(args[1]);
  const plist = JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', join(packagePath, 'PanePeek.app/Contents/Info.plist')], { encoding: 'utf8' }));
  if (plist.CFBundleShortVersionString !== metadata.version || plist.CFBundleVersion !== String(metadata.build)) {
    throw new Error('Packaged app metadata differs from version.json.');
  }
  for (const format of ['zip', 'dmg']) {
    const name = `PanePeek-${metadata.version}-build${metadata.build}-macos-arm64.${format}`;
    const checksum = createHash('sha256').update(await readFile(join(packagePath, name))).digest('hex');
    if (await readFile(join(packagePath, `${name}.sha256`), 'utf8') !== `${checksum}  ${name}\n`) {
      throw new Error(`The ${format} checksum does not match the package.`);
    }
  }
  const notes = releaseNotes({ metadata, commit: git(root, ['rev-parse', 'HEAD']), repository: process.env.GITHUB_REPOSITORY || 'bcinarli/pane-peek', minimumVersion: plist.LSMinimumSystemVersion, changelog: await readFile(join(root, 'CHANGELOG.md'), 'utf8'), kind, sequence });
  await writeFile(join(packagePath, 'release-notes.md'), notes, { flag: 'wx' });
  console.log(`Draft notes: ${join(packagePath, 'release-notes.md')}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch(error => {
    console.error(`Release review failed: ${error.message}`);
    process.exitCode = 1;
  });
}
