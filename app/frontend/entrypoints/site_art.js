import { assetFor, manifestUrl, parseManifest } from "../lib/site_art"
import { applyPresentation, createBackgroundPresenter } from "../lib/site_art_presentation"
import "../styles/site_art.css"

const interval = 60_000
const background = document.querySelector("#site-art-background")
const icon = document.querySelector("#site-art-icon")
const localIcon = { url: icon.href, media_type: icon.type }
const rasterTypes = ["image/webp", "image/jpeg", "image/png"]
let requestedIcon
let iconGeneration = 0
let refreshing = false

function readCache(key) {
  try { return sessionStorage.getItem(key) } catch { return null }
}

function writeCache(key, value) {
  try { sessionStorage.setItem(key, value) } catch { /* Storage is optional. */ }
}

const artRoles = Object.fromEntries(["top", "default", "bottom"].map(role =>
  [role, document.querySelector(`[data-art-role="${role}"]`)]))
const setBackground = createBackgroundPresenter({
  async decode(url) {
    const image = new Image()
    image.alt = ""
    image.crossOrigin = "anonymous"
    image.src = url
    await image.decode()
    return image
  },
  display(image) {
    background.replaceChildren(...(image ? [image] : []))
    document.body.toggleAttribute("data-site-art-background", Boolean(image))
  },
  apply: asset => applyPresentation(artRoles, asset)
})

async function setIcon(asset) {
  if (asset?.url === requestedIcon) return
  requestedIcon = asset?.url
  const generation = ++iconGeneration
  let selected = localIcon
  if (asset) {
    const image = new Image()
    image.crossOrigin = "anonymous"
    image.src = asset.url
    try {
      await image.decode()
      selected = asset
    } catch { /* Keep the bundled icon. */ }
  }
  if (generation === iconGeneration) {
    icon.type = selected.media_type
    icon.href = selected.url
  }
}

function render(assets) {
  void setBackground(assetFor(assets, "remote-gaming.background", rasterTypes))
  void setIcon(assetFor(assets, "remote-gaming.favicon", ["image/svg+xml", "image/png"]))
}

let lastAttempt = Number(readCache("site-art.last-attempt"))
async function refresh() {
  if (refreshing || Date.now() - lastAttempt < interval) return
  refreshing = true
  lastAttempt = Date.now()
  writeCache("site-art.last-attempt", lastAttempt)
  try {
    const response = await fetch(manifestUrl, {
      credentials: "omit", redirect: "error", signal: AbortSignal.timeout(500), cache: "no-cache"
    })
    if (!response.ok) return
    const source = await response.text()
    const assets = parseManifest(source)
    writeCache("site-art.manifest", source)
    render(assets)
  } catch { /* Keep the last accepted snapshot and installed artwork. */ }
  finally { refreshing = false }
}

const cached = readCache("site-art.manifest")
if (cached) {
  try { render(parseManifest(cached)) } catch { /* Start with local artwork. */ }
}
void refresh()
setInterval(refresh, interval)
