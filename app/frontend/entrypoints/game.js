import { mount } from "svelte"
import "../styles/app.css"
import GameShow from "../components/Game.svelte"

const el = document.getElementById("games-show")

if (el) {
  mount(GameShow, {
    target: el,
    props: JSON.parse(el.dataset.props)
  })
}
