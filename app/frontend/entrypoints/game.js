import { mount } from "svelte"
import GameShow from "../components/Game.svelte"

const el = document.getElementById("games-show")
const dataEl = document.getElementById("games-show-data");

const props = JSON.parse(dataEl.textContent);

if (el) {
  mount(GameShow, {
    target: el,
    props
  })
}
