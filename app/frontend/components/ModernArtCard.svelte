<script>
  import { artistColors } from "../lib/modernArtPalette"
  export let card
  export let onplay = null
  export let disabled = false
  export let back = false
</script>

{#snippet face()}
  <span class="emblem"><i class={"fas fa-" + card.iconClass} aria-hidden="true"></i></span>
  <span class="artist">{card.name}</span>
  <span class="auction-type">{card.value}</span>
{/snippet}

{#if back}
  <span class="card back" aria-hidden="true"><span>MA</span></span>
{:else if onplay}
  <button class="card" style:--artist={artistColors[card.color]} type="button" data-card-id={card.id} {disabled} onclick={() => onplay(card)}>
    {@render face()}
  </button>
{:else}
  <span class="card" style:--artist={artistColors[card.color]} data-card-id={card.id}>
    {@render face()}
  </span>
{/if}

<style>
  .card {
    --artist: #e1d6c3;
    display: inline-grid;
    grid-template-rows: auto 1fr auto;
    align-items: start;
    justify-items: start;
    gap: .35rem;
    box-sizing: border-box;
    width: 6.4rem;
    min-height: 6.85rem;
    padding: .55rem .58rem .62rem;
    border: 1px solid #40342755;
    border-top: .27rem solid var(--artist);
    border-radius: .38rem;
    color: #27221d;
    background: color-mix(in srgb, var(--artist) 20%, #fffdf6);
    box-shadow: 0 2px 5px #1b100526;
    font-family: "IBM Plex Sans", system-ui, sans-serif;
    text-align: left;
    line-height: 1.1;
    vertical-align: top;
  }
  .artist { font-family: Fraunces, Georgia, serif; font-size: .99rem; font-weight: 700; }
  .auction-type { font-size: .68rem; font-weight: 600; }
  .emblem {
    display: grid;
    place-items: center;
    width: 1.55rem;
    height: 1.55rem;
    border-radius: 50%;
    background: color-mix(in srgb, var(--artist) 50%, #fffdf6);
    font-size: .8rem;
  }
  button.card:enabled { cursor: pointer; }
  button.card:enabled:hover { outline: 2px solid #fffdf6; outline-offset: 2px; }
  button.card:focus-visible { outline: 3px solid #fffdf6; outline-offset: 3px; }
  button.card:disabled { cursor: default; }
  .back {
    --artist: #a78a62;
    width: 2.25rem;
    min-height: 3rem;
    display: inline-grid;
    place-items: center;
    padding: .2rem;
    background: #382e25;
    color: #ead4af;
    border-color: #a78a62;
    font: 700 .63rem Georgia, serif;
    letter-spacing: .04em;
  }
</style>
