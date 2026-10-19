import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));

try {
  const swiftc = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const testingPlugins = resolve(dirname(swiftc), '..', 'lib', 'swift', 'host', 'plugins', 'testing');
  const args = ['test'];

  // Some Command Line Tools builders omit the installed Testing macro search path.
  if (existsSync(testingPlugins)) {
    args.push('-Xswiftc', '-plugin-path', '-Xswiftc', testingPlugins);
  }
  const extraArgs = process.argv.slice(2);
  args.push(...extraArgs);
  const hasSelectionOrQuery = extraArgs.some(arg =>
    /^(--filter|--skip|--specifier)(=|$)/.test(arg) ||
    ['list', '--list-tests', '-l', '--help', '-h', '--version'].includes(arg)
  );
  const phases = hasSelectionOrQuery ? [[]] : [
    ['--filter', '.*HighlightingTests'],
    ['--skip-build', '--skip', '.*HighlightingTests'],
  ];
  // Lexical stress work must not starve browser-test gate controllers.
  for (const phase of phases) {
    execFileSync('swift', [...args, ...phase], { cwd: projectRoot, stdio: 'inherit' });
  }
} catch (error) {
  console.error(`Tests failed: ${error.message}`);
  process.exitCode = error.status || 1;
}
