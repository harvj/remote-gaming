export const manifestUrl = "https://art.harvj.com/manifest.json"

const mediaTypes = {
  svg: "image/svg+xml", png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg",
  webp: "image/webp", gif: "image/gif", ico: "image/vnd.microsoft.icon"
}
const object = value => value !== null && typeof value === "object" && !Array.isArray(value)

export function parseManifest(source) {
  const manifest = JSON.parse(source)

  // JSON.parse accepts duplicate keys. Scan the already valid JSON, accounting
  // for escaped keys and skipping structural characters inside string values.
  const objects = []
  for (const [token, colon] of source.matchAll(/"(?:[^"\\]|\\[\s\S])*"(\s*:)?|[{}]/g)) {
    if (token === "{") objects.push(new Set())
    else if (token === "}") objects.pop()
    else if (colon) {
      const key = JSON.parse(token.slice(0, -1))
      const keys = objects.at(-1)
      if (keys.has(key)) throw new Error("Duplicate Site Art manifest key")
      keys.add(key)
    }
  }

  if (!object(manifest) || manifest.schema_version !== 1 ||
      typeof manifest.commit !== "string" || manifest.commit.length !== 40 || /[^a-f0-9]/.test(manifest.commit) ||
      typeof manifest.release !== "string" || manifest.release.length !== 64 || /[^a-f0-9]/.test(manifest.release) ||
      !object(manifest.assets)) throw new Error("Invalid Site Art manifest")

  return manifest.assets
}

export function assetFor(assets, id, allowedTypes) {
  const asset = assets[id]
  if (!object(asset) || typeof asset.url !== "string") return
  const url = /^https:\/\/art\.harvj\.com\/assets\/([a-f0-9]{64})\.(svg|png|jpe?g|webp|gif|ico)$/.exec(asset.url)
  if (!url || url[0] !== asset.url || url[1] !== asset.sha256 ||
      mediaTypes[url[2]] !== asset.media_type || !allowedTypes.includes(asset.media_type) ||
      !Number.isInteger(asset.bytes) || asset.bytes < 1 || asset.bytes > 25 * 1024 ** 2 ||
      typeof asset.rights !== "string" || !asset.rights.trim()) return

  return asset
}
