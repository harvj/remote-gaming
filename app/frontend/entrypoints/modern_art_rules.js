import "../styles/modern_art_rules.css"

const drawer = document.querySelector("#modern-art-rules-drawer")
if (drawer) {
  let opener
  let outsidePointer = false

  document.addEventListener("click", event => {
    const trigger = event.target.closest("[data-modern-art-rules-trigger]")
    if (!trigger || drawer.open) return

    opener = trigger
    const root = document.documentElement
    root.style.setProperty("--modern-art-rules-scrollbar", `${innerWidth - root.clientWidth}px`)
    drawer.showModal()
    drawer.querySelector(".modern-art-rules-content").scrollTop = 0
  })

  function outside(event) {
    const bounds = drawer.getBoundingClientRect()
    return event.target === drawer && (event.clientX < bounds.left || event.clientX > bounds.right)
  }

  drawer.addEventListener("pointerdown", event => { outsidePointer = outside(event) })
  drawer.addEventListener("click", event => {
    if (outsidePointer && outside(event)) drawer.close()
    outsidePointer = false
  })

  drawer.addEventListener("keydown", event => {
    if (event.key !== "Tab") return

    const items = [...drawer.querySelectorAll("button:not([disabled]), a[href], [tabindex='0']")]
    const edge = event.shiftKey ? items[0] : items.at(-1)
    if (document.activeElement !== edge) return

    event.preventDefault()
    const target = event.shiftKey ? items.at(-1) : items[0]
    target.focus()
  })

  drawer.addEventListener("close", () => {
    document.documentElement.style.removeProperty("--modern-art-rules-scrollbar")
    opener?.focus({ preventScroll: true })
  })
}
