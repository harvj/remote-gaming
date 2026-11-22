// Site Art presentation v1 treats unknown optional fields as absent.
const roles = ["default", "top", "bottom"]
const hex = value => typeof value === "string" && value.length === 7 && /^#[0-9a-f]{6}$/i.test(value)
const object = value => value !== null && typeof value === "object" && !Array.isArray(value)
const shadowBounds = { opacity_percent: [0, 100], blur_px: [0, 8], x_px: [-4, 4], y_px: [-4, 4] }
const backingBounds = { opacity_percent: [0, 50] }
// Approved Remote Gaming design. The declaration applies to all artwork roles.
export const presentationOverrides = Object.freeze({
  default: Object.freeze({ text_shadow: "none" })
})
const legacyColors = { light: "#FFF3DE", dark: "#243B44" }

function effect(value, bounds) {
  if (!object(value) || !hex(value.color) || Object.keys(value).length !== 1 + Object.keys(bounds).length) return
  if (Object.entries(bounds).every(([key, [min, max]]) =>
    Object.hasOwn(value, key) && Number.isInteger(value[key]) && value[key] >= min && value[key] <= max
  )) return value
}

function rgba({ color, opacity_percent }) {
  const channels = color.slice(1).match(/../g).map(channel => parseInt(channel, 16))
  return `rgb(${channels.join(" ")} / ${opacity_percent}%)`
}

function scope(value) {
  if (!object(value)) return {}
  const properties = {}
  if (hex(value.foreground)) properties["--art-foreground"] = value.foreground.toUpperCase()
  const shadow = effect(value.text_shadow, shadowBounds)
  if (shadow) {
    properties["--art-text-shadow"] = shadow.opacity_percent === 0 ? "none" :
      `${shadow.x_px}px ${shadow.y_px}px ${shadow.blur_px}px ${rgba(shadow)}`
  }
  const backing = effect(value.backing, backingBounds)
  if (backing) properties["--art-backing"] = backing.opacity_percent === 0 ? "transparent" : rgba(backing)
  return properties
}

export function presentationFor(asset) {
  const legacy = typeof asset?.foreground === "string" && Object.hasOwn(legacyColors, asset.foreground) ?
    { "--art-foreground": legacyColors[asset.foreground] } : {}
  const presentation = object(asset?.presentation) ? asset.presentation : {}
  const defaults = { ...legacy, ...scope(presentation) }
  const regions = object(presentation.regions) ? presentation.regions : {}
  return { default: defaults, top: { ...defaults, ...scope(regions.top) }, bottom: { ...defaults, ...scope(regions.bottom) } }
}

export function applyPresentation(elements, asset) {
  const presentation = presentationFor(asset)
  const shadow = asset && presentationOverrides.default.text_shadow
  for (const role of roles) {
    if (!elements[role]) continue
    for (const property of ["--art-foreground", "--art-text-shadow", "--art-backing"]) {
      const value = property === "--art-text-shadow" && shadow === "none"
        ? shadow : presentation[role][property]
      if (value) elements[role].style.setProperty(property, value)
      else elements[role].style.removeProperty(property)
    }
  }
}

export function createBackgroundPresenter({ decode, display, apply }) {
  let requestedUrl
  let displayedUrl
  let requestedAsset
  let failedTreatment
  let generation = 0

  return async function select(asset) {
    const url = asset?.url
    requestedAsset = asset
    if (url === requestedUrl) {
      if (url === displayedUrl) {
        apply(asset)
        return
      }
      if (!failedTreatment || failedTreatment === JSON.stringify(presentationFor(asset))) return
    }
    requestedUrl = url
    failedTreatment = undefined
    const selection = ++generation

    if (url === displayedUrl) {
      apply(asset)
      return
    }

    let image
    if (url) {
      try { image = await decode(url) } catch { /* Restore the local theme. */ }
    }
    if (selection !== generation) return
    displayedUrl = image ? url : undefined
    if (url && !image) failedTreatment = JSON.stringify(presentationFor(requestedAsset))
    display(image)
    apply(image ? requestedAsset : undefined)
  }
}
