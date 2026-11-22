<script>
  import { onMount } from "svelte"
  import { cable } from "../lib/cable"
  import { artistColors } from "../lib/modernArtPalette"
  import ModernArtCard from "./ModernArtCard.svelte"

  let { board: initial, uid, endpoint, rulesUrl, lobbyUrl, token } = $props()
  const initialBoard = () => initial
  let board = $state(initialBoard())
  let amount = $state("")
  let busy = $state(false)
  let message = $state("")
  let unavailable = $state(false)

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
    if (busy || unavailable) return

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
    const subscription = cable.subscriptions.create({ channel: "ModernArtPracticeChannel", uid }, {
      connected: refresh, received: refresh
    })
    const interval = setInterval(refresh, 10000)
    return () => { subscription.unsubscribe(); clearInterval(interval) }
  })

  function describe(event) {
    if (event.type === "played") return `${label(event.seat)} offered ${event.card.name} · ${event.card.value}.`
    if (event.type === "price") return `${label(event.seat)} set the price at ${cash(event.amount)}.`
    if (event.type === "bid") return `${label(event.seat)} bid ${cash(event.amount)}.`
    if (event.type === "sold") return `${label(event.seat)} acquired ${event.cards.length === 1 ? "one painting" : "two paintings"} for ${cash(event.amount)}.`
    if (event.type === "revealed") return event.amounts.map((value, seat) => `${label(seat)} ${cash(value)}`).join(" · ")
    return "The bank settled this season."
  }
</script>

{#if unavailable}
  <p class="panel" role="alert">This private table is no longer available. <a href={lobbyUrl}>Return to practice tables</a>.</p>
{:else}
  <article class="practice">
    <header class="heading">
      <div>
        <a href={lobbyUrl}>Practice tables</a>
        <h1>Modern Art</h1>
      </div>
      <a class="rules" href={rulesUrl}>Rules reference</a>
    </header>

    <ol class="seasons" aria-label="Seasons">
      {#each [1, 2, 3, 4] as season}
        <li aria-current={season === board.season ? "step" : undefined} class:current={season === board.season}>Season {season}</li>
      {/each}
    </ol>

    <section class="auction" aria-labelledby="auction-heading">
      <p class="turn">{board.turn == null ? (board.auction ? (board.auction.seller === 0 ? "You’re selling" : `${label(board.auction.seller)} is selling`) : "The bank") : `${label(board.turn)} · ${board.phase === "scoring" ? "next seller" : "active seat"}`}</p>
      <h2 id="auction-heading">{phases[board.phase][0]}</h2>
      <p aria-live="polite">{phases[board.phase][1]}</p>

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
        <p>Your bank payout <strong>{cash(summary.payouts[0])}</strong></p>
        <button class="action" disabled={busy} onclick={() => send("advance")}>{board.season === 4 || board.players.every(player => player.handCount === 0) ? "Reveal results" : "Continue to next season"}</button>
      {/if}

      {#if board.phase === "complete"}
        <p class="winner">{winners.map(player => label(player.seat)).join(" and ")} {winners.length > 1 ? "tie" : winners[0].seat === 0 ? "win" : "wins"} with {cash(winners[0].cash)}.</p>
        <ol class="standings" aria-label="Final cash balances">
          {#each standings as player (player.seat)}
            <li><span>{label(player.seat)}</span><strong>{cash(player.cash)}</strong></li>
          {/each}
        </ol>
        <a href={lobbyUrl}>Return to practice tables</a>
      {/if}
    </section>

    <aside class="market" aria-labelledby="market-heading">
      <h2 id="market-heading">Artist market</h2>
      <table>
        <thead><tr><th scope="col">Artist</th><th scope="col">Played</th><th scope="col">Tiles</th></tr></thead>
        <tbody>
          {#each artists as [key, name, color]}
            <tr>
              <th scope="row"><span class="marker" style:background={artistColors[color]}></span>{name}</th>
              <td>{board.market[key] ?? 0}</td>
              <td>{board.seasons.map(season => season.tiles[key]).filter(Boolean).join(" + ") || "—"}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </aside>

    {#if board.phase !== "complete"}
      <section class="hand" aria-labelledby="hand-heading">
        <div class="heading hand-heading">
          <h2 id="hand-heading">Your hand <small>{board.hand.length} paintings</small></h2>
          <strong>{cash(board.players[0].cash)} available</strong>
        </div>
        <div class="cards">
          {#each board.hand as card (card.id)}
            {@const playable = board.legal.card_ids?.includes(card.id)}
            <ModernArtCard {card} onplay={playable ? () => send("play", card.id) : null} disabled={busy} />
          {/each}
          {#if board.hand.length === 0}<p>No cards in hand. You can still bid when eligible.</p>{/if}
        </div>
      </section>

      <section class="seats" aria-label="Museums">
        {#each board.players as player (player.seat)}
          <article class:active={board.turn === player.seat}>
            <h2>{label(player.seat)}</h2>
            <p>{player.handCount} in hand · {player.holdings.length} acquired</p>
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

    {#if board.recent.length}
      <section class="activity">
        <h2>Recent actions</h2>
        <ol>
          {#each [...board.recent].reverse() as event}<li>{describe(event)}</li>{/each}
        </ol>
      </section>
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
  .practice a { color: var(--oak-link); }
  .heading { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: .75rem; }
  .heading h1, .practice h2, .winner { font-family: Fraunces, Georgia, serif; }
  .heading h1 { margin: .15rem 0; font-size: clamp(2.2rem, 5vw, 3.45rem); line-height: 1; }
  .rules { padding: .65rem .85rem; border: 1px solid var(--oak-line); border-radius: var(--oak-radius-control); }
  .seasons { display: grid; grid-template-columns: repeat(4, 1fr); gap: .4rem; padding: 0; margin: 0; list-style: none; }
  .seasons li { border-radius: var(--oak-radius-control); background: var(--oak-nested); padding: .55rem .3rem; text-align: center; font-size: .83rem; }
  .seasons .current { background: #e4c593; color: #322116; font-weight: 700; }
  .auction, .market, .hand, .activity, .seats article {
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
  .practice button:not([data-card-id]), .practice input {
    min-height: 44px; padding: .45rem .65rem; border: 1px solid var(--oak-line);
    border-radius: var(--oak-radius-control); color: var(--oak-text); background: #493628; font: inherit;
  }
  .practice input { width: 7rem; }
  .practice button.action { background: #efd29f; color: #2c1b12; font-weight: 700; }
  .practice button:disabled { cursor: wait; }
  .practice th, .practice td { text-align: left; padding: .45rem .22rem; border-bottom: 1px solid #ae93715c; }
  .practice table { width: 100%; border-collapse: collapse; font-size: .84rem; margin-block-start: .45rem; }
  .practice th[scope="row"] { font-weight: 600; }
  .marker { display: inline-block; width: .56em; height: .56em; border-radius: 50%; margin-inline-end: .42em; vertical-align: .12em; }
  .hand-heading small { font: 500 .78rem system-ui; margin-inline-start: .3rem; }
  .seats { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: .55rem; }
  .seats article { border-radius: var(--oak-radius-section); background: var(--oak-nested); }
  .seats article.active { border-color: #ecc081; }
  .payouts { list-style: none; padding: 0; }
  .payouts li { display: flex; align-items: center; gap: .35rem; margin: .3rem 0; }
  .payouts strong { margin-inline-start: auto; }
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
