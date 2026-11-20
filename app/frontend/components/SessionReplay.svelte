<script>
  import { onDestroy } from "svelte"

  export let initial
  export let replayPath
  export let branchPath = null
  export let branchToken = null
  export let lineage = null
  let frame = initial
  let jump = initial.cursor
  let pending = false
  let error = ""
  let request
  let original = null
  let comparisonError = ""

  async function compare() {
    comparisonError = ""
    try {
      const response = await fetch(lineage.path, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error()
      original = await response.json()
    } catch {
      comparisonError = "Could not load the original fork."
    }
  }

  function label(value) {
    return value?.replaceAll("_", " ") ?? "—"
  }

  function date(value) {
    return new Date(value).toLocaleString()
  }

  async function seek(cursor) {
    if (!Number.isInteger(cursor) || cursor < 1 || cursor > frame.last) return

    request?.abort()
    const controller = new AbortController()
    request = controller
    pending = true
    error = ""
    try {
      const response = await fetch(`${replayPath}?frame=${cursor}`, {
        headers: { Accept: "application/json" }, signal: controller.signal
      })
      if (!response.ok) throw new Error("Could not load this frame.")
      const result = await response.json()
      if (controller.signal.aborted) return

      frame = result
      jump = result.cursor
      history.replaceState(null, "", `${replayPath}?frame=${result.cursor}`)
    } catch (failure) {
      if (!controller.signal.aborted) error = failure.message
    } finally {
      if (request === controller) pending = false
    }
  }

  onDestroy(() => request?.abort())
</script>

{#if lineage}
  <p>Private experimental branch · Forked at frame {lineage.fork} · Rules v{lineage.rulesVersion}</p>
  {#if lineage.path}
    <a href={lineage.path}>Original timeline</a>
    <button type="button" onclick={compare}>Compare with original fork</button>
  {/if}
{/if}
<nav aria-label="Replay controls">
  <button type="button" onclick={() => seek(1)} disabled={pending || frame.cursor === 1}>Beginning</button>
  <button type="button" onclick={() => seek(frame.cursor - 1)} disabled={pending || frame.cursor === 1}>Previous</button>
  <button type="button" onclick={() => seek(frame.cursor + 1)} disabled={pending || frame.cursor === frame.last}>Next</button>
  <button type="button" onclick={() => seek(frame.last)} disabled={pending || frame.cursor === frame.last}>End</button>
  <form onsubmit={(event) => { event.preventDefault(); void seek(jump) }}>
    <label for="replay-frame">Frame</label>
    <input id="replay-frame" type="number" min="1" max={frame.last} bind:value={jump} required>
    <button type="submit" disabled={pending}>Go</button>
  </form>
</nav>
<p aria-live="polite">Frame {frame.cursor} of {frame.last}{pending ? " · Loading" : ""}</p>
{#if error}<p role="alert">{error}</p>{/if}
{#if branchPath && frame.branchable}
  <form method="post" action={branchPath}>
    <input type="hidden" name="authenticity_token" value={branchToken}>
    <input type="hidden" name="frame" value={frame.cursor}>
    <button type="submit" disabled={pending}>Create private branch</button>
  </form>
{/if}
{#if comparisonError}<p role="alert">{comparisonError}</p>{/if}
{#if original}
  <section aria-label="Timeline comparison" class="comparison">
    {#each [{ title: "Original fork", state: original }, { title: "Branch frame", state: frame }] as timeline (timeline.title)}
      <div>
        <h3>{timeline.title} {timeline.state.cursor}</h3>
        <p>{label(timeline.state.phase)} · {timeline.state.played.length} {timeline.state.played.length === 1 ? "painting" : "paintings"} played</p>
        <ul>{#each timeline.state.played as card (card.id)}<li>{card.label}</li>{/each}</ul>
      </div>
    {/each}
  </section>
{/if}

<dl class="event">
  <dt>Action</dt><dd>{label(frame.event.action)} ({label(frame.event.kind)})</dd>
  <dt>Actor</dt><dd>{frame.event.actor ?? label(frame.event.actorKind)}</dd>
  <dt>Phase</dt><dd>{label(frame.event.phase)}</dd>
  <dt>Recorded</dt><dd><time datetime={frame.event.recordedAt}>{date(frame.event.recordedAt)}</time></dd>
</dl>
{#if frame.checkpoint !== frame.cursor}<p>State from checkpoint {frame.checkpoint}.</p>{/if}

<section aria-label="Recorded game state">
  <h3>{label(frame.phase)}</h3>
  <ul>
    {#each frame.players as player (player.id)}
      <li>
        <strong>{player.name}</strong>{player.captain ? " · Captain" : ""}{player.id === frame.currentPlayerId ? " · Current turn" : ""}{player.winner ? " · Winner" : ""}
        <span> · {player.handCount} in hand{player.score == null ? "" : ` · Score ${player.score}`}</span>
        {#if player.hand?.length}<ul>{#each player.hand as card (card.id)}<li>{card.label}</li>{/each}</ul>{/if}
      </li>
    {/each}
  </ul>
  <h4>Played paintings</h4>
  {#if frame.played.length}
    <ul>{#each frame.played as card (card.id)}<li>{card.label}</li>{/each}</ul>
  {:else}<p>No paintings played.</p>{/if}
</section>

<section aria-label="Table-captain observations">
  <h3>Table-captain observations</h3>
  {#if frame.observations.length}
    <ul>
      {#each frame.observations as report (report.sequence)}
        <li>
          <strong>{label(report.action)}</strong> · {report.kind === "correction" ? `Correction of frame ${report.corrects}` : "Recorded observation"}
          {report.superseded ? " · Superseded" : ""}
          <p>Frame {report.sequence} · {report.actor ?? "Table captain"} · {label(report.phase)}
            {report.context ? ` · Context frame ${report.context}` : ""} · Recorded {date(report.recordedAt)}
            {report.occurredAt ? ` · Occurred ${date(report.occurredAt)}` : ""}</p>
          <ul>
            {#each Object.entries(report.data) as [key, value] (key)}
              {#if value != null}<li>{label(key.replace(/_id$/, ""))}: {value}</li>{/if}
            {/each}
          </ul>
        </li>
      {/each}
    </ul>
  {:else}<p>No observations at this point.</p>{/if}
</section>

<style>
  nav, form { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem; }
  input { width: 6rem; }
  .event { display: grid; grid-template-columns: max-content 1fr; gap: .2rem 1rem; }
  dd { margin: 0; }
  dt { font-weight: 600; }
  h3, h4, dt { text-transform: capitalize; }
  section { margin-top: 1.5rem; }
  .comparison { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); gap: 1rem; }
</style>
