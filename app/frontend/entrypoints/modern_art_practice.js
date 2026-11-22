import { mount } from "svelte"
import PracticeTable from "../components/ModernArtPractice.svelte"

const target = document.getElementById("practice-table")
const props = JSON.parse(document.getElementById("practice-table-data").textContent)
mount(PracticeTable, { target, props })
