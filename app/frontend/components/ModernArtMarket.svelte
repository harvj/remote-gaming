<script>
  import { artistColors } from "../lib/modernArtPalette"

  export let artists
  export let counts = null
  export let seasons = null

  function tiles(key) {
    return seasons?.map(season => season.tiles[key]).filter(Boolean).join(" + ") || "—"
  }
</script>

<section aria-label="Artist market">
  <h4>Artist market</h4>
  <table>
    <thead><tr><th scope="col">Artist</th><th scope="col">{seasons ? "Played" : "Recorded plays"}</th><th scope="col">Tiles</th></tr></thead>
    <tbody>
      {#each artists as artist (artist.name)}
        <tr>
          <th scope="row"><span class="marker" style:background={artistColors[artist.color]}></span>{artist.name}</th>
          <td>{counts ? counts[artist.key] ?? 0 : "—"}</td>
          <td>{seasons ? tiles(artist.key) : "—"}</td>
        </tr>
      {/each}
    </tbody>
  </table>
  {#if !seasons}<p>Valuation tiles <strong>Not recorded</strong></p>{/if}
</section>

<style>
  h4 { margin: 0; font: 700 clamp(1.15rem, 3vw, 1.55rem) Fraunces, Georgia, serif; }
  th, td { text-align: left; padding: .4rem .2rem; border-bottom: 1px solid #ae93715c; }
  table { width: 100%; border-collapse: collapse; font-size: .83rem; margin-block-start: .45rem; }
  th[scope="row"] { font-weight: 600; }
  .marker { display: inline-block; width: .56em; height: .56em; border-radius: 50%; margin-inline-end: .42em; vertical-align: .12em; }
  p { font-size: .83rem; margin: .5rem 0 0; }
</style>
