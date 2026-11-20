import assert from "node:assert/strict"
import test from "node:test"
import { applyPresentation, createBackgroundPresenter, presentationFor } from "../../app/frontend/lib/site_art_presentation.js"

const shadow = { color: "#160D08", opacity_percent: 85, blur_px: 2, x_px: 0, y_px: 1 }
const oak = { url: "oak.png", presentation: { foreground: "#fff3de", text_shadow: shadow } }
const regionalOak = { ...oak, presentation: { ...oak.presentation, regions: {
  top: { foreground: "#FFFFFF", text_shadow: { ...shadow, opacity_percent: 0 } },
  bottom: { text_shadow: { ...shadow, spread_px: 1 } }
} } }

test("resolves treatment per role, retaining valid fields and rejecting unsupported effects", () => {
  const result = presentationFor(regionalOak)
  assert.deepEqual(result.default, {
    "--art-foreground": "#FFF3DE", "--art-text-shadow": "0px 1px 2px rgb(22 13 8 / 85%)"
  })
  assert.deepEqual(result.top, { "--art-foreground": "#FFFFFF", "--art-text-shadow": "none" })
  assert.deepEqual(result.bottom, result.default)
})

test("uses only the latest treatment when a decode is pending and clears it on fallback", async () => {
  let finish, displayed, decodes = 0
  const properties = new Map()
  const style = { setProperty: (...args) => properties.set(...args), removeProperty: key => properties.delete(key) }
  const select = createBackgroundPresenter({
    decode: () => { decodes++; return new Promise(resolve => { finish = resolve }) },
    display: next => { displayed = next },
    apply: asset => applyPresentation({ top: { style } }, asset)
  })

  const initial = select(oak)
  await select(regionalOak)
  assert.equal(properties.size, 0)
  finish("decoded oak")
  await initial
  assert.equal(displayed, "decoded oak")
  assert.equal(properties.get("--art-foreground"), "#FFFFFF")
  await select(oak)
  assert.equal(decodes, 1)
  assert.equal(properties.get("--art-foreground"), "#FFF3DE")
  await select(undefined)
  assert.equal(displayed, undefined)
  assert.equal(properties.size, 0)
})

test("a failed decode retains the fallback until the record changes", async () => {
  let decodes = 0
  let displayed, applied
  const select = createBackgroundPresenter({
    decode: async () => {
      if (++decodes === 1) throw Error("unavailable")
      return "decoded oak"
    },
    display: next => { displayed = next },
    apply: asset => { applied = asset }
  })
  await select(oak)
  assert.equal(displayed, undefined)
  assert.equal(applied, undefined)
  await select(structuredClone(oak))
  assert.equal(decodes, 1)
  await select(regionalOak)
  assert.equal(displayed, "decoded oak")
  assert.equal(applied, regionalOak)
})
