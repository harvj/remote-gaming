<script>
  import { onMount } from "svelte"
  import { cable } from "../lib/cable"
  import { artistColors } from "../lib/modernArtPalette"
  import ModernArtCard from "./ModernArtCard.svelte"
  import ModernArtSeasonRail from "./ModernArtSeasonRail.svelte"
  import ModernArtMarket from "./ModernArtMarket.svelte"
  import ModernArtPlayerBadges from "./ModernArtPlayerBadges.svelte"

  let { board: initial, uid, endpoint, lobbyUrl, token, channel, replay = false } = $props()
  const initialBoard = () => initial
  let board = $state(initialBoard())
  $effect(() => { if (replay) board = initial })
  let amount = $state("")
  let busy = $state(false)
  let message = $state("")
  let unavailable = $state(false)
  let handSort = $state("recorded")
  let groupHand = $state(false)
  const handGroups = $derived.by(() => {
    const cards = [...board.hand]
    if (handSort !== "recorded") {
      const field = handSort === "artist" ? "name" : "value"
      cards.sort((first, second) => first[field].localeCompare(second[field]))
    }
    if (!board.historical || !groupHand) return [["", cards]]

    const groups = new Map()
    for (const card of cards) {
      if (!groups.has(card.name)) groups.set(card.name, [])
      groups.get(card.name).push(card)
    }
    return [...groups]
  })

  const artists = [
    ["lite_metal", "Lite Metal", "yellow"], ["yoko", "Yoko", "light-green"],
    ["cristin_p", "Cristin P", "dark-pink"], ["karl_gitter", "Karl Gitter", "light-purple"],
    ["krypto", "Krypto", "light-brown"]
  ]
  const phases = {
    offer: ["Choose a painting", "Offer a card from your hand. Its auction symbol determines how the lot is sold."],
    pair: ["Double auction", "Add a non-double painting by the same artist, or let the next seat try. The second card sets the auction type."],
    fixed_price: ["Set a fixed price", "If nobody buys at this price, you pay the bank and keep the lot."],
    fixed_offer: ["Fixed price", "Buy at the stated price or pass. If every buyer passes, the seller pays the bank."],
    open: ["Open auction", "Raise the highest bid or pass. A new bid reopens bidding. The lot closes once nobody raises."],
    once_around: ["Once Around auction", "Each seat can raise once or pass. The seller has the final bid."],
    sealed: ["Sealed auction", "Your bid stays private until everyone has committed. Bid zero to pass."],
    scoring: ["Bank settlement", "Ranked artists earn a tile. Each ranked artist pays the sum of their tiles from this and earlier seasons."],
    complete: ["Final results", "The museum with the most cash wins."]
  }
  const cash = value => `$${value}k`
  const label = seat => board.names[seat]
  const viewerSeat = $derived(board.viewerSeat ?? 0)
  const bounds = $derived(board.legal.price ?? board.legal.bid)
  const summary = $derived(board.seasons.at(-1))
  const standings = $derived([...board.players].sort((a, b) => (b.cash ?? 0) - (a.cash ?? 0)))
  const winners = $derived(board.phase === "complete"
    ? board.players.filter(player => player.cash === Math.max(...board.players.map(seat => seat.cash))) : [])

  function accept(next) {
    if (next.revision < board.revision) return
    if (next.revision > board.revision) amount = ""
    board = next
  }

  async function refresh() {
    try {
      const response = await fetch(endpoint, { headers: { Accept: "application/json" }, cache: "no-store" })
      if (response.ok) accept(await response.json())
      else if ([401, 404].includes(response.status)) unavailable = true
    } catch { /* The next cable notification or refresh retries. */ }
  }

  async function send(command, value = null) {
    if (busy || unavailable || replay) return

    busy = true
    message = ""
    try {
      const response = await fetch(endpoint, {
        method: "PATCH", cache: "no-store",
        headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ command, value, revision: board.revision })
      })
      if (response.ok) accept(await response.json())
      else if ([401, 404].includes(response.status)) unavailable = true
      else if ([409, 422].includes(response.status)) {
        const result = await response.json()
        accept(result.board)
        message = result.message
      } else {
        message = "The table could not confirm the action. It is refreshing before you try again."
        await refresh()
      }
    } catch {
      message = "Connection interrupted. The table is refreshing."
      await refresh()
    } finally {
      busy = false
    }
  }

  onMount(() => {
    if (replay || !channel) return
    const subscription = cable.subscriptions.create({ channel, uid }, {
      connected: refresh, received: refresh
    })
    const interval = setInterval(refresh, 10000)
    return () => { subscription.unsubscribe(); clearInterval(interval) }
  })

  function describe(event) {
    if (event.number) {
      if (event.sealed) return "A sealed bid was submitted."
      const context = event.action === "pass" ? `${label(event.seat)} passed.`
        : event.action === "advance" ? "Season settlement acknowledged."
        : event.action === "bid" && event.amount != null ? `${label(event.seat)} sealed ${cash(event.amount)}.` : ""
      return [context, ...event.notes.map(describe)].filter(Boolean).join(" ")
    }
    if (event.description) return event.description
    if (event.type === "played") return `${label(event.seat)} offered ${event.card.name} · ${event.card.value}.`
    if (event.type === "price") return `${label(event.seat)} set the price at ${cash(event.amount)}.`
    if (event.type === "bid") return `${label(event.seat)} bid ${cash(event.amount)}.`
    if (event.type === "sold") return `${label(event.seat)} acquired ${event.cards.length === 1 ? "one painting" : "two paintings"} for ${cash(event.amount)}.`
    if (event.type === "revealed") return event.amounts.map((value, seat) => `${label(seat)} ${cash(value)}`).join(" · ")
    return "The bank settled this season."
  }
