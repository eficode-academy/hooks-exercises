import { spawn, spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { validateConfig } from "./validate-configs.mjs";

export async function tryHook(filename, eventName, event, options = {}) {
  const root = options.root ?? process.cwd();
  const shell = options.shell ?? (process.platform === "win32" ? "powershell" : "bash");
  if (!["bash", "powershell"].includes(shell)) {
    throw new Error("Choose --shell bash or --shell powershell");
  }
  const config = await validateConfig(filename, root);
  if (config.disableAllHooks === true) return [];
  const results = [];
  for (const entry of config.hooks[eventName] ?? []) {
    if (entry.matcher !== undefined) {
      const field =
        eventName === "notification"
          ? event.notification_type
          : eventName === "preCompact"
            ? event.trigger
            : eventName === "subagentStart"
              ? event.agentName
              : event.toolName;
      if (typeof field !== "string" || !new RegExp(`^(?:${entry.matcher})$`).test(field)) {
        continue;
      }
    }
    const command = entry[shell] ?? entry.command;
    const argv =
      shell === "bash"
        ? ["-c", command]
        : ["-NoProfile", "-NonInteractive", "-Command", command];
    const child = spawn(shell === "bash" ? "bash" : "pwsh", argv, {
      cwd: resolve(root, entry.cwd ?? "."),
      env: { ...process.env, ...entry.env },
      stdio: ["pipe", "pipe", "pipe"],
      detached: process.platform !== "win32",
    });
    const result = await new Promise((accept, reject) => {
      let stdout = "";
      let stderr = "";
      let timedOut = false;
      let outputTruncated = false;
      const timer = setTimeout(() => {
        timedOut = true;
        if (process.platform === "win32") {
          spawnSync("taskkill", ["/PID", String(child.pid), "/T", "/F"], { stdio: "ignore" });
        } else {
          try { process.kill(-child.pid, "SIGKILL"); }
          catch (error) { if (error.code !== "ESRCH") reject(error); }
        }
      }, (entry.timeoutSec ?? 30) * 1000);
      child.stdout.on("data", (chunk) => {
        outputTruncated ||= stdout.length + chunk.length > 131072;
        stdout = (stdout + chunk).slice(0, 131072);
      });
      child.stderr.on("data", (chunk) => {
        outputTruncated ||= stderr.length + chunk.length > 131072;
        stderr = (stderr + chunk).slice(0, 131072);
      });
      child.on("error", (error) => { clearTimeout(timer); reject(error); });
      child.on("close", (status) => {
        clearTimeout(timer);
        accept({ status, stdout, stderr, timedOut, outputTruncated });
      });
      child.stdin.on("error", (error) => {
        if (error.code !== "EPIPE") reject(error);
      });
      child.stdin.end(JSON.stringify(event));
    });
    results.push(result);
  }
  return results;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const [config, event, fixture, flag, shell] = process.argv.slice(2);
    if (!config || !event || !fixture || (flag && flag !== "--shell")) {
      throw new Error("Usage: node tests/try-hook.mjs CONFIG EVENT FIXTURE [--shell bash|powershell]");
    }
    const input = JSON.parse(await readFile(fixture, "utf8"));
    input.cwd = resolve(input.cwd ?? ".");
    const results = await tryHook(config, event, input, { shell });
    console.error(`Offline ${event}: ${results.length} matching hook(s); no Copilot tool was executed.`);
    for (const result of results) {
      process.stdout.write(result.stdout);
      process.stderr.write(result.stderr);
      console.error(`Hook exit=${result.status}, timedOut=${result.timedOut}`);
      if (result.outputTruncated) console.error("Hook output exceeded the offline runner's 128 KiB stream limit.");
      if (result.timedOut || result.outputTruncated || (result.status !== 0 && result.status !== 2)) process.exitCode = 1;
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
