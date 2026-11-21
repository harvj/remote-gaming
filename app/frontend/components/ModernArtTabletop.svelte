<script>
  import { artistColors } from "../lib/modernArtPalette"
  import ModernArtCard from "./ModernArtCard.svelte"

  export let board
  export let liveHand = null
  export let livePlayerId = null

  const seasons = ["season_one", "season_two", "season_three", "season_four"]


  $: offerIds = new Set(board.offer.map(card => card.id))
  $: sales = new Map((board.sales ?? []).map(sale => [sale.cardId, sale]))
  $: playersById = new Map(board.players.map(player => [player.id, player.name]))
  $: played = board.played.filter(card => !offerIds.has(card.id) && !sales.has(card.id))

  function phaseName(phase) {
    return phase === "completed" ? "Completed" : phase?.replaceAll("_", " ") ?? "Unknown season"
  }
</script>

<section class="tabletop" aria-label="Modern Art tabletop">
  <header class="board-heading">
    <div>
      <h3>{phaseName(board.phase)}</h3>
      <p>{board.undealt} in deck</p>
    </div>
    {#if board.artists.length}
      <ul class="artists" aria-label="Artists">
        {#each board.artists as artist (artist.name)}
          <li><span class="swatch" style:background={artistColors[artist.color]}></span>{artist.name}</li>
        {/each}
      </ul>
    {/if}
  </header>

  <div class="zones">
    <section class="auction zone" aria-label="Auction table">
      <h4>Auction table</h4>
      {#if board.offer.some(card => !sales.has(card.id))}
        <ul class="cards" role="list">
          {#each board.offer.filter(card => !sales.has(card.id)) as card (card.id)}
            <li><ModernArtCard {card} /><span class="sale">{playersById.get(card.playerId) ?? ""}</span></li>
          {/each}
        </ul>
        <p>Latest digital offer · physical bidding is untracked</p>
      {:else}
        <p>No unsettled offer is represented here.</p>
      {/if}
    </section>

    <section class="zone" aria-label="Played paintings">
      <h4>Played paintings</h4>
      {#if played.length}
        {#each [...seasons, null] as season (season)}
          {@const cards = played.filter(card => card.season === season)}
          {#if cards.length}
            <h5>{phaseName(season)}</h5>
            <ul class="cards" role="list">
              {#each cards as card (card.id)}
                <li><ModernArtCard {card} /><span class="sale">{playersById.get(card.playerId) ?? ""}</span></li>
              {/each}
            </ul>
          {/if}
        {/each}
      {:else}<p>No earlier paintings.</p>{/if}
    </section>

    {#if sales.size}
      <section class="zone" aria-label="Reported sales">
        <h4>Reported sales</h4>
        <ul class="cards" role="list">
          {#each board.played.filter(card => sales.has(card.id)) as card (card.id)}
            {@const sale = sales.get(card.id)}
            <li><ModernArtCard {card} /><span class="sale">{sale.buyer} · {sale.amount}</span></li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if board.discarded.length}
      <section class="zone" aria-label="Discarded cards">
        <h4>Discarded cards</h4>
        <ul class="cards" role="list">
          {#each board.discarded as discard (discard.playerId)}
            {#if discard.cards}
              {#each discard.cards as card (card.id)}
                <li><ModernArtCard {card} /></li>
              {/each}
            {:else}
              <li aria-label={`${discard.count} hidden discards`}><ModernArtCard back /> × {discard.count}</li>
            {/if}
          {/each}
        </ul>
      </section>
    {/if}
  </div>

  {#if board.players.length}
    <div class="seats" aria-label="Player hands">
      {#each board.players as player (player.id)}
        <section class="seat" class:current={player.id === board.currentPlayerId} class:visible-hand={player.hand?.length > 0} aria-label={`${player.name}’s hand`}>
          <header class="seat-heading">
            <h4>{player.name}</h4>
            <div class="seat-meta">
              {#if player.city}<span>{player.city}</span>{/if}
              {#if player.id === board.currentPlayerId}<strong>Current turn</strong>{/if}
              {#if player.captain}<span>Captain</span>{/if}
              {#if player.winner}<strong>Winner</strong>{/if}
              {#if player.score != null}<span>Score {player.score}</span>{/if}
            </div>
          </header>
          <p>{player.handCount} {player.handCount === 1 ? "card" : "cards"} in hand</p>
          {#if player.id === livePlayerId && liveHand}
            {@render liveHand()}
          {:else if player.hand}
            <ul class="cards" role="list">
              {#each player.hand as card (card.id)}<li><ModernArtCard {card} /></li>{/each}
            </ul>
          {:else if player.handCount}
            <div class="backs" aria-hidden="true">
              {#each Array(player.handCount) as _}<ModernArtCard back />{/each}
            </div>
          {/if}
        </section>
      {/each}
    </div>
  {/if}
</section>

<style>
  .tabletop {
    --line: #b79c714d;
    color: #fff6e7;
    background: var(--oak-outer, #2b241d);
    border: 1px solid #867052;
    border-radius: var(--oak-radius-container, .8rem);
    padding: clamp(.7rem, 2.25vw, 1.35rem);
    font-family: "IBM Plex Sans", system-ui, sans-serif;
  }
  .tabletop :is(h3, h4, h5, p) { margin: 0; }
  h3, h4 { font-family: Fraunces, Georgia, serif; }
  h3, h5 { text-transform: capitalize; }
  h3 { font-size: 1.55rem; }
  h4 { font-size: 1.12rem; }
  h5 { color: #efdbbb; margin-top: .5rem !important; font-size: .82rem; }
  p { font-size: .82rem; color: #e3d5c2; }
  .board-heading, .seat-heading { display: flex; justify-content: space-between; align-items: flex-start; gap: .5rem 1rem; flex-wrap: wrap; }
  .artists, .cards { padding: 0; margin: 0; list-style: none; display: flex; flex-wrap: wrap; gap: .4rem; }
  .artists li { display: flex; align-items: center; gap: .35rem; padding: .2rem .4rem; font-size: .74rem; }
  .swatch { width: .53rem; height: .53rem; border-radius: 50%; }
  .zones { display: grid; grid-template-columns: minmax(12rem, .8fr) minmax(0, 2fr); gap: .65rem; margin-top: .9rem; }
  .zone, .seat { min-width: 0; border: 1px solid var(--line); border-radius: var(--oak-radius-section, .5rem); background: var(--oak-nested, #342b22); padding: .7rem; }
  .zone p, .cards, .backs { margin-top: .48rem; }
  .auction { background: var(--oak-accent, #473929); }
  .sale { display: block; font-size: .7rem; margin-top: .25rem; }
  .seats { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .65rem; margin-top: .65rem; }
  .seat.current { border-color: #e0b975; }
  .seat.visible-hand { grid-column: 1 / -1; }
  .seat-meta { display: flex; flex-wrap: wrap; gap: .3rem .6rem; color: #efdbbb; font-size: .74rem; }
  .backs { display: flex; flex-wrap: wrap; gap: .25rem; }
  @media (max-width: 36rem) { .zones, .seats { grid-template-columns: 1fr; } }
</style>
