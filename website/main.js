// Clove website: the demo's pages, the light / dark switch, the notch's section pill, and the
// download links, which point at the latest release once there is one.

const repo = "sriramkansala/clove";
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// Demo: the segmented control under the big screen swaps the island.
const demoCaptions = {
  player: "Music or Spotify, with artwork and controls. Click the track to jump to the app.",
  calendar: "Your next events today and tomorrow, with a Join button for calls.",
  reminder: "A call is starting: Join, Ignore, or Remind me in 5 min.",
  tasks: "This cycle's Linear issues, grouped by status. ⌥ Space dictates a note.",
  system: "Battery and charger, CPU, memory, network and disk, sampled only while you look.",
  clipboard: "Copy anything and the notch says so; hover it for what you copied. Click one to copy it again, or pin it to keep it.",
};
const demoAlt = {
  player: "The Clove island open below the notch, playing music",
  calendar: "The island's calendar page with two events",
  reminder: "A card below the notch: Design review starts in 1 min, with Remind me in 5 min, Ignore and Join",
  tasks: "The island's tasks page with Linear issues",
  system: "The island's system page with battery, CPU and memory",
  clipboard: "The island's clipboard page: a pinned file, then recent text, a link and an image",
};
const demoImage = document.querySelector("[data-demo-image]");
const demoCaption = document.querySelector("[data-demo-caption]");
const demoTabs = document.querySelectorAll("[data-demo]");

function showDemo(name) {
  if (!demoImage) return;
  demoTabs.forEach((tab) => tab.setAttribute("aria-selected", String(tab.dataset.demo === name)));
  const swap = () => {
    demoImage.src = `images/island-${name}.png`;
    demoImage.alt = demoAlt[name];
    demoCaption.textContent = demoCaptions[name];
    demoImage.classList.remove("leaving");
  };
  if (reduceMotion) return swap();
  demoImage.classList.add("leaving");
  setTimeout(swap, 200);
}

demoTabs.forEach((tab) => tab.addEventListener("click", () => showDemo(tab.dataset.demo)));
// Preload the other pages, so a tab never waits on the network.
if (demoImage) Object.keys(demoCaptions).forEach((name) => { new Image().src = `images/island-${name}.png`; });

// Theme: the system's until the switch is used, then the chosen one, remembered.
const toggle = document.querySelector("[data-theme-toggle]");
const systemDark = window.matchMedia("(prefers-color-scheme: dark)");
const currentTheme = () => document.documentElement.dataset.theme || (systemDark.matches ? "dark" : "light");
function labelToggle() {
  toggle.setAttribute("aria-label", currentTheme() === "dark" ? "Switch to light mode" : "Switch to dark mode");
}
toggle.addEventListener("click", () => {
  const next = currentTheme() === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = next;
  try { localStorage.setItem("theme", next); } catch (e) {}
  labelToggle();
});
systemDark.addEventListener("change", labelToggle);
labelToggle();

// The notch: a pill behind the link of the section on screen, travelling between links the way
// the island's page tabs do.
const notchRow = document.querySelector(".notch-row");
const notchLinks = [...notchRow.querySelectorAll("a")];
// Only links to this page's own sections (the privacy page's point back to the home page).
const sections = notchLinks.map((link) => {
  const href = link.getAttribute("href");
  return href.startsWith("#") ? document.querySelector(href) : null;
});

function placePill(link) {
  notchLinks.forEach((l) => l.setAttribute("aria-current", String(l === link)));
  if (!link) {
    notchRow.style.setProperty("--pill-o", "0");
    return;
  }
  notchRow.style.setProperty("--pill-x", `${link.offsetLeft}px`);
  notchRow.style.setProperty("--pill-w", `${link.offsetWidth}px`);
  notchRow.style.setProperty("--pill-o", "1");
}

function sectionOnScreen() {
  // The last section whose top has passed a line a third of the way down the window. (The calls
  // section, between Features and Activities, keeps Features lit.)
  const line = window.innerHeight / 3;
  let current = null;
  sections.forEach((section, index) => {
    if (section && section.getBoundingClientRect().top <= line) current = notchLinks[index];
  });
  return current;
}

let ticking = false;
window.addEventListener("scroll", () => {
  if (ticking) return;
  ticking = true;
  requestAnimationFrame(() => { placePill(sectionOnScreen()); ticking = false; });
}, { passive: true });
window.addEventListener("resize", () => placePill(sectionOnScreen()));
document.fonts?.ready.then(() => placePill(sectionOnScreen()));
placePill(sectionOnScreen());

// GitHub: the star count in the menu bar, and the download links once a release exists. Both
// are optional; without the API the links keep pointing at the releases page.
if (document.querySelector("[data-stars-label]")) fetch(`https://api.github.com/repos/${repo}`)
  .then((r) => (r.ok ? r.json() : null))
  .then((info) => {
    // A brand-new repo keeps saying "GitHub" rather than "0 stars".
    if (!info || typeof info.stargazers_count !== "number" || info.stargazers_count === 0) return;
    const label = document.querySelector("[data-stars-label]");
    if (label) label.textContent = info.stargazers_count.toLocaleString();
  })
  .catch(() => {});

// The release list, not /releases/latest, which answers 404 (an error in the console) until the
// first release exists.
if (document.querySelector("[data-download-note]")) fetch(`https://api.github.com/repos/${repo}/releases?per_page=5`)
  .then((r) => (r.ok ? r.json() : null))
  .then((releases) => {
    const release = Array.isArray(releases) ? releases.find((r) => !r.draft && !r.prerelease) : null;
    const note = document.querySelector("[data-download-note]");
    const asset = release?.assets?.find((a) => /\.(zip|dmg)$/i.test(a.name));
    if (!asset) {
      if (note) note.textContent = "Free and open source. The first signed build is on its way — star the repo to hear when it lands.";
      return;
    }
    document.querySelectorAll("[data-download]").forEach((link) => { link.href = asset.browser_download_url; });
    if (note) note.textContent = `Version ${release.tag_name.replace(/^v/, "")}. Free and open source. macOS 26 or later.`;
  })
  .catch(() => {});
