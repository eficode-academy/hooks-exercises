import { access, readFile, readdir } from "node:fs/promises";
import { constants } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const events = new Set([
  "sessionStart",
  "userPromptSubmitted",
  "preToolUse",
  "postToolUse",
  "postToolUseFailure",
  "errorOccurred",
  "preCompact",
  "subagentStart",
  "subagentStop",
  "agentStop",
  "sessionEnd",
  "notification",
]);
const matchers = new Set([
  "preToolUse",
  "postToolUse",
  "subagentStart",
  "preCompact",
  "notification",
]);

export async function validateConfig(filename, root = process.cwd()) {
  const config = JSON.parse(await readFile(resolve(root, filename), "utf8"));
  if (
    config.version !== 1 ||
    !config.hooks ||
    typeof config.hooks !== "object" ||
    Array.isArray(config.hooks)
  ) {
    throw new Error(`${filename}: expected version 1 and a hooks event map`);
  }
  if (
    config.disableAllHooks !== undefined &&
    typeof config.disableAllHooks !== "boolean"
  ) {
    throw new Error(`${filename}: disableAllHooks must be a boolean`);
  }
  for (const [event, hooks] of Object.entries(config.hooks)) {
    if (!events.has(event) || !Array.isArray(hooks)) {
      throw new Error(`${filename}: unsupported exercise event or non-array: ${event}`);
    }
    for (const entry of hooks) {
      if (!entry || entry.type !== "command") {
        throw new Error(`${filename}: use command hooks for these exercises`);
      }
      if (
        entry.timeoutSec !== undefined &&
        (!Number.isFinite(entry.timeoutSec) || entry.timeoutSec <= 0)
      ) {
        throw new Error(`${filename}: timeoutSec must be positive`);
      }
      if (entry.matcher !== undefined) {
        if (!matchers.has(event) || typeof entry.matcher !== "string") {
          throw new Error(`${filename}: matcher is not supported on ${event}`);
        }
        new RegExp(`^(?:${entry.matcher})$`);
      }
      if (
        entry.env !== undefined &&
        (!entry.env ||
          Array.isArray(entry.env) ||
          typeof entry.env !== "object" ||
          Object.values(entry.env).some((value) => typeof value !== "string"))
      ) {
        throw new Error(`${filename}: env must map names to strings`);
      }
      for (const shell of ["bash", "powershell"]) {
        const command = entry[shell] ?? entry.command;
        if (typeof command !== "string") {
          throw new Error(`${filename}: provide both Bash and PowerShell commands`);
        }
        const reference = command.match(/(?:^|\s)(?:"([^"]+\.(?:sh|ps1))"|'([^']+\.(?:sh|ps1))'|([^"'\s]+\.(?:sh|ps1)))(?:\s|$)/);
        const script = reference?.[1] ?? reference?.[2] ?? reference?.[3];
        if (!script) {
          throw new Error(`${filename}: ${shell} must reference a provided .sh/.ps1 script`);
        }
        await access(resolve(root, entry.cwd ?? ".", script), constants.R_OK);
      }
    }
  }
  return config;
}

async function solutionConfigs(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = `${directory}/${entry.name}`;
    if (entry.isDirectory()) files.push(...(await solutionConfigs(path)));
    else if (entry.name.endsWith(".json")) files.push(path);
  }
  return files;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const files =
      process.argv.length > 2
        ? process.argv.slice(2)
        : await solutionConfigs("solutions");
    for (const file of files) {
      await validateConfig(file);
      console.log(`Valid exercise config: ${file}`);
    }
    console.log("Structure and script paths checked; use try-hook.mjs to test your actual wiring.");
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
