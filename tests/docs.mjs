import assert from "node:assert/strict";
import { readdir, readFile, access } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";

async function markdownFiles(directory) {
  const paths = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) paths.push(...(await markdownFiles(path)));
    else if (entry.name.endsWith(".md")) paths.push(path);
  }
  return paths;
}

const paths = ["README.md", ...(await markdownFiles("exercises")), ...(await markdownFiles("docs"))];
let links = 0;
for (const path of paths) {
  const source = await readFile(path, "utf8");
  for (const match of source.matchAll(/(?<!!)\[[^\]]+\]\(([^)]+)\)/g)) {
    const link = match[1];
    if (/^(?:https?:|mailto:)/.test(link)) continue;
    const [file, fragment] = decodeURIComponent(link).split("#");
    const target = file ? resolve(dirname(path), file) : resolve(path);
    try {
      await access(target);
    } catch {
      throw new Error(`Broken link from ${path}: ${link}`);
    }
    if (fragment) {
      const headings = [...(await readFile(target, "utf8")).matchAll(/^#{1,6}\s+(.+?)\s*$/gm)];
      const slugs = headings.map((heading) =>
        heading[1].toLowerCase().replace(/[^\p{L}\p{N}_ -]/gu, "").replace(/ /g, "-"),
      );
      assert(slugs.includes(fragment), `Missing anchor in ${path}: ${link}`);
    }
    links += 1;
  }
}
console.log(`${paths.length} learner documents and ${links} local links checked.`);
