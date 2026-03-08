import { mount } from "svelte"
import "../styles/app.css"
import GameSessionPage from "../pages/GameSessionPage.svelte"

const el = document.getElementById("game-session-app")

if (el) {
  const session = JSON.parse(el.dataset.session || "{}")

  mount(GameSessionPage, {
    target: el,
    props: { session }
  })
}
