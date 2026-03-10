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
