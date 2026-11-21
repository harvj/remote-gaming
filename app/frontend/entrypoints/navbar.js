import { mount } from "svelte";
import { watchApplications } from "../shell_applications.js";
import Navbar from "../components/Navbar.svelte";

const target = document.getElementById("navbar-app");
const dataEl = document.getElementById("navbar-data");

if (target && dataEl) {
  mount(Navbar, {
    target,
    props: JSON.parse(dataEl.textContent)
  });
}

const disclosure = document.querySelector(".directory-apps");
if (disclosure) {
  const trigger = disclosure.querySelector("summary");
  const applications = disclosure.querySelector("[data-shell-applications]");
  if (applications) {
    let current;
    disclosure.addEventListener("toggle", () => {
      current?.destroy();
      current = disclosure.open ? watchApplications(applications) : null;
    });
  }
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && disclosure.open && disclosure.contains(document.activeElement)) {
      trigger.focus();
      disclosure.open = false;
    }
  });
  document.addEventListener("click", (event) => {
    if (disclosure.open && !disclosure.contains(event.target)) {
      if (disclosure.contains(document.activeElement)) trigger.focus();
      disclosure.open = false;
    }
  });
}

window.addEventListener("pagehide", (event) => {
  if (event.persisted) {
    if (disclosure) disclosure.open = false;
    document.documentElement.classList.add("shell-restoring");
  }
});

window.addEventListener("pageshow", (event) => {
  if (event.persisted) window.location.reload();
});

// Anchor the content mask to the viewport edge of the in-flow sticky header.
const shellHeader = document.querySelector(".oak-shell > header");
if (shellHeader) {
  const regions = document.querySelectorAll(".oak-shell > main, .oak-shell > footer");
  let frame;

  function updateFade() {
    frame = undefined;
    const boundary = shellHeader.getBoundingClientRect().bottom;
    document.body.style.setProperty("--shell-header-height", `${shellHeader.offsetHeight}px`);
    for (const region of regions) {
      const cover = boundary - region.getBoundingClientRect().top;
      const active = window.scrollY > 0 && cover > -24;
      region.toggleAttribute("data-shell-fading", active);
      if (active) region.style.setProperty("--shell-cover", `${cover}px`);
    }
  }

  function scheduleFade() {
    if (frame === undefined) frame = requestAnimationFrame(updateFade);
  }

  window.addEventListener("scroll", scheduleFade, { passive: true });
  window.addEventListener("resize", scheduleFade);
  document.addEventListener("focusin", ({ target }) => {
    if (target.matches(":focus-visible") && target.closest("main, footer") &&
        target.getBoundingClientRect().top < shellHeader.getBoundingClientRect().bottom) {
      target.scrollIntoView({ block: "center" });
    }
  });
  const observer = new ResizeObserver(scheduleFade);
  observer.observe(shellHeader);
  for (const region of regions) observer.observe(region);
  scheduleFade();
}
