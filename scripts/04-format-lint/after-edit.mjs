import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';

const warning = (message) => process.stderr.write(`after-edit: ${message}\n`);
const object = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const within = (base, file) => {
  const relative = path.relative(base, file);
  return relative !== '' && !relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative);
};
function localPath(value, base) {
  if (typeof value !== 'string' || value.length === 0 || /[\x00-\x1f]/.test(value)) throw new Error('Invalid path');
  // Accept CLI backslash separators, but never reinterpret Windows/UNC absolute paths on POSIX.
  if (process.platform !== 'win32' && /^(?:[A-Za-z]:|\\\\)/.test(value)) throw new Error('Foreign absolute path');
  return path.resolve(base, value.replaceAll('\\', '/'));
}
function flag(name) {
  const value = process.env[name] ?? 'true';
  if (!['true', 'false'].includes(value)) throw new Error(`${name} must be true or false`);
  return value === 'true';
}
function timeout() {
  const value = process.env.CHECK_TIMEOUT_SEC ?? '10';
  if (!/^(?:[1-9]|10)$/.test(value)) throw new Error('CHECK_TIMEOUT_SEC must be an integer from 1 to 10');
  return Number(value) * 1000;
}
function patchPaths(patch) {
  if (typeof patch !== 'string') throw new Error('apply_patch needs string input or patch');
  const lines = patch.replaceAll('\r\n', '\n').split('\n');
  if (lines.at(-1) === '') lines.pop();
  if (lines.shift() !== '*** Begin Patch' || lines.pop() !== '*** End Patch') throw new Error('Unknown patch envelope');
  const paths = [];
  for (const line of lines) {
    const header = /^\*\*\* (Add File|Update File|Delete File|Move to): (.+)$/.exec(line);
    if (header) paths.push(header[2]);
    else if (!paths.length || !(/^[ +\-]/.test(line) || line.startsWith('@@') || line === '*** End of File' || line === '')) {
      throw new Error('Unknown patch syntax');
    }
  }
  if (!paths.length) throw new Error('Patch has no file headers');
  return paths;
}
function changedPaths(event, cwd) {
  const args = event.toolArgs;
  if (!object(args)) throw new Error('toolArgs must be an object');
  if (['edit', 'create'].includes(event.toolName)) {
    const has = (key) => Object.hasOwn(args, key);
    if (!has('path') && !has('filePath')) throw new Error('Missing path (or filePath alias)');
    const file = localPath(has('path') ? args.path : args.filePath, cwd);
    if (has('path') && has('filePath') && file !== localPath(args.filePath, cwd)) throw new Error('path and filePath disagree');
    return [file];
  }
  if (event.toolName === 'apply_patch') {
    if (Object.hasOwn(args, 'input') && Object.hasOwn(args, 'patch') && args.input !== args.patch) throw new Error('input and patch disagree');
    return patchPaths(Object.hasOwn(args, 'input') ? args.input : args.patch).map((file) => localPath(file, cwd));
  }
  throw new Error('Unsupported tool; use matcher edit|create|apply_patch');
}
function noSymlinks(base, target) {
  let current = base;
  for (const part of path.relative(base, target).split(path.sep)) {
    current = path.join(current, part);
    if (fs.lstatSync(current).isSymbolicLink()) return false;
  }
  return true;
}
function eligible(file, demo) {
  if (!within(demo, file)) return false;
  const parts = path.relative(demo, file).split(path.sep);
  if (!['src', 'test'].includes(parts[0]) || !['.js', '.json'].includes(path.extname(file))) return false;
  if (parts.some((part) => part.startsWith('.') || /^(?:node_modules|config|secrets?|credentials?)(?:\.|$)/i.test(part)) ||
      /^(?:production|credentials?|secrets?)(?:\.|$)/i.test(path.basename(file))) return false;
  if (!fs.existsSync(file)) return false; // Deleted and moved-away files need no formatting.
  if (!noSymlinks(demo, file) || !within(demo, fs.realpathSync(file))) throw new Error('Refusing a symlinked edit target');
  return fs.statSync(file).isFile();
}
function run(cli, args, cwd, milliseconds) {
  return new Promise((resolve) => {
    let output = Buffer.alloc(0);
    let timedOut = false;
    let settled = false;
    let cleanupTimer;
    const child = spawn(process.execPath, [cli, ...args], {
      cwd, shell: false, windowsHide: true, detached: process.platform !== 'win32',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const capture = (chunk) => { output = Buffer.concat([output, chunk]).subarray(-6000); };
    child.stdout.on('data', capture);
    child.stderr.on('data', capture);
    const finish = (code, error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearTimeout(cleanupTimer);
      resolve({ ok: code === 0 && !timedOut && !error, output: output.toString('utf8'), timedOut, error });
    };
    const timer = setTimeout(() => {
      timedOut = true;
      if (process.platform === 'win32') {
        spawn('taskkill.exe', ['/pid', String(child.pid), '/t', '/f'], { stdio: 'ignore', windowsHide: true })
          .on('error', () => child.kill('SIGKILL'));
      } else {
        try { process.kill(-child.pid, 'SIGKILL'); } catch { child.kill('SIGKILL'); }
      }
      cleanupTimer = setTimeout(() => {
        child.kill('SIGKILL');
        child.stdout.destroy();
        child.stderr.destroy();
        child.unref();
        finish(null, 'Timed-out process did not close promptly');
      }, 500);
    }, milliseconds);
    child.on('error', (error) => finish(null, error.message));
    child.on('close', (code) => finish(code));
  });
}
async function main() {
  let text = '';
  for await (const chunk of process.stdin) text += chunk;
  const event = JSON.parse(text);
  if (!object(event) || typeof event.cwd !== 'string' || !path.isAbsolute(event.cwd) || !fs.statSync(event.cwd).isDirectory()) {
    throw new Error('Expected an existing absolute cwd');
  }
  const cwd = fs.realpathSync(event.cwd);
  const demo = localPath(process.env.DEMO_DIR ?? 'demo-app', cwd);
  if (!within(cwd, demo)) throw new Error('DEMO_DIR must be a subdirectory of cwd');
  const format = flag('FORMAT_ON_EDIT');
  const lint = flag('LINT_ON_EDIT');
  const milliseconds = timeout();
  let changed;
  try { changed = changedPaths(event, cwd); }
  catch (error) { warning(`Skipped unknown edit shape: ${error.message}`); return {}; }
  // Unrelated edits do not need an installed demo or its dependencies.
  if (!changed.some((file) => within(demo, file))) return {};
  if (!fs.statSync(demo).isDirectory() || !noSymlinks(cwd, demo) || fs.realpathSync(demo) !== demo) {
    throw new Error('DEMO_DIR must be a real directory, not a symlink');
  }
  const files = [...new Set(changed.filter((file) => eligible(file, demo)))];
  if (!files.length || (!format && !lint)) return {};
  const prettier = path.join(demo, 'node_modules/prettier/bin/prettier.cjs');
  const eslint = path.join(demo, 'node_modules/eslint/bin/eslint.js');
  for (const [enabled, cli] of [[format, prettier], [lint && files.some((file) => file.endsWith('.js')), eslint]]) {
    if (enabled && !fs.statSync(cli).isFile()) throw new Error(`Missing local CLI ${cli}; run npm --prefix "${demo}" ci`);
  }
  const failures = [];
  if (format) {
    const result = await run(prettier, ['--write', '--', ...files], demo, milliseconds);
    if (!result.ok) failures.push(`Prettier ${result.timedOut ? 'timed out' : 'failed'}: ${result.error ?? result.output}`);
  }
  const js = files.filter((file) => file.endsWith('.js'));
  if (lint && js.length) {
    const result = await run(eslint, ['--', ...js], demo, milliseconds);
    if (!result.ok) failures.push(`ESLint ${result.timedOut ? 'timed out' : 'failed'}: ${result.error ?? result.output}`);
  }
  if (!failures.length) return {};
  const context = `After-edit checks need attention. Fix the selected demo files, then run npm --prefix "${demo}" run format:check and npm --prefix "${demo}" run lint.\n${failures.join('\n').slice(-6500)}`;
  warning(context);
  return { additionalContext: context };
}
try {
  const result = await main();
  process.stdout.write(`${JSON.stringify(result)}\n`);
} catch (error) {
  warning(`${error.message}. Checks did not complete; verify DEMO_DIR and run npm ci in the demo.`);
  process.stdout.write('{}\n');
  process.exitCode = 2;
}
