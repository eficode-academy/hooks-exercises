import { validateConfig, lessonLink, readProgress, writeProgress } from "./core.js";

const byId = (id) => document.getElementById(id);
const content = byId("content");
const menu = byId("lesson-menu");
const footer = byId("completion");
const viewerDirectory = new URL(".", location.href);
const contentRoot = viewerDirectory.pathname.replace(/\/$/, "").endsWith("/site")
  ? new URL("../", viewerDirectory)
  : viewerDirectory;
let config;
let pages = [];
let completed = new Set();
let active;
let pending;
let revision = 0;
let loaded = false;
const warnings = new Map();
const unsaved = new Map();

document.querySelector(".skip-link").onclick = (event) => {
  event.preventDefault();
  content.focus();
  content.scrollIntoView({ block: "start" });
};

async function readFile(file, signal) {
  let response;
  try {
    response = await fetch(file, { signal });
  } catch (error) {
    throw new Error(`Cannot load ${file}. Check your connection and local HTTP server, then reload.`, { cause: error });
  }
  if (!response.ok) throw new Error(`Cannot load ${file} (HTTP ${response.status}). Check the file path in lab.json and serve the lab over HTTP.`);
  return response.text();
}

function warn(key, message, error) {
  console.warn(message, error);
  warnings.set(key, message);
  const notice = byId("storage-warning");
  notice.textContent = [...warnings.values()].join(" ");
  notice.hidden = false;
}

function errorPanel(message) {
  content.replaceChildren();
  const panel = document.createElement("div");
  panel.className = "notice";
  panel.setAttribute("role", "alert");
  const text = document.createElement("p");
  text.textContent = message;
  const reload = document.createElement("button");
  reload.type = "button";
  reload.textContent = "Reload viewer";
  reload.onclick = () => location.reload();
  panel.append(text, reload);
  content.append(panel);
  content.setAttribute("aria-busy", "false");
  footer.replaceChildren();
}

function setTheme(theme) {
  document.documentElement.dataset.theme = theme;
  const next = theme === "dark" ? "light" : "dark";
  byId("theme-toggle").textContent = `${next === "dark" ? "Dark" : "Light"} theme`;
  byId("theme-toggle").setAttribute("aria-label", `Switch to ${next} theme`);
}