</script>

{#if unavailable}
  <p class="panel" role="alert">This private table is no longer available. <a href={lobbyUrl}>{replay ? "Return to live table" : board.viewerSeat != null ? "Return to lobby" : "Return to practice tables"}</a>.</p>
{:else}
  <article class="practice tabletop" aria-label="Modern Art tabletop">
    <header class="heading">
      <div>
        {#if lobbyUrl}<a href={lobbyUrl}>{board.historical ? "Modern Art lobby" : replay ? "Live table" : board.viewerSeat != null ? "Modern Art lobby" : "Practice tables"}</a>{/if}
        <h1>Modern Art</h1>
      </div>
      <button type="button" data-modern-art-rules-trigger aria-haspopup="dialog" aria-controls="modern-art-rules-drawer">Game Rules</button>
    </header>

    <div class="seasons"><ModernArtSeasonRail season={board.season} /></div>

    <section class="auction" aria-label="Auction table">
      {#if board.historical}
        <p class="turn">Historical record · Read only</p>
        <h2 id="auction-heading">Auction table</h2>
        {#if !board.completeReplay}<p>The available record cannot reconstruct a complete deterministic replay.</p>{/if}
        {#if !board.auction.cards.length}<p>Recorded offer <strong>Not recorded</strong></p>{/if}
        {#if board.turn != null}<p>Recorded active seat · {label(board.turn)}</p>{/if}
        <p>Bid history <strong>Not recorded</strong></p>
        {#each board.auction.sales as sale (sale.cardId)}
          <p>Reported sale · {sale.buyer} · {cash(sale.amount)}</p>
        {/each}
      {:else}
        <p class="turn">{board.turn == null ? (board.auction ? (board.auction.seller === viewerSeat ? "You’re selling" : `${label(board.auction.seller)} is selling`) : "The bank") : `${label(board.turn)} · ${board.phase === "scoring" ? "next seller" : "active seat"}`}</p>
        <h2 id="auction-heading">{phases[board.phase][0]}</h2>
        <p aria-live="polite">{phases[board.phase][1]}</p>
      {/if}

      {#if board.auction}
        <div class="lot">
          {#each board.auction.cards as card (card.id)}
            <ModernArtCard {card} />
          {/each}
          {#if board.auction.price != null}
            <strong>{cash(board.auction.price)} asking price</strong>
          {:else if board.auction.high > 0}
            <strong>{cash(board.auction.high)} · {label(board.auction.leader)}</strong>
          {/if}
        </div>
      {/if}

      {#if message}<p role="alert">{message}</p>{/if}
      {#if bounds}
        <form class="bid-form" onsubmit={event => {
          event.preventDefault()
          if (Number.isInteger(amount)) void send(board.legal.price ? "price" : "bid", Number(amount))
        }}>
          <label>Amount in $k
            <input type="number" inputmode="numeric" min={bounds[0]} max={bounds[1]} step="1" bind:value={amount} required />
          </label>
          <button class="action" disabled={busy}>{board.legal.price ? "Set price" : board.phase === "sealed" ? "Seal bid" : "Bid"}</button>
        </form>
      {/if}
      <div class="actions">
        {#if board.legal.buy}<button class="action" disabled={busy} onclick={() => send("buy")}>Buy lot</button>{/if}
        {#if board.legal.pass}<button disabled={busy} onclick={() => send("pass")}>{board.phase === "pair" ? "Decline to pair" : "Pass"}</button>{/if}
      </div>

      {#if board.phase === "scoring"}
        <ul class="payouts">
          {#each artists as [key, name, color]}
            {#if summary.values[key]}
              <li><span class="marker" style:background={artistColors[color]}></span>{name}<strong>{cash(summary.values[key])} each</strong></li>
            {/if}
          {/each}
        </ul>
        <p>Your bank payout <strong>{cash(summary.payouts[viewerSeat])}</strong></p>
        {#if board.legal.advance}<button class="action" disabled={busy} onclick={() => send("advance")}>{board.season === 4 || board.players.every(player => player.handCount === 0) ? "Reveal results" : "Continue to next season"}</button>{/if}
      {/if}

      {#if board.phase === "complete"}
        <p class="winner">{winners.map(player => label(player.seat)).join(" and ")} {winners.length > 1 ? "tie" : winners[0].seat === viewerSeat ? "win" : "wins"} with {cash(winners[0].cash)}.</p>
        <ol class="standings" aria-label="Final cash balances">
          {#each standings as player (player.seat)}
            <li><span>{label(player.seat)}</span><strong>{cash(player.cash)}</strong></li>
          {/each}
        </ol>
        <a href={lobbyUrl}>{replay ? "Return to live table" : board.viewerSeat != null ? "Return to lobby" : "Return to practice tables"}</a>
      {/if}
      {#if board.historical && board.concluded}
        <div class="historical-results">
          <h2>Recorded results</h2>
          <ol class="standings" aria-label="Recorded standings">
            {#each board.players as player (player.seat)}
              <li><span>{player.name}{player.winner ? " · Winner" : ""}</span><strong>{player.score == null ? "Score not recorded" : player.score}</strong></li>
            {/each}
          </ol>
          <p>Final cash standings <strong>Not recorded</strong></p>
        </div>
      {/if}
    </section>

    <aside class="market" aria-label="Market board">
      <ModernArtMarket artists={board.artists ?? artists.map(([key, name, color]) => ({ key, name, color }))} counts={board.market} seasons={board.seasons} />
    </aside>

    {#if board.phase !== "complete"}
      <section class="hand" aria-labelledby="hand-heading">
        <div class="heading hand-heading">
          <h2 id="hand-heading">Your hand <small>{board.hand.length} paintings</small></h2>
          {#if board.historical}<strong>Cash balance · Not recorded</strong>{:else}<strong>{cash(board.players[viewerSeat].cash)} available</strong>{/if}
        </div>
        {#if board.historical && board.hand.length > 1}
          <div class="hand-options">
            <label>Sort hand
              <select bind:value={handSort}>
                <option value="recorded">Recorded order</option>
                <option value="artist">Artist</option>
                <option value="auction">Auction type</option>
              </select>
            </label>
            <label><input type="checkbox" bind:checked={groupHand} /> Group by artist</label>
          </div>
        {/if}
        {#each handGroups as [group, cards] (group)}
          {#if group}<h3>{group}</h3>{/if}
          <div class="cards">
            {#each cards as card (card.id)}
              {@const playable = board.legal.card_ids?.includes(card.id)}
              <ModernArtCard {card} onplay={playable ? () => send("play", card.id) : null} disabled={busy} />
            {/each}
          </div>
        {/each}
        {#if board.historical && !board.handKnown}<p>Hand <strong>Not recorded</strong></p>{:else if board.hand.length === 0}<p>{board.historical ? "No paintings recorded in this hand." : "No cards in hand. You can still bid when eligible."}</p>{/if}
      </section>

      <section class="seats" aria-label="Museums">
        {#each board.players as player (player.seat)}
          <article class:active={board.turn === player.seat}>
            <h2>{label(player.seat)}</h2>
            <ModernArtPlayerBadges metadata={player.badges} />
            {#if board.historical}
              <p>{player.handCount ?? "Not recorded"} in hand · Cash <strong>Not recorded</strong></p>
              <p>{player.holdings.length > 0 ? "Recorded acquisitions" : "Acquisitions · Not recorded"}</p>
              {#if player.hand?.length}
                <details>
                  <summary>Recorded hand</summary>
                  <div class="cards">{#each player.hand as card (card.id)}<ModernArtCard {card} />{/each}</div>
                </details>
              {/if}
            {:else}
              <p>{player.handCount} in hand · {player.holdings.length} acquired</p>
            {/if}
            {#if player.holdings.length}
              <div class="cards">
                {#each player.holdings as card (card.id)}
                  <ModernArtCard {card} />
                {/each}
              </div>
            {/if}
          </article>
        {/each}
      </section>
    {/if}

    {#if board.recent.length || board.historical}
      <section class="activity">
        <h2>Recent actions</h2>
        {#if board.historical}<p>Only existing frame references are shown. A complete action sequence was not recorded.</p>{/if}
        <ul class="numbered-actions">
          {#each [...board.recent].reverse() as event}
            <li data-action-number={event.number}><strong>{event.number ? `#${event.number}` : event.frame ? `Frame ${event.frame}` : ""}</strong> {describe(event)}</li>
          {/each}
        </ul>
      </section>
    {/if}
    {#if board.actionHistory?.length}
      <details class="ledger">
        <summary>Full action history</summary>
        <ul class="numbered-actions">
          {#each [...board.actionHistory].reverse() as event}
            <li><strong>{event.number ? `#${event.number}` : `Frame ${event.frame}`}</strong> {describe(event)}</li>
          {/each}
        </ul>
      </details>
    {/if}
    {#if board.historical && board.played.length}
      <details class="ledger" aria-label="Played paintings"><summary>Recorded paintings</summary>
        <div class="cards">{#each board.played as card (card.id)}<ModernArtCard {card} />{/each}</div>
      </details>
    {/if}
    {#if board.bidHistory}
      <details class="ledger">
        <summary>Recorded bidding and outcomes</summary>
        {#if board.bidHistory.length === 0}<p>No bidding is visible yet.</p>{/if}
        <ol>
          {#each board.bidHistory as entry (entry.sequence)}
            <li>Action {entry.sequence} · Auction {entry.auction} · {label(entry.seat)} · {entry.action}{entry.amount != null ? ` ${cash(entry.amount)}` : ""}</li>
          {/each}
        </ol>
        {#if board.settlements.length}
          <h2>Auction outcomes</h2>
          <ul>
            {#each board.settlements as outcome (outcome.auction)}
              <li>Auction {outcome.auction} · {outcome.outcome === "unsold" ? "Unsold · season ended" : `${label(outcome.winner)} acquired the lot for ${cash(outcome.amount)}`}</li>
            {/each}
          </ul>
        {/if}
      </details>
    {/if}
  </article>
{/if}

<style>
  .practice {
    color: var(--oak-text); display: grid; gap: 1rem; margin-block-end: 1rem;
    grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr);
    grid-template-areas: "title title" "seasons seasons" "auction market" "hand hand" "seats seats" "activity activity";
  }
  .practice > .heading { grid-area: title; }
  .seasons { grid-area: seasons; }
  .auction { grid-area: auction; }
  .market { grid-area: market; }
  .hand { grid-area: hand; }
  .seats { grid-area: seats; }
  .activity { grid-area: activity; }
  .ledger { grid-column: 1 / -1; }
  .practice a { color: var(--oak-link); }
  .heading { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: .75rem; }
  .heading h1, .practice h2, .winner { font-family: Fraunces, Georgia, serif; }
  .heading h1 { margin: .15rem 0; font-size: clamp(2.2rem, 5vw, 3.45rem); line-height: 1; }
  .auction, .market, .hand, .activity, .ledger, .seats article {
    background: var(--oak-outer); border: 1px solid #b0926b99; border-radius: var(--oak-radius-container);
    padding: clamp(.7rem, 2.4vw, 1.25rem); min-width: 0;
  }
  .auction { background: #35271e; }
  .practice h2 { margin: 0; font-size: clamp(1.15rem, 3vw, 1.55rem); }
  .practice p { margin: .4rem 0; }
  .practice .turn { font-size: .82rem; color: #f1d3a6; margin: 0 0 .3rem; font-weight: 700; }
  .lot, .cards, .actions, .bid-form { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem; }
  .lot, .bid-form, .actions:not(:empty), .cards { margin-block-start: .75rem; }
  .bid-form { align-items: end; }
  .bid-form label { display: grid; gap: .25rem; }
  .practice button:not([data-card-id]), .bid-form input, .hand-options select {
    min-height: 44px; padding: .45rem .65rem; border: 1px solid var(--oak-line);
    border-radius: var(--oak-radius-control); color: var(--oak-text); background: #493628; font: inherit;
  }
  .bid-form input { width: 7rem; }
  .hand-options { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem 1rem; margin-top: .5rem; }
  .hand-options label { display: inline-flex; align-items: center; gap: .35rem; }
  .practice button.action { background: #efd29f; color: #2c1b12; font-weight: 700; }
  .practice button:disabled { cursor: wait; }
  .marker { display: inline-block; width: .56em; height: .56em; border-radius: 50%; margin-inline-end: .42em; vertical-align: .12em; }
  .hand-heading small { font: 500 .78rem system-ui; margin-inline-start: .3rem; }
  .seats { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: .55rem; }
  .seats article { border-radius: var(--oak-radius-section); background: var(--oak-nested); }
  .seats article.active { border-color: #ecc081; }
  .payouts { list-style: none; padding: 0; }
  .payouts li { display: flex; align-items: center; gap: .35rem; margin: .3rem 0; }
  .payouts strong { margin-inline-start: auto; }
  .historical-results { grid-area: auto; grid-column: 1 / -1; }
  .numbered-actions { list-style: none; padding-inline-start: 0; }
  .numbered-actions strong { color: #efd29f; margin-inline-end: .45rem; }
  .activity li { margin: .25rem 0; }
  .winner { font-size: 1.4rem; }
  .standings { list-style: none; margin: .6rem 0 1rem; padding: 0; }
  .standings li { display: flex; justify-content: space-between; padding: .45rem 0; border-bottom: 1px solid #ae93715c; }
  .practice:has(.standings) { grid-template-areas: "title title" "seasons seasons" "auction market" "activity activity"; }
  @media (max-width: 700px) {
    .practice {
      grid-template-columns: minmax(0, 1fr);
      grid-template-areas: "title" "seasons" "auction" "hand" "seats" "market" "activity";
    }
    .practice:has(.standings) { grid-template-areas: "title" "seasons" "auction" "market" "activity"; }
    .seats { grid-template-columns: 1fr; }
  }
</style>
