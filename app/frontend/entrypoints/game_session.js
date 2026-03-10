import { mount } from "svelte"
import GameSessionPage from "../components/GameSession.svelte"

const el = document.getElementById("game-sessions-show")

if (el) {
  const session = JSON.parse(el.dataset.session || "{}")

  mount(GameSessionPage, {
    target: el,
    props: { session }
  })
}
