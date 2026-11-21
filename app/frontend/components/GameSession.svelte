<script>
  import { onMount } from "svelte"
  import { cable } from "../lib/cable"
  import PlayerList from "./PlayerList.svelte"
  import ModernArtTabletop from "./ModernArtTabletop.svelte"
  import PlayerCards from "./PlayerCards.svelte"
  import PhysicalObservations from "./PhysicalObservations.svelte"

  export let session
  export let token
  export let paths
  export let currentUser

  let busy = false
  let error = ""
  let connectionError = ""
  let score = ""
  let selectedPlayerId
  let groupCardsBy = session.game.groupCardsBy
  let sortCardsBy = session.game.sortCardsBy
  let showInactiveCards = session.showInactiveCards

  const groupNext = { status: "name", name: "value", value: "dealtDuringState", dealtDuringState: "status" }
  const sortNext = { status: "nameSort", nameSort: "valueSort", valueSort: "status" }

  $: player = session.players.find(p => p.user.username === currentUser?.username)
  $: displayPlayer = (session.allowDisplayPlayerSwitching && session.players.find(p => p.id === selectedPlayerId)) || player
  $: actionPrompt = session.started && !session.completed && player?.actionPrompt

  function accept(next) {
    if (next.revision >= session.revision) session = next
  }

  async function refresh() {
    try {
      const response = await fetch(session.uri, { headers: { Accept: "application/json" }, cache: "no-store" })
      if (response.ok) {
        const data = await response.json()
        accept(data.content.session)
        connectionError = ""
      } else {
        connectionError = "This session is no longer accessible."
      }
    } catch {
      connectionError = "Connection interrupted. The session will refresh on reconnect."
    }
  }

  async function submit(path, params = {}, method = "PATCH") {
    if (busy) return false

    busy = true
    error = ""
    try {
      const response = await fetch(path, {
        method,
        headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify(params)
      })
      if (!response.headers.get("content-type")?.includes("application/json")) {
        error = "This action is unavailable. Reload the page to check your session."
        return false
      }
      const data = await response.json()
      if (!response.ok) {
        error = data.errors?.join(". ") || "That action is unavailable."
        return false
      }
      accept(data.content.session)
      return true
    } catch {
      error = "The connection was interrupted. Check the session before trying again."
      return false
    } finally {
      busy = false
    }
  }

  onMount(() => {
    if (session.readOnly) return
    const subscription = cable.subscriptions.create({ channel: "GameSessionChannel", uid: session.uid }, {
      connected: refresh,
      received: refresh
    })
    return () => subscription.unsubscribe()
  })
</script>

<div id={`game-session-${session.uid}`} data-revision={session.revision}>
  {#if actionPrompt}<p class="panel ghost" aria-live="polite">{actionPrompt}</p>{/if}

  <header class="page-header">
    <h2 class="page-title session-title"><a href={session.game.uri}>{session.game.name}</a> · <span class="name">{session.uid}</span></h2>
    {#if session.canStart}
      <button class="btn btn-primary" disabled={busy} onclick={() => submit(session.uri)}>
        {session.nextActionPrompt}
      </button>
    {:else}
      <p aria-live="polite">{session.completed ? `Completed ${session.completedAt}` : session.state}</p>
    {/if}
  </header>

  {#if session.readOnly}<p>This historical session is read-only. Its recorded play history is available, but a complete replay is unavailable.</p>{/if}
  {#if error || connectionError}<p role="alert">{error || connectionError}</p>{/if}

  <section class="panel ghost">
    <p aria-live="polite">{session.playerCount} {session.playerCount === 1 ? "player" : "players"}</p>
    <PlayerList {session} {currentUser} selectedPlayerId={displayPlayer?.id} onselect={(id) => selectedPlayerId = id} />
    {#if session.joinable}
      <button class="btn btn-primary" disabled={busy} onclick={() => submit(paths.playersPath, { uid: session.uid }, "POST")}>Join</button>
    {:else if player && session.waiting && !session.readOnly}
      <button class="btn btn-primary" disabled={busy} onclick={() => submit(player.playerPath, { player_action: "leave_session" })}>Leave</button>
      {#if player.captain}<p>Share this session link to invite players.</p>{/if}
    {/if}
  </section>

  {#if session.promptForPlayerScore && player && player.score == null}
    <form class="panel ghost" onsubmit={(event) => { event.preventDefault(); submit(player.playerPath, { player: { score } }) }}>
      <label for="player-score">Your score</label>
      <input id="player-score" type="number" step="1" required bind:value={score} />
      <button class="btn btn-primary" disabled={busy}>Submit</button>
    </form>
  {/if}

  {#if displayPlayer && session.started}
    {#if displayPlayer.id === player?.id && !session.readOnly}
      {#each player.possibleActions ?? [] as action}
        <button class="btn btn-primary" disabled={busy} onclick={() => submit(player.playPath, { player_action: action })}>
          {action[0].toUpperCase() + action.slice(1)}
        </button>
      {/each}
    {/if}
  {/if}

  {#snippet hand(embedded)}
    <PlayerCards {displayPlayer} {session} {groupCardsBy} {sortCardsBy} {showInactiveCards} {embedded}
      playable={displayPlayer.id === player?.id && !session.readOnly && !session.completed && !busy}
      ongroup={() => groupCardsBy = groupNext[groupCardsBy]}
      onsort={() => sortCardsBy = sortNext[sortCardsBy]}
      ontoggle={() => showInactiveCards = !showInactiveCards}
      onplay={(card) => submit(card.updatePath, { card_action: "play" })} />
  {/snippet}
  {#if session.tabletop}
    {#snippet liveHand()}{@render hand(true)}{/snippet}
    <ModernArtTabletop board={session.tabletop} livePlayerId={displayPlayer?.id ?? null}
      liveHand={displayPlayer && session.started ? liveHand : null} />
  {:else if displayPlayer && session.started}
    {@render hand(false)}
  {/if}

  {#if session.completed && displayPlayer}
    <section class="panel ghost">
      <h3>{displayPlayer.user.name}’s play history</h3>
      <ol>
        {#each displayPlayer.playHistory ?? [] as frame (frame.id)}
          {#if frame.subject}<li>{frame.state} · {frame.subject.value} {frame.subject.name}</li>{/if}
        {/each}
      </ol>
    </section>
  {/if}

  {#if session.physical}
    <PhysicalObservations physical={session.physical} players={session.players} {busy}
      onrecord={(observation) => submit(session.physical.path, { observation }, "POST")} />
  {/if}
</div>

<style>
  .session-title { min-width: 0; overflow-wrap: anywhere; }
</style>
