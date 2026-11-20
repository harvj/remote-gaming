import { mount } from "svelte"
import SessionReplay from "../components/SessionReplay.svelte"

const target = document.getElementById("session-replay")
const props = JSON.parse(document.getElementById("session-replay-data").textContent)
mount(SessionReplay, { target, props })
