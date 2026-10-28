import { execFileSync } from 'node:child_process';
import { appendFileSync } from 'node:fs';
import { basename, extname } from 'node:path';

const all = { swift: true, javascript: true, actions: true };

function classify(paths) {
  const scans = { swift: false, javascript: false, actions: false };
  for (const path of paths) {
    if (/^\.github\/(workflows|actions|codeql)(\/|[.-])/.test(path)
        || path === 'scripts/ci-changes.mjs' || path === 'tests/tooling/ci-changes.test.mjs') {
      return { scans: all, reason: 'Workflow or scanner inputs changed; running all scans.' };
    }
    if (/\.(md|txt|rst|adoc)$/i.test(path) || ['LICENSE', 'NOTICE'].includes(path)) {
      continue;
    }
    if (extname(path).toLowerCase() === '.swift' || basename(path) === 'Package.resolved'
        || path.startsWith('xcode/') || path === 'scripts/sandbox.entitlements' || path === 'version.json') {
      scans.swift = true;
    } else if (/^(website|scripts\/website|tests\/website)\//.test(path)
        || /\.(mjs|cjs|js|jsx|mts|cts|ts|tsx|html|htm|xhtml|vue|svelte)$/i.test(path)
        || /^(package(-lock)?\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?)$/.test(basename(path))) {
      scans.javascript = true;
      if (path.startsWith('scripts/') && !path.startsWith('scripts/website/')
          && !['scripts/check-privacy.mjs', 'scripts/privacy-hooks.mjs'].includes(path)) {
        scans.swift = true;
      }
    } else {
      return { scans: all, reason: 'Unrecognised inputs changed; running all scans.' };
    }
  }
  return { scans, reason: `Selected scans from the complete PR diff (${paths.length} changed paths).` };
}

function selectScans() {
  if (process.env.GITHUB_EVENT_NAME !== 'pull_request') {
    return { scans: all, reason: 'Main, scheduled and manual runs scan every language.' };
  }
  const base = process.env.CODEQL_BASE_SHA;
  const head = process.env.CODEQL_HEAD_SHA;
  try {
    if (![base, head].every(sha => /^[a-f0-9]{40}$/i.test(sha ?? ''))) {
      throw new Error('Missing PR commit IDs');
    }
    // Merge-base comparison covers the whole PR; disabling rename detection retains both paths.
    const diff = execFileSync('git', ['diff', '--name-only', '--no-renames', '-z', `${base}...${head}`, '--'], {
      encoding: 'utf8', timeout: 20_000, maxBuffer: 16 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'],
    });
    return classify(diff.split('\0').filter(Boolean));
  } catch {
    return { scans: all, reason: 'Unable to determine the complete PR diff; running all scans.' };
  }
}

const { scans, reason } = selectScans();
if (process.env.GITHUB_OUTPUT) {
  appendFileSync(process.env.GITHUB_OUTPUT, Object.entries(scans).map(([name, run]) => `${name}=${run}\n`).join(''));
}
if (process.env.GITHUB_STEP_SUMMARY) {
  const labels = { swift: 'Swift', javascript: 'JavaScript/TypeScript', actions: 'GitHub Actions' };
  const rows = Object.entries(scans).map(([name, run]) => `| ${labels[name]} | ${run ? 'Run' : 'Skip'} |\n`).join('');
  appendFileSync(process.env.GITHUB_STEP_SUMMARY, `## CodeQL scan selection\n\n${reason}\n\n| Language | Decision |\n| --- | --- |\n${rows}`);
}
console.log(JSON.stringify({ ...scans, reason }));
