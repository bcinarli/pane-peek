import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
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

/** Reuse one changelog section in a review draft without assigning a publication date. */
export function releaseNotes({ metadata, commit, repository, minimumVersion, changelog }) {
  const { version, build } = validateReleaseMetadata(metadata);
  const sections = changelog.replace(/\r\n/g, '\n').split(/^## /m).slice(1).map(section => {
    const newline = section.indexOf('\n');
    return { title: section.slice(0, newline).trim(), body: section.slice(newline + 1).trim() };
  });
  const released = sections.find(section => section.title.startsWith(`[${version}] - `));
  const selected = released ?? sections.find(section => section.title === 'Unreleased');
  if (!selected?.body) {
    throw new Error('The changelog needs a non-empty matching release or Unreleased section.');
  }
  return `# Draft: PanePeek ${version} (build ${build})\n\n` +
    `Requires macOS ${minimumVersion}+ on Apple Silicon.\n\n` +
    `Source: [${commit}](https://github.com/${repository}/commit/${commit}).\n\n` +
    `## ${released ? `Changelog for ${version}` : 'Unreleased changelog draft'}\n\n${selected.body}\n`;
}

async function main(args) {
  const root = fileURLToPath(new URL('..', import.meta.url));
  if (args.length !== 2 || !['verify', 'notes'].includes(args[0])) {
    throw new Error('Usage: node scripts/release-review.mjs verify COMMIT | notes PACKAGE_DIRECTORY');
  }
  if (args[0] === 'verify') {
    const urls = await verifyReleaseSource({ root, commit: args[1], repository: process.env.GITHUB_REPOSITORY, token: process.env.GITHUB_TOKEN });
    console.log(`Source and CI verified:\n${urls.join('\n')}`);
    return;
  }
  const packagePath = resolve(args[1]);
  const metadata = await readReleaseMetadata(join(root, 'version.json'));
  const plist = JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', join(packagePath, 'PanePeek.app/Contents/Info.plist')], { encoding: 'utf8' }));
  if (plist.CFBundleShortVersionString !== metadata.version || plist.CFBundleVersion !== String(metadata.build)) {
    throw new Error('Packaged app metadata differs from version.json.');
  }
  const name = `PanePeek-${metadata.version}-build${metadata.build}-macos-arm64.zip`;
  const checksum = createHash('sha256').update(await readFile(join(packagePath, name))).digest('hex');
  if (await readFile(join(packagePath, `${name}.sha256`), 'utf8') !== `${checksum}  ${name}\n`) {
    throw new Error('The package checksum does not match the archive.');
  }
  const notes = releaseNotes({ metadata, commit: git(root, ['rev-parse', 'HEAD']), repository: process.env.GITHUB_REPOSITORY || 'bcinarli/pane-peek', minimumVersion: plist.LSMinimumSystemVersion, changelog: await readFile(join(root, 'CHANGELOG.md'), 'utf8') });
  await writeFile(join(packagePath, 'release-notes.md'), notes, { flag: 'wx' });
  console.log(`Draft notes: ${join(packagePath, 'release-notes.md')}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch(error => {
    console.error(`Release review failed: ${error.message}`);
    process.exitCode = 1;
  });
}
