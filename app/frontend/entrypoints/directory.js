import { mount } from "svelte"
import Directory from "../components/Directory.svelte"

const target = document.getElementById("game-directory")
const props = JSON.parse(document.getElementById("directory-data").textContent)
target.replaceChildren()
mount(Directory, { target, props })
