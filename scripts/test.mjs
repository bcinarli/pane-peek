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
  args.push(...process.argv.slice(2));
  execFileSync('swift', args, { cwd: projectRoot, stdio: 'inherit' });
} catch (error) {
  console.error(`Tests failed: ${error.message}`);
  process.exitCode = error.status || 1;
}