setTheme(matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
try {
  const saved = localStorage.getItem("copilot-lab:theme");
  if (saved === "dark" || saved === "light") setTheme(saved);
} catch (error) {
  warn("theme", "Theme preference cannot be saved in this browser.", error);
}
byId("theme-toggle").onclick = () => {
  setTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
  try {
    localStorage.setItem("copilot-lab:theme", document.documentElement.dataset.theme);
  } catch (error) {
    warn("theme", "Theme preference cannot be saved in this browser.", error);
  }
};
byId("theme-toggle").disabled = false;
byId("menu-toggle").onclick = () => {
  const open = menu.classList.toggle("open");
  byId("menu-toggle").setAttribute("aria-expanded", String(open));
  byId("menu-toggle").textContent = open ? "Hide other lessons" : "Show all lessons";
};

function renderNavigation() {
  menu.replaceChildren();
  pages.forEach((page, index) => {
    const item = document.createElement("li");
    const link = document.createElement("a");
    link.className = `lesson${completed.has(page.id) ? " done" : ""}`;
    link.href = `#${page.id}`;
    if (page.id === active?.id) link.setAttribute("aria-current", "page");
    const number = document.createElement("span");
    number.className = "lesson-number";
    number.textContent = index === 0 ? "-" : completed.has(page.id) ? "\u2713" : String(index);
    number.setAttribute("aria-hidden", "true");
    const title = document.createElement("span");
    title.textContent = page.title;
    link.append(number, title);
    if (page.level) {
      const level = document.createElement("span");
      level.className = `lesson-level ${page.level}`;
      level.textContent = page.level === "core" ? "Core" : "Stretch";
      link.append(level);
    }
    if (page.minutes) {
      const duration = document.createElement("span");
      duration.className = "lesson-time";
      duration.textContent = `${page.minutes} min`;
      link.append(duration);
    }
    if (completed.has(page.id)) {
      const state = document.createElement("span");
      state.className = "sr-only";
      state.textContent = " (complete)";
      link.append(state);
    }
    item.append(link);
    menu.append(item);
  });
  byId("progress-text").textContent = `${completed.size} of ${config.lessons.length} complete`;
  byId("progress").max = config.lessons.length;
  byId("progress").value = completed.size;
}

function renderFooter() {
  footer.replaceChildren();
  const index = pages.indexOf(active);
  if (index > 0) {
    const button = document.createElement("button");
    const done = completed.has(active.id);
    button.type = "button";
    button.className = done ? "" : "primary";
    button.textContent = done ? "Mark this part incomplete" : "Mark this part complete";
    button.setAttribute("aria-pressed", String(done));
    button.onclick = () => {
      const done = !completed.has(active.id);
      if (done) completed.add(active.id);
      else completed.delete(active.id);
      try {
        writeProgress(localStorage, config, active.id, done);
        unsaved.delete(active.id);
      } catch (error) {
        unsaved.set(active.id, done);
        warn("progress", "Progress is not saved. Keep this tab open; reloading or closing it may lose changes. Allow browser storage to save progress.", error);
      }
      renderNavigation();
      renderFooter();
      footer.querySelector("button").focus();
      byId("announcement").textContent = byId("progress-text").textContent;
    };
    footer.append(button);
  }
  if (index > 0) {
    const previous = document.createElement("a");
    previous.href = `#${pages[index - 1].id}`;
    previous.textContent = "Previous";
    footer.append(previous);
  }
  if (pages[index + 1]) {
    const next = document.createElement("a");
    next.href = `#${pages[index + 1].id}`;
    next.textContent = `Next: ${pages[index + 1].title}`;
    footer.append(next);
  }
}

function enhance(page) {
  const used = new Set();
  content.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach((heading) => {
    const base = heading.textContent.toLowerCase().trim().replace(/[^\p{L}\p{N}\s-]/gu, "").replace(/\s+/g, "-") || "section";
    let id = base;
    let suffix = 1;
    while (used.has(id)) id = `${base}-${suffix++}`;
    used.add(id);
    heading.id = id;
    heading.tabIndex = -1;
  });
  content.querySelectorAll("a[href]").forEach((link) => {
    link.href = lessonLink(link.getAttribute("href"), page, pages, contentRoot);
  });
  content.querySelectorAll("[src], [poster]").forEach((element) => {
    for (const attribute of ["src", "poster"]) {
      if (element.hasAttribute(attribute)) element.setAttribute(attribute, new URL(element.getAttribute(attribute), new URL(page.file, contentRoot)).href);
    }
  });
  content.querySelectorAll("blockquote").forEach((quote) => {
    const label = quote.querySelector("p > strong:first-child")?.textContent.trim().toLowerCase();
    if (label === "goal" || label === "checkpoint") quote.classList.add(label);
  });
  content.querySelectorAll("table").forEach((table) => {
    const wrapper = document.createElement("div");
    wrapper.className = "table-wrap";
    table.replaceWith(wrapper);
    wrapper.append(table);
  });
  content.querySelectorAll("pre").forEach((pre) => {
    const code = pre.querySelector("code");
    if (!code) return;
    const wrapper = document.createElement("div");
    wrapper.className = "code-block";
    const header = document.createElement("div");
    header.className = "code-header";
    const label = document.createElement("span");
    label.textContent = code.className.replace("language-", "") || "Code";
    const button = document.createElement("button");
    button.type = "button";
    button.className = "copy";
    button.textContent = "Copy";
    button.setAttribute("aria-label", "Copy code");
    button.onclick = async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        button.textContent = "Copied";
        byId("announcement").textContent = "Code copied.";
      } catch (error) {
        console.warn("Clipboard unavailable.", error);
        const range = document.createRange();
        range.selectNodeContents(code);
        getSelection().removeAllRanges();
        getSelection().addRange(range);
        button.textContent = "Copy manually";
        byId("announcement").textContent = "Clipboard unavailable. Code selected; press Command+C or Control+C to copy.";
      }
    };
    pre.replaceWith(wrapper);
    header.append(label, button);
    wrapper.append(header, pre);
  });
}

