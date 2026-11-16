import assert from "node:assert/strict";
import {
  cpSync, existsSync, mkdtempSync, mkdirSync, readFileSync, readdirSync,
  renameSync, rmSync, symlinkSync, writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { tryHook } from "./try-hook.mjs";
import { validateConfig } from "./validate-configs.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const shell = process.argv[process.argv.indexOf("--shell") + 1];
assert(["bash", "powershell"].includes(shell), "Use --shell bash or --shell powershell");
assert(existsSync(join(root, "demo-app/node_modules")), "Run npm ci --prefix demo-app first");
const temporary = mkdtempSync(join(tmpdir(), "copilot hooks fixture "));
const extension = shell === "bash" ? "sh" : "ps1";
const executable = shell === "bash" ? "/bin/bash" :
  spawnSync("pwsh", ["-NoProfile", "-Command", "[Environment]::ProcessPath"], { encoding: "utf8" }).stdout.trim();
let assertions = 0;

function command(program, args, options = {}) {
  const result = spawnSync(program, args, {
    cwd: temporary, encoding: "utf8", timeout: 90000, ...options,
  });
  if (result.error) throw result.error;
  return result;
}

function event(filename) {
  const payload = JSON.parse(readFileSync(join(root, "fixtures/events", filename), "utf8"));
  payload.cwd = temporary;
  return payload;
}

function invoke(folder, script, payload, args = [], env = {}) {
  const path = join(temporary, "scripts", folder, `${script}.${extension}`);
  const parameters = shell === "bash" ? [path, ...args] : ["-NoProfile", "-File", path, ...args];
  const result = command(executable, parameters, {
    input: typeof payload === "string" ? payload : JSON.stringify(payload),
    env: { ...process.env, ...env },
  });
  assert.notEqual(result.signal, "SIGTERM", `Hook timed out: ${folder}/${script}`);
  return result;
}

function response(result, status = 0) {
  assert.equal(result.status, status, result.stderr + result.stdout);
  const output = JSON.parse(result.stdout);
  assert(output && typeof output === "object" && !Array.isArray(output));
  assertions += 1;
  return output;
}

function empty(result, status = 0) {
  assert.deepEqual(response(result, status), {});
}

function treeText(directory) {
  if (!existsSync(directory)) return "";
  return readdirSync(directory, { withFileTypes: true })
    .map((entry) => entry.isDirectory()
      ? treeText(join(directory, entry.name))
      : readFileSync(join(directory, entry.name), "utf8"))
    .join("\n");
}

try {
  cpSync(join(root, "scripts"), join(temporary, "scripts"), { recursive: true });
  cpSync(join(root, "solutions"), join(temporary, "solutions"), { recursive: true });
  cpSync(join(root, "demo-app"), join(temporary, "demo-app"), {
    recursive: true,
    filter: (path) => !path.split(/[\\/]/).includes("node_modules"),
  });
  symlinkSync(join(root, "demo-app/node_modules"), join(temporary, "demo-app/node_modules"), "junction");
  assert.equal(command("git", ["init", "-q"]).status, 0);

  const fixtures = {
    sessionStart: "sessionStart-new.json",
    userPromptSubmitted: "userPromptSubmitted.json",
    preToolUse: "preToolUse-edit-protected.json",
    postToolUse: "postToolUse-edit.json",
    postToolUseFailure: "postToolUseFailure-missing-file.json",
    errorOccurred: "errorOccurred.json",
    preCompact: "preCompact.json",
    subagentStart: "subagentStart.json",
    subagentStop: "subagentStop.json",
    agentStop: "agentStop.json",
    sessionEnd: "sessionEnd.json",
    notification: "notification.json",
  };
  for (const [name, fixture] of Object.entries(fixtures)) {
    empty(invoke("01-activity-log", "log", event(fixture), [name]));
  }
  const activityText = treeText(join(temporary, ".hooks-state"));
  assert(!activityText.includes("DO-NOT-LOG"), "Sensitive fixture values must not enter the log");
  for (const name of Object.keys(fixtures)) assert(activityText.includes(name), `Missing ${name} record`);
  const malformedLog = invoke("01-activity-log", "log", "DO-NOT-LOG not JSON", ["preToolUse"]);
  assert(malformedLog.stderr.length > 0, "Malformed logging input must be diagnosed");
  assert(!treeText(join(temporary, ".hooks-state")).includes("DO-NOT-LOG"));
  const timeline = invoke("01-activity-log", "show-log", "");
  assert.equal(timeline.status, 0, timeline.stderr);
  assert(timeline.stdout.includes("preToolUse"));
  empty(invoke("08-notifications", "notify", event("agentStop.json")));
  empty(invoke("08-notifications", "notify", event("notification.json")));

  const brief = response(invoke("02-session-context", "briefing", event("sessionStart-new.json"), ["sessionStart"]));
  assert(brief.additionalContext.includes("demo-app"));
  assert(brief.additionalContext.includes("test"));
  assert(brief.additionalContext.length <= 12000);
  const subagentBrief = response(invoke("02-session-context", "briefing", event("subagentStart.json"), ["subagentStart"]));
  assert(subagentBrief.additionalContext.includes("cent"));

  const protectedEvent = event("preToolUse-edit-protected.json");
  assert.equal(response(invoke("03-guardrails", "protect-files", protectedEvent)).permissionDecision, "deny");
  const relative = structuredClone(protectedEvent);
  relative.toolArgs.path = "demo-app/config/../config/production.json";
  assert.equal(response(invoke("03-guardrails", "protect-files", relative)).permissionDecision, "deny");
  relative.toolArgs.path = join(temporary, "demo-app/config/production.json");
  assert.equal(response(invoke("03-guardrails", "protect-files", relative)).permissionDecision, "deny");
  empty(invoke("03-guardrails", "protect-files", event("preToolUse-edit-source.json")));
  empty(invoke("03-guardrails", "protect-files", event("preToolUse-read.json")));
  const patch = {
    ...protectedEvent,
    toolName: "apply_patch",
    toolArgs: { input: "*** Begin Patch\n*** Update File: demo-app/config/production.json\n@@\n-old\n+new\n*** End Patch" },
  };
  assert.equal(response(invoke("03-guardrails", "protect-files", patch)).permissionDecision, "deny");
  const guard = response(invoke("03-guardrails", "guard-commands", event("preToolUse-dangerous-command.json")));
  assert.equal(guard.permissionDecision, "deny");
  empty(invoke("03-guardrails", "guard-commands", event("preToolUse-safe-command.json")));

  const editedFile = join(temporary, "demo-app/src/hook-example.js");
  const editedEvent = event("postToolUse-edit.json");
  editedEvent.toolArgs.path = "demo-app/src/hook-example.js";
  writeFileSync(editedFile, "export const example={value:1}\n");
  const formatted = response(invoke("04-format-lint", "after-edit", editedEvent));
  assert(!formatted.additionalContext || !formatted.additionalContext.includes("failed"), JSON.stringify(formatted));
  assert(readFileSync(editedFile, "utf8").includes("example = { value: 1 };"), "Formatter did not update edited file");
  writeFileSync(editedFile, "const unused = 1;\nexport const example = { value: 1 };\n");
  const linted = response(invoke("04-format-lint", "after-edit", editedEvent));
  assert(linted.additionalContext && /unused|lint/i.test(linted.additionalContext), "Lint failure needs agent context");
  assert(linted.additionalContext.length <= 12000);
  writeFileSync(editedFile, "export const example={value:1}\n");
  empty(invoke("04-format-lint", "after-edit", event("postToolUse-read.json")));
  assert.equal(readFileSync(editedFile, "utf8"), "export const example={value:1}\n", "Read event must not format");
  empty(invoke("04-format-lint", "after-edit", editedEvent, [], {
    FORMAT_ON_EDIT: "false", LINT_ON_EDIT: "false",
  }));
  assert.equal(readFileSync(editedFile, "utf8"), "export const example={value:1}\n", "Disabled edit checks must not mutate");
  empty(invoke("04-format-lint", "after-edit", "not-json"), 2);
  rmSync(editedFile);

  empty(invoke("05-quality-gate", "gate", event("agentStop.json")));
  empty(invoke("05-quality-gate", "gate", event("agentStop-retry.json")));
  const original = readFileSync(join(temporary, "demo-app/src/cart.js"));
  cpSync(join(root, "fixtures/broken-code/cart.js"), join(temporary, "demo-app/src/cart.js"));
  const gate = response(invoke("05-quality-gate", "gate", event("agentStop.json"), [], { CHECK_STEPS: "test" }));
  assert.equal(gate.decision, "block");
  assert(/test/i.test(gate.reason));
  const retry = invoke("05-quality-gate", "gate", event("agentStop-retry.json"), [], { CHECK_STEPS: "test" });
  empty(retry, 2);
  assert(retry.stderr.length > 0);
  writeFileSync(join(temporary, "demo-app/src/cart.js"), original);
  writeFileSync(editedFile, "const unused = 1;\nexport const example = 1;\n");
  assert.equal(response(invoke("05-quality-gate", "gate", event("agentStop.json"), [], { CHECK_STEPS: "lint" })).decision, "block");
  writeFileSync(editedFile, "export const example={value:1}\n");
  assert.equal(response(invoke("05-quality-gate", "gate", event("agentStop.json"), [], { CHECK_STEPS: "format:check" })).decision, "block");
  rmSync(editedFile);
  empty(invoke("05-quality-gate", "gate", event("agentStop-retry.json")));
  empty(invoke("05-quality-gate", "gate", "not-json"), 2);
  empty(invoke("05-quality-gate", "gate", event("agentStop.json"), [], { CHECK_STEPS: "arbitrary-command" }), 2);
  renameSync(join(temporary, "demo-app/node_modules"), join(temporary, "demo-app/dependencies-hidden"));
  try {
    const missingDeps = invoke("05-quality-gate", "gate", event("agentStop.json"));
    empty(missingDeps, 2);
    assert(/dependenc|ENOENT|npm ci/i.test(missingDeps.stderr), missingDeps.stderr);
  } finally {
    renameSync(join(temporary, "demo-app/dependencies-hidden"), join(temporary, "demo-app/node_modules"));
  }
  const savedPackage = readFileSync(join(temporary, "demo-app/package.json"), "utf8");
  const hangingPackage = JSON.parse(savedPackage);
  hangingPackage.scripts.test = 'node -e "setInterval(() => {}, 1000)"';
  writeFileSync(join(temporary, "demo-app/package.json"), JSON.stringify(hangingPackage));
  const began = Date.now();
  const timeoutGate = response(invoke("05-quality-gate", "gate", event("agentStop.json"), [], {
    CHECK_STEPS: "test", CHECK_TIMEOUT_SEC: "1",
  }));
  assert.equal(timeoutGate.decision, "block");
  assert(/timed out/i.test(timeoutGate.reason));
  assert(Date.now() - began < 6000, "One-second timeout must actually bound execution");
  writeFileSync(join(temporary, "demo-app/package.json"), savedPackage);
  empty(invoke("05-quality-gate", "gate", event("agentStop.json")));

  const missingToolPath = join(temporary, "empty-tools");
  mkdirSync(missingToolPath);
  if (shell === "bash") {
    symlinkSync(process.execPath, join(missingToolPath, "node"));
    const missingJq = invoke("05-quality-gate", "gate", event("agentStop.json"), [], { PATH: missingToolPath });
    empty(missingJq, 2);
    assert(/jq is required/i.test(missingJq.stderr));
  } else {
    const missingNode = invoke("05-quality-gate", "gate", event("agentStop.json"), [], { PATH: missingToolPath });
    empty(missingNode, 2);
    assert(/node/i.test(missingNode.stderr));
  }

  const failureEvent = event("postToolUseFailure-missing-file.json");
  for (let count = 1; count <= 3; count += 1) {
    const recovery = invoke("06-failure-recovery", "recover", failureEvent, ["postToolUseFailure"]);
    const guidance = response(recovery).additionalContext;
    assert(typeof guidance === "string" && guidance.length > 10, recovery.stdout);
    assert(!guidance.includes("DO-NOT-LOG"));
    if (count === 1) assert(/Category: file-not-found/.test(guidance), guidance);
    if (count === 3) assert(/stop|summari|human|user/i.test(guidance), guidance);
  }
  empty(invoke("06-failure-recovery", "recover", event("postToolUse-read.json"), ["postToolUse"]));
  const recovered = invoke("06-failure-recovery", "recover", event("postToolUseFailure-missing-script.json"), ["postToolUseFailure"]);
  assert(/npm|script/i.test(response(recovered).additionalContext), recovered.stdout);
  empty(invoke("06-failure-recovery", "recover", event("errorOccurred.json"), ["errorOccurred"]));
  assert(!treeText(join(temporary, ".hooks-state")).includes("DO-NOT-LOG"), "State must exclude raw errors");

  empty(invoke("07-session-recovery", "checkpoint", event("sessionStart-new.json"), ["sessionStart"]));
  empty(invoke("07-session-recovery", "checkpoint", event("preCompact.json"), ["preCompact"]));
  const checkpoint = join(temporary, ".hooks-state/checkpoint.json");
  assert(existsSync(checkpoint), "preCompact should save its artifact");
  const resumed = response(invoke("07-session-recovery", "checkpoint", event("sessionStart-resume.json"), ["sessionStart"]));
  assert(resumed.additionalContext && resumed.additionalContext.length <= 12000);
  assert(!readFileSync(checkpoint, "utf8").includes("DO-NOT-LOG"));

  const active = ".github/hooks/learner.json";
  mkdirSync(join(temporary, ".github/hooks"), { recursive: true });
  const learner = {
    version: 1,
    hooks: {
      preToolUse: [{
        type: "command", matcher: "edit|create|apply_patch",
        bash: "bash scripts/03-guardrails/protect-files.sh",
        powershell: "pwsh -NoProfile -File scripts/03-guardrails/protect-files.ps1",
        env: { PROTECTED_PATHS: "demo-app/config/production.json" }, timeoutSec: 5,
      }],
    },
  };
  writeFileSync(join(temporary, active), JSON.stringify(learner));
  await validateConfig(active, temporary);
  let actual = await tryHook(active, "preToolUse", protectedEvent, { root: temporary, shell });
  assert.equal(actual.length, 1);
  assert.equal(response(actual[0]).permissionDecision, "deny");
  actual = await tryHook(active, "preToolUse", event("preToolUse-read.json"), { root: temporary, shell });
  assert.equal(actual.length, 0, "Matcher negative control");
  actual = await tryHook(active, "sessionStart", event("sessionStart-new.json"), { root: temporary, shell });
  assert.equal(actual.length, 0, "Wrong event must not invoke a hook");
  cpSync(join(temporary, "scripts/03-guardrails"), join(temporary, "scripts/quoted guard"), { recursive: true });
  learner.hooks.preToolUse[0].bash = 'bash "scripts/quoted guard/protect-files.sh"';
  learner.hooks.preToolUse[0].powershell = 'pwsh -NoProfile -File "scripts/quoted guard/protect-files.ps1"';
  writeFileSync(join(temporary, active), JSON.stringify(learner));
  actual = await tryHook(active, "preToolUse", protectedEvent, { root: temporary, shell });
  assert.equal(response(actual[0]).permissionDecision, "deny", "Quoted script paths must work");
  learner.disableAllHooks = true;
  writeFileSync(join(temporary, active), JSON.stringify(learner));
  assert.deepEqual(await tryHook(active, "preToolUse", protectedEvent, { root: temporary, shell }), []);
  learner.hooks.preToolUse[0].bash = "bash scripts/no-such-script.sh";
  writeFileSync(join(temporary, active), JSON.stringify(learner));
  await assert.rejects(validateConfig(active, temporary));
  console.log(`${shell}: ${assertions} JSON responses plus privacy, formatting, lint, test, recovery, checkpoint and actual-config controls passed.`);
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
