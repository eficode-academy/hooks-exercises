export function validateConfig(config) {
  const identifier = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
  if (!config || !identifier.test(config.id ?? "")) throw new Error("Set a lowercase, hyphenated lab id in lab.json.");
  if (typeof config.title !== "string" || !config.title.trim()) throw new Error("Set a lab title in lab.json.");
  if (typeof config.description !== "string") throw new Error("Set a lab description in lab.json.");
  if (!Array.isArray(config.lessons) || !config.lessons.length) throw new Error("Add at least one lesson in lab.json.");
  const ids = new Set();
  const files = new Set();
  for (const page of [config.overview, ...config.lessons]) {
    if (!page || !identifier.test(page.id ?? "") || ids.has(page.id)) throw new Error("Each page needs a unique lowercase id.");
    if (typeof page.title !== "string" || !page.title.trim()) throw new Error(`Set a title for ${page.id}.`);
    if (typeof page.file !== "string" || !/^(?:[a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_.-]+\.md$/.test(page.file) || files.has(page.file)) {
      throw new Error(`Set a unique relative Markdown file for ${page.id}; do not use parent paths or URLs.`);
    }
    if (page !== config.overview && (!Number.isInteger(page.minutes) || page.minutes <= 0)) throw new Error(`Set positive whole minutes for ${page.id}.`);
    if (page.level !== undefined && !["core", "stretch"].includes(page.level)) throw new Error(`Set level to core or stretch for ${page.id}.`);
    ids.add(page.id);
    files.add(page.file);
  }
  return config;
}

export function lessonLink(href, page, pages, base) {
  const target = new URL(href, new URL(page.file, base));
  const match = pages.find((candidate) => {
    const url = new URL(candidate.file, base);
    return url.origin === target.origin && url.pathname === target.pathname;
  });
  if (match && !target.search) {
    return `#${match.id}${target.hash ? `/${target.hash.slice(1)}` : ""}`;
  }
  return target.href;
}

function progressKey(config, lessonId) {
  return `copilot-lab:${config.id}:progress:${lessonId}`;
}

export function readProgress(storage, config) {
  const completed = new Set();
  for (const lesson of config.lessons) {
    const raw = storage.getItem(progressKey(config, lesson.id));
    if (raw === null) continue;
    const parsed = JSON.parse(raw);
    if (typeof parsed !== "boolean") throw new Error("Invalid saved progress.");
    if (parsed) completed.add(lesson.id);
  }
  return completed;
}

export function writeProgress(storage, config, lessonId, done) {
  storage.setItem(progressKey(config, lessonId), JSON.stringify(done));
}