async function loadRoute(event) {
  const currentRevision = ++revision;
  loaded = false;
  pending?.abort();
  pending = new AbortController();
  footer.replaceChildren();
  content.setAttribute("aria-busy", "true");
  try {
    const [id, ...fragment] = location.hash.slice(1).split("/");
    active = pages.find((page) => page.id === (id || config.overview.id));
    renderNavigation();
    if (!active) throw new Error("Unknown lesson. Choose a lesson in the navigation.");
    byId("breadcrumb").textContent = `${config.title} / ${active.title}`;
    const part = config.lessons.indexOf(active);
    const coreMinutes = config.lessons.filter((page) => page.level === "core").reduce((sum, page) => sum + page.minutes, 0);
    const label = active.level ? `${active.level === "core" ? "Core" : "Stretch"} / ` : "";
    byId("step-label").textContent = part < 0 ? `Core path about ${coreMinutes} minutes / Stretch topics optional / Self-paced` : `${label}Part ${part + 1} of ${config.lessons.length} / ${active.minutes} minutes`;
    content.textContent = "Loading lesson...";
    const markdown = await readFile(new URL(active.file, contentRoot), pending.signal);
    if (currentRevision !== revision) return;
    content.innerHTML = DOMPurify.sanitize(marked.parse(markdown), { FORBID_TAGS: ["style", "input", "button", "form"], FORBID_ATTR: ["style", "srcset", "id", "name"] });
    enhance(active);
    content.setAttribute("aria-busy", "false");
    loaded = true;
    renderFooter();
    document.title = `${active.title} | ${config.title}`;
    const anchor = fragment.length ? [...content.querySelectorAll("[id]")].find((element) => element.id === decodeURIComponent(fragment.join("/"))) : content;
    if (anchor) {
      if (event || fragment.length) anchor.focus({ preventScroll: true });
      if (fragment.length) anchor.scrollIntoView({ block: "start" });
      else scrollTo(0, 0);
    } else if (fragment.length) {
      byId("announcement").textContent = "This section was not found. The lesson is shown from the start.";
      content.focus({ preventScroll: true });
      scrollTo(0, 0);
    }
  } catch (error) {
    if (currentRevision !== revision) return;
    console.error(error);
    errorPanel(error.message);
  }
}

async function start() {
  try {
    if (location.protocol === "file:") throw new Error("Run a local HTTP server: python3 -m http.server 8000, then open http://localhost:8000. Opening index.html directly cannot load lessons.");
    const raw = await readFile("lab.json");
    try {
      config = validateConfig(JSON.parse(raw));
    } catch (error) {
      throw new Error(`Check lab.json: ${error.message}`, { cause: error });
    }
    pages = [config.overview, ...config.lessons];
    byId("menu-toggle").disabled = false;
    byId("lab-title").textContent = config.title;
    byId("lab-description").textContent = config.description;
    try {
      completed = readProgress(localStorage, config);
    } catch (error) {
      warn("progress", "Progress could not be restored. New progress is kept in this tab but is not saved reliably. Check browser storage permissions; do not close this tab if you need its progress.", error);
    }
    if (!globalThis.marked || !globalThis.DOMPurify) throw new Error("Markdown dependencies could not load. An internet connection and access to cdn.jsdelivr.net are required. Reconnect or allow the CDN, then reload.");
    addEventListener("storage", (event) => {
      if (event.key !== null && !event.key.startsWith(`copilot-lab:${config.id}:progress:`)) return;
      try {
        const synced = readProgress(localStorage, config);
        for (const [id, done] of unsaved) {
          if (done) synced.add(id);
          else synced.delete(id);
        }
        completed = synced;
        renderNavigation();
        if (loaded) renderFooter();
      } catch (error) {
        warn("progress", "Progress could not be synchronized with another tab. Keep this tab open and check browser storage permissions.", error);
      }
    });
    addEventListener("hashchange", loadRoute);
    await loadRoute();
  } catch (error) {
    console.error(error);
    errorPanel(error.message);
  }
}
start();
