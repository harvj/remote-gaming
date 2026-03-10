import { mount } from "svelte"
import GameSessionPage from "../components/GameSession.svelte"

const target = document.getElementById("game-sessions-show");
const dataEl = document.getElementById("game-sessions-show-data");

if (target && dataEl) {
  const session = JSON.parse(dataEl.textContent);

  mount(GameSessionPage, {
    target,
    props: { session }
  })
}
