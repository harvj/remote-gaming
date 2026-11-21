import { mount } from "svelte";
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

window.addEventListener("pageshow", (event) => {
  if (event.persisted) window.location.reload();
});
