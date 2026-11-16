import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';

const warning = (message) => process.stderr.write(`quality-gate: ${message}\n`);
const object = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
function within(base, file) {
  const relative = path.relative(base, file);
  return relative !== '' && !relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative);
}
function localPath(value, cwd) {
  if (typeof value !== 'string' || value.length === 0 || /[\x00-\x1f]/.test(value)) throw new Error('Invalid configured path');
  if (process.platform !== 'win32' && /^(?:[A-Za-z]:|\\\\)/.test(value)) throw new Error('Foreign absolute path');
  return path.resolve(cwd, value.replaceAll('\\', '/'));
}
function noSymlinks(base, target, allowMissing = false) {
  let current = base;
  for (const part of path.relative(base, target).split(path.sep)) {
    current = path.join(current, part);
    if (allowMissing && !fs.existsSync(current)) {
      // lstat still rejects dangling symlinks.
      try { if (fs.lstatSync(current).isSymbolicLink()) return false; }
      catch (error) { if (error.code !== 'ENOENT') throw error; }
      continue;
    }
    if (fs.lstatSync(current).isSymbolicLink()) return false;
  }
  return true;
}
function npmCli() {
  const nodeDir = path.dirname(process.execPath);
  const candidates = [
    path.join(nodeDir, 'node_modules/npm/bin/npm-cli.js'),
    path.resolve(nodeDir, '../lib/node_modules/npm/bin/npm-cli.js'),
  ];
  // POSIX npm is normally a symlink to npm-cli.js. Windows uses the nodeDir candidate.
  for (const directory of (process.env.PATH ?? '').split(path.delimiter)) {
    if (!directory) continue;
    for (const name of ['npm', 'npm.cmd']) {
      try {
        const resolved = fs.realpathSync(path.join(directory, name));
        if (path.basename(resolved) === 'npm-cli.js') candidates.push(resolved);
        candidates.push(path.join(directory, 'node_modules/npm/bin/npm-cli.js'));
      } catch { /* Continue to other installed npm locations. */ }
    }
  }
  const cli = candidates.find((candidate) => {
    try { return fs.statSync(candidate).isFile(); } catch { return false; }
  });
  if (!cli) throw new Error('Cannot locate npm-cli.js; install Node.js with npm');
  return cli;
}
function run(cli, step, cwd, milliseconds) {
  return new Promise((resolve) => {
    let output = Buffer.alloc(0);
    let timedOut = false;
    let settled = false;
    let cleanupTimer;
    const child = spawn(process.execPath, [cli, 'run', step, '--ignore-scripts'], {
      cwd, shell: false, windowsHide: true, detached: process.platform !== 'win32',
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, NO_COLOR: '1', FORCE_COLOR: '0' },
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
function saveState(directory, step, status) {
  // This is a last-result record, never a cache or an input to loop prevention.
  fs.mkdirSync(directory, { recursive: true });
  const target = path.join(directory, 'last-check.json');
  try { if (fs.lstatSync(target).isSymbolicLink()) throw new Error('State file must not be a symlink'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  fs.writeFileSync(target, `${JSON.stringify({ step, status, timestamp: new Date().toISOString() })}\n`, { flag: 'w', mode: 0o600 });
}
async function main() {
  let input = '';
  for await (const chunk of process.stdin) input += chunk;
  const event = JSON.parse(input);
  if (!object(event) || typeof event.cwd !== 'string' || !path.isAbsolute(event.cwd) || !fs.statSync(event.cwd).isDirectory()) {
    throw new Error('Expected an existing absolute cwd');
  }
  if (Object.hasOwn(event, 'stop_hook_active') && typeof event.stop_hook_active !== 'boolean') {
    throw new Error('stop_hook_active must be a boolean when present');
  }
  const cwd = fs.realpathSync(event.cwd);
  const demo = localPath(process.env.DEMO_DIR ?? 'demo-app', cwd);
  if (!within(cwd, demo) || !noSymlinks(cwd, demo) || !fs.statSync(demo).isDirectory()) {
    throw new Error('DEMO_DIR must be a real subdirectory of cwd, not a symlink');
  }
  const steps = (process.env.CHECK_STEPS ?? 'format:check;lint;test').split(';');
  if (steps.length === 0 || steps.length > 3 || new Set(steps).size !== steps.length ||
      steps.some((step) => !['format:check', 'lint', 'test'].includes(step))) {
    throw new Error('CHECK_STEPS must contain 1–3 distinct labels: format:check;lint;test (semicolon-delimited)');
  }
  const seconds = process.env.CHECK_TIMEOUT_SEC ?? '10';
  if (!/^(?:[1-9]|1[0-5])$/.test(seconds)) throw new Error('CHECK_TIMEOUT_SEC must be an integer from 1 to 15');
  const state = localPath(process.env.HOOK_STATE_DIR ?? '.hooks-state', cwd);
  if (!within(cwd, state) || !noSymlinks(cwd, state, true)) throw new Error('HOOK_STATE_DIR must be a non-symlink subdirectory of cwd');
  const pkg = JSON.parse(fs.readFileSync(path.join(demo, 'package.json'), 'utf8'));
  if (!object(pkg.scripts) || steps.some((step) => typeof pkg.scripts[step] !== 'string' || !pkg.scripts[step])) {
    throw new Error('package.json must define each selected format:check/lint/test npm script');
  }
  if (!fs.statSync(path.join(demo, 'node_modules')).isDirectory()) throw new Error('Missing local dependencies; run npm ci in DEMO_DIR');
  for (const [step, cli] of [
    ['format:check', 'node_modules/prettier/bin/prettier.cjs'],
    ['lint', 'node_modules/eslint/bin/eslint.js'],
  ]) {
    if (steps.includes(step) && !fs.statSync(path.join(demo, cli)).isFile()) throw new Error(`Missing ${cli}; run npm ci in DEMO_DIR`);
  }
  const cli = npmCli();
  for (const step of steps) {
    const result = await run(cli, step, demo, Number(seconds) * 1000);
    saveState(state, step, result.timedOut ? 'timeout' : result.ok ? 'passed' : 'failed');
    if (!result.ok) {
      const reason = `Quality gate: ${step} ${result.timedOut ? 'timed out' : 'failed'}. Fix the demo, then run npm --prefix "${demo}" run ${step}.\n${result.error ?? result.output}`;
      if (event.stop_hook_active === true) {
        warning(`${reason}\nChecks ran again, but the gate will not request another continuation. Do not claim checks passed.`);
        process.exitCode = 2;
        return {};
      }
      return { decision: 'block', reason };
    }
  }
  return {};
}
try {
  const result = await main();
  process.stdout.write(`${JSON.stringify(result)}\n`);
} catch (error) {
  warning(`${error.message}. Checks did not complete; verify configuration and install the demo dependencies.`);
  process.stdout.write('{}\n');
  process.exitCode = 2;
}
