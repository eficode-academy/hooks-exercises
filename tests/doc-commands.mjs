import assert from "node:assert/strict";
import {
  cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync,
  rmSync, symlinkSync, writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const shell = process.argv[process.argv.indexOf("--shell") + 1];
assert(["bash", "powershell"].includes(shell), "Use --shell bash or --shell powershell");
const temporary = mkdtempSync(join(tmpdir(), "copilot documented commands "));
const executable = shell === "bash" ? "bash" : "pwsh";
const blocks = (filename) => [...readFileSync(filename, "utf8").matchAll(
  new RegExp("```" + shell + "\\n([\\s\\S]*?)```", "g"),
)].map((match) => match[1]);
function run(script) {
  const args = shell === "bash" ? ["-c", script] : ["-NoProfile", "-NonInteractive", "-Command", script];
  const result = spawnSync(executable, args, {
    cwd: temporary, encoding: "utf8", timeout: 90000,
  });
  if (result.error) throw result.error;
  return result;
}

try {
  for (const folder of ["scripts", "solutions", "fixtures", "tests", "demo-app"]) {
    cpSync(join(root, folder), join(temporary, folder), {
      recursive: true,
      filter: (path) => !path.split(/[\\/]/).includes("node_modules"),
    });
  }
  symlinkSync(join(root, "demo-app/node_modules"), join(temporary, "demo-app/node_modules"), "junction");
  mkdirSync(join(temporary, ".github/hooks"), { recursive: true });
  for (const folder of readdirSync(join(root, "solutions"))) {
    for (const name of readdirSync(join(root, "solutions", folder))) {
      if (name.endsWith(".json")) {
        cpSync(join(root, "solutions", folder, name), join(temporary, ".github/hooks", name));
      }
    }
  }
  assert.equal(spawnSync("git", ["init", "-q"], { cwd: temporary }).status, 0);
  const cart = join(temporary, "demo-app/src/cart.js");
  const backup = `${cart}.exercise-backup`;
  const original = readFileSync(cart, "utf8");
  let count = 0;
  for (const name of readdirSync(join(root, "exercises")).filter((name) => /^\d.*\.md$/.test(name)).sort()) {
    for (const block of blocks(join(root, "exercises", name))) {
      const result = run(block);
      assert.equal(result.status, 0, `${name}:\n${result.stderr}\n${result.stdout}`);
      assert.equal(readFileSync(cart, "utf8"), original, `${name} must restore the cart`);
      assert(!existsSync(backup), `${name} must clean its successfully restored backup`);
      if (name.startsWith("04") && block.includes("fixtures/edit-examples/messy")) {
        assert(result.stdout.includes("no-unused-vars"), `Documented lint fixture must demonstrate feedback:\n${result.stderr}\n${result.stdout}`);
      }
      count += 1;
    }
  }
  const gateBlock = blocks(join(root, "exercises/05-quality-gate.md")).find((block) =>
    block.includes("fixtures/broken-code/cart.js"));
  writeFileSync(backup, "existing backup: preserve me\n");
  run(gateBlock);
  assert.equal(readFileSync(backup, "utf8"), "existing backup: preserve me\n");
  assert.equal(readFileSync(cart, "utf8"), original);
  rmSync(backup);
  const rejectRestore = shell === "bash"
    ? 'copies=0\ncp() { copies=$((copies + 1)); if test "$copies" -eq 3; then return 1; fi; command cp "$@"; }\n'
    : "$script:copies = 0\nfunction Copy-Item { [CmdletBinding()] param([string]$Path, [string]$Destination)\n$script:copies++; if ($script:copies -eq 3) { throw 'Simulated restore failure' }; Microsoft.PowerShell.Management\\Copy-Item @PSBoundParameters }\n";
  run(rejectRestore + gateBlock);
  assert.equal(readFileSync(backup, "utf8"), original, "Failed restoration must retain the recoverable backup");
  assert.notEqual(readFileSync(cart, "utf8"), original, "Restore failure simulation must actually fail");
  writeFileSync(cart, readFileSync(backup));
  rmSync(backup);
  console.log(`${shell}: ${count} documented blocks ran verbatim; existing backup and failed-restore preservation passed.`);
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
