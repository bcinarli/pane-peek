import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
let loadedPolicy;
function rules() {
  loadedPolicy ??= JSON.parse(readFileSync(join(scriptDirectory, 'privacy-rules.json'), 'utf8'));
  return loadedPolicy;
}
const pathRules = [
  ['private-home-path', /(?<![\w])(?:\/(?:Users|home)\/|[A-Za-z]:\\+Users\\+)[^\s"'`<>()[\]{},;]+/gi],
  ['machine-cache-path', /\/(?:private\/)?var\/folders\/[^\s"'`<>()[\]{},;]+/g],
  ['private-vault-link', /(?:obsidian|logseq):\/\/[^\s"'`<>()[\]{},;]+/gi]
];

function normalise(line) {
  return line.replace(/(?:%[\da-f]{2})+/gi, value => {
    try {
      return decodeURIComponent(value);
    } catch {
      return value;
    }
  }).replace(/&#(x[\da-f]+|\d+);/gi, (value, code) => {
    const number = code[0].toLowerCase() === 'x' ? parseInt(code.slice(1), 16) : Number(code);
    return number <= 0x10ffff ? String.fromCodePoint(number) : value;
  }).replace(/&(quot|apos|lt|gt|amp);/g, (_, entity) => ({ quot: '"', apos: "'", lt: '<', gt: '>', amp: '&' })[entity]);
}

function sensitiveFilename(file) {
  const name = file.split('/').at(-1);
  return (/^\.env(?:\.|$)/.test(name) && !/^\.env\.(?:example|sample|template)$/.test(name))
    || /\.(?:p12|pfx|mobileprovision|key)$/i.test(name)
    || /^(?:\.netrc|id_rsa|id_dsa|id_ecdsa(?:_sk)?|id_ed25519(?:_sk)?)$/.test(name)
    || /(?:^|\/)\.aws\/credentials$/.test(file);
}

/** Inspect bytes without following links; findings contain locations and rule IDs only. */
export function inspectFile(file, bytes) {
  const findings = sensitiveFilename(file) ? [{ file, line: 1, rule: 'sensitive-file' }] : [];
  if (bytes.includes(0)) {
    return findings;
  }
  bytes.toString('utf8').split(/\r?\n/).forEach((line, index) => {
    const text = normalise(line);
    for (const [rule, pattern] of pathRules) {
      for (const match of text.matchAll(pattern)) {
        const value = match[0].replace(/\\+/g, '\\');
        const allowed = rules().pathExceptions.some(exception => exception.files.includes(file) && exception.values.includes(value));
        if (!allowed) {
          findings.push({ file, line: index + 1, rule });
        }
      }
    }
  });
  return findings;
}

function git(repo, args, input) {
  const result = spawnSync('git', ['-C', repo, ...args], {
    input, maxBuffer: 64 * 1024 * 1024, timeout: 30_000,
    env: { ...process.env, GIT_OPTIONAL_LOCKS: '0', GIT_NO_REPLACE_OBJECTS: '1' }
  });
  if (result.status !== 0 || result.error) {
    throw new Error('Unable to read the requested Git content.');
  }
  return result.stdout;
}

function commit(repo, ref) {
  return git(repo, ['rev-parse', '--verify', '--end-of-options', `${ref}^{commit}`]).toString().trim();
}

function entries(repo, revision) {
  const staged = revision === null;
  const changed = staged ? new Set(git(repo, ['diff', '--cached', '--name-only', '-z', '--diff-filter=ACMRT']).toString().split('\0')) : null;
  const listing = git(repo, staged ? ['ls-files', '--stage', '-z'] : ['ls-tree', '-rz', '--full-tree', revision]);
  return listing.toString('utf8').split('\0').filter(Boolean).flatMap(record => {
    const tab = record.indexOf('\t');
    const [mode, oidOrType, stageOrOid] = record.slice(0, tab).split(' ');
    const file = record.slice(tab + 1);
    if (staged && stageOrOid !== '0') {
      throw new Error('Resolve index conflicts before checking privacy.');
    }
    if (staged && !changed.has(file)) {
      return [];
    }
    if (!['100644', '100755', '120000'].includes(mode)) {
      throw new Error('Unsupported Git entry; privacy scan is incomplete.');
    }
    if (file.includes('\ufffd') || isAbsolute(file) || file.split('/').some(part => ['..', '.git'].includes(part))) {
      throw new Error('Unsupported Git filename; privacy scan is incomplete.');
    }
    return [{ file, oid: staged ? oidOrType : stageOrOid }];
  });
}

function blobs(repo, files) {
  const oids = [...new Set(files.map(file => file.oid))];
  if (oids.length === 0) {
    return new Map();
  }
  const output = git(repo, ['cat-file', '--batch'], `${oids.join('\n')}\n`);
  const contents = new Map();
  let offset = 0;
  for (const oid of oids) {
    const end = output.indexOf(10, offset);
    const [actual, type, length] = output.subarray(offset, end).toString().split(' ');
    const size = Number(length);
    if (actual !== oid || type !== 'blob' || !Number.isSafeInteger(size) || size < 0 || end + size + 2 > output.length) {
      throw new Error('Incomplete Git blob; privacy scan is incomplete.');
    }
    contents.set(oid, output.subarray(end + 1, end + 1 + size));
    offset = end + size + 2;
  }
  return contents;
}

function verifyScanner(binary) {
  const result = spawnSync(binary, ['version'], { encoding: 'utf8', timeout: 5_000 });
  if (result.status !== 0 || result.error || result.stdout.trim() !== rules().gitleaksVersion) {
    throw new Error('Gitleaks pinned version is required; check privacy-rules.json and GITLEAKS_BIN.');
  }
}

function secretFindings(binary, snapshot, report, ignore, files) {
  const result = spawnSync(binary, ['dir', '.', '--config', join(scriptDirectory, 'gitleaks.toml'),
    '--gitleaks-ignore-path', ignore, '--ignore-gitleaks-allow', '--redact=100', '--no-banner', '--no-color',
    '--report-format', 'json', '--report-path', report, '--timeout', '30'], {
    cwd: snapshot, timeout: 35_000, maxBuffer: 1024 * 1024
  });
  if (result.error || ![0, 1].includes(result.status)) {
    throw new Error('Secret scanner failed; privacy scan is incomplete.');
  }
  let findings;
  try {
    findings = JSON.parse(readFileSync(report, 'utf8'));
  } catch {
    throw new Error('Secret scanner report is unavailable; privacy scan is incomplete.');
  }
  if (!Array.isArray(findings) || (result.status === 1 && findings.length === 0)) {
    throw new Error('Invalid secret scanner report; privacy scan is incomplete.');
  }
  return findings.map(finding => {
    const file = relative(snapshot, resolve(snapshot, finding.File)).split(sep).join('/');
    if (!files.has(file) || !Number.isSafeInteger(finding.StartLine) || finding.StartLine < 1 || typeof finding.RuleID !== 'string') {
      throw new Error('Invalid secret scanner location; privacy scan is incomplete.');
    }
    return { file, line: finding.StartLine, rule: finding.RuleID };
  });
}

/** Check committed trees or index blobs with an offline, version-pinned secret scanner. */
export function checkRepository({ repo, mode = 'tree', ref = 'HEAD', from, to, gitleaks = process.env.GITLEAKS_BIN || 'gitleaks' }) {
  verifyScanner(gitleaks);
  repo = git(repo, ['rev-parse', '--show-toplevel']).toString().replace(/\n$/, '');
  let revisions;
  if (mode === 'staged') {
    revisions = [null];
  } else if (mode === 'tree') {
    revisions = [commit(repo, ref)];
  } else if (mode === 'range') {
    const base = commit(repo, from);
    const head = commit(repo, to);
    revisions = [...new Set([...git(repo, ['rev-list', '--reverse', `${base}..${head}`]).toString().trim().split('\n').filter(Boolean), head])];
  } else {
    throw new Error('Unknown privacy scan mode.');
  }

  const temporary = mkdtempSync(join(tmpdir(), 'panepeek-privacy-'));
  const findings = [];
  let scannedFiles = 0;
  let binaryFiles = 0;
  try {
    const ignore = join(temporary, 'empty.ignore');
    writeFileSync(ignore, '', { mode: 0o600 });
    for (const [index, revision] of revisions.entries()) {
      const snapshot = join(temporary, String(index));
      mkdirSync(snapshot, { mode: 0o700 });
      const files = entries(repo, revision);
      const contents = blobs(repo, files);
      for (const { file, oid } of files) {
        const bytes = contents.get(oid);
        findings.push(...inspectFile(file, bytes).map(finding => ({ ...finding, revision })));
        if (bytes.includes(0)) {
          binaryFiles++;
        }
        const destination = join(snapshot, file);
        mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
        // Git symlink blobs become plain text, so scanning cannot escape the snapshot.
        writeFileSync(destination, bytes, { mode: 0o600 });
      }
      if (files.length > 0) {
        const secrets = secretFindings(gitleaks, snapshot, join(temporary, `${index}.json`), ignore, new Set(files.map(file => file.file)));
        findings.push(...secrets.map(finding => ({ ...finding, revision })));
      }
      scannedFiles += files.length;
    }
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
  return { findings, scannedFiles, binaryFiles };
}

/** Print redacted locations and scan totals; return the findings exit code. */
export function reportResult(result) {
  for (const finding of result.findings) {
    const revision = finding.revision ? ` (${finding.revision.slice(0, 12)})` : '';
    console.log(`${JSON.stringify(finding.file)}:${finding.line} ${finding.rule}${revision}`);
  }
  console.log(`Checked ${result.scannedFiles} file versions; ${result.findings.length} findings; ${result.binaryFiles} binary files need manual privacy review.`);
  return result.findings.length > 0 ? 1 : 0;
}

function main(args) {
  const options = { repo: process.cwd() };
  let selectedMode = false;
  for (let index = 0; index < args.length; index++) {
    const flag = args[index];
    if (flag === '--repo' && args[index + 1]) {
      options.repo = resolve(args[++index]);
    } else if (!selectedMode && flag === '--staged') {
      options.mode = 'staged';
      selectedMode = true;
    } else if (!selectedMode && flag === '--tree' && args[index + 1]) {
      options.mode = 'tree';
      options.ref = args[++index];
      selectedMode = true;
    } else if (!selectedMode && flag === '--range' && args[index + 1] && args[index + 2]) {
      options.mode = 'range';
      options.from = args[++index];
      options.to = args[++index];
      selectedMode = true;
    } else {
      throw new Error('Usage: check-privacy.mjs [--repo repository] [--tree ref | --staged | --range base head]');
    }
  }
  process.exitCode = reportResult(checkRepository(options));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    // Child-process output can itself contain secrets or machine-specific paths.
    console.error(error instanceof Error && error.message.startsWith('Usage:') ? error.message :
      error instanceof Error && error.message.startsWith('Gitleaks ') ? error.message : 'Privacy check could not complete. Check Git references, file support and scanner availability.');
    process.exitCode = 2;
  }
}
