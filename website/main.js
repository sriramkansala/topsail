// Clove website: the demo tabs, the page panels, the rotating headline word, the theme switch,
// and the download links, which point at the latest release once there is one.

const repo = "sriramkansala/clove";
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// Demo: the tabs under the before / after panel swap the island on the right.
const demoCaptions = {
  player: "Move the pointer to the notch: the island opens on what's playing.",
  calendar: "Your next events, with a Join button when a meeting is about to start.",
  tasks: "This cycle's Linear issues, grouped by status.",
  system: "Battery, charger, CPU, memory and more, sampled only while you look.",
  "low-battery": "When something happens, the island grows beside the notch for a moment.",
};
const demoImage = document.querySelector("[data-demo-image]");
const demoCaption = document.querySelector("[data-demo-caption]");
const demoTabs = document.querySelectorAll("[data-demo]");

function showDemo(name) {
  demoTabs.forEach((tab) => tab.setAttribute("aria-selected", String(tab.dataset.demo === name)));
  const swap = () => {
    demoImage.src = `images/island-${name}.png`;
    demoImage.alt = `The Clove island: ${demoCaptions[name]}`;
    demoCaption.textContent = demoCaptions[name];
    demoImage.classList.remove("leaving");
  };
  if (reduceMotion) return swap();
  demoImage.classList.add("leaving");
  setTimeout(swap, 220);
}

demoTabs.forEach((tab) => tab.addEventListener("click", () => showDemo(tab.dataset.demo)));
// Preload the other pages, so a tab never waits on the network.
Object.keys(demoCaptions).forEach((name) => { new Image().src = `images/island-${name}.png`; });

// Pages: one panel open at a time.
const panels = document.querySelectorAll(".panel");
function openPanel(panel) {
  panels.forEach((p) => p.setAttribute("aria-expanded", String(p === panel)));
}
panels.forEach((panel) => {
  panel.addEventListener("click", () => openPanel(panel));
  panel.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") { event.preventDefault(); openPanel(panel); }
  });
});

// The headline's last words take turns.
const words = document.querySelectorAll(".rotator span");
if (words.length > 1 && !reduceMotion) {
  let current = 0;
  setInterval(() => {
    words[current].classList.remove("on");
    current = (current + 1) % words.length;
    words[current].classList.add("on");
  }, 2600);
}

// Theme: light, dark, or the system's.
const themeButtons = document.querySelectorAll("[data-theme-choice]");
function applyTheme(choice) {
  if (choice === "light" || choice === "dark") {
    document.documentElement.dataset.theme = choice;
  } else {
    delete document.documentElement.dataset.theme;
  }
  themeButtons.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.themeChoice === choice)));
  try { choice === "system" ? localStorage.removeItem("theme") : localStorage.setItem("theme", choice); } catch (e) {}
}
let savedTheme = "system";
try { savedTheme = localStorage.getItem("theme") || "system"; } catch (e) {}
applyTheme(savedTheme);
themeButtons.forEach((b) => b.addEventListener("click", () => applyTheme(b.dataset.themeChoice)));

// GitHub: the star count in the header, and the download links once a release exists. Both
// are optional; without the API the links keep pointing at the releases page.
fetch(`https://api.github.com/repos/${repo}`)
  .then((r) => (r.ok ? r.json() : null))
  .then((info) => {
    // A brand-new repo keeps saying "GitHub" rather than "0 stars".
    if (!info || typeof info.stargazers_count !== "number" || info.stargazers_count === 0) return;
    const label = document.querySelector("[data-stars-label]");
    label.textContent = `${info.stargazers_count.toLocaleString()} stars`;
  })
  .catch(() => {});

fetch(`https://api.github.com/repos/${repo}/releases/latest`)
  .then((r) => (r.ok ? r.json() : null))
  .then((release) => {
    const note = document.querySelector("[data-download-note]");
    const asset = release?.assets?.find((a) => /\.(zip|dmg)$/i.test(a.name));
    if (!asset) {
      note.textContent = "Free and open source. The first signed build is on its way — star the repo to hear when it lands.";
      return;
    }
    document.querySelectorAll("[data-download]").forEach((link) => { link.href = asset.browser_download_url; });
    note.textContent = `Version ${release.tag_name.replace(/^v/, "")}. Free and open source. macOS 26 or later.`;
  })
  .catch(() => {});
