<script>
  let { physical, players, busy, onrecord } = $props()

  let type = $state("auction_result")
  let contextId = $state("")
  let occurred = $state("")
  let correctionId = $state(null)
  let data = $state({})
  let expanded = $state(false)

  const labels = { auction_result: "Auction result", payment: "Payment", round_score: "Round score" }
  const fieldLabels = { buyer_id: "Buyer", payer_id: "Payer", payee_id: "Payee", player_id: "Player",
    winning_bid: "Winning bid", amount: "Amount", score: "Score", card_id: "Painting" }

  const contexts = $derived(physical.contexts ?? [])
  const context = $derived(contexts.find(item => item.id === contextId) ?? contexts.at(-1))
  const participants = $derived(Object.fromEntries(players.map(player => [player.id, player.user.name])))

  function start(reportType) {
    type = reportType
    correctionId = null
    data = {}
    occurred = ""
    contextId = contexts.at(-1).id
    expanded = true
  }

  function correct(report) {
    correctionId = report.id
    type = report.type
    contextId = report.contextId
    occurred = ""
    data = { ...report.data }
    expanded = true
  }

  async function record(event) {
    event.preventDefault()
    if (await onrecord({
      type, context_frame_id: context?.id, corrects_frame_id: correctionId,
      occurred_at: occurred ? new Date(occurred).toISOString() : null, data
    })) {
      correctionId = null
      data = {}
      occurred = ""
      expanded = false
    }
  }
</script>

<section class="panel ghost">
  <h3>Table notes</h3>
  <p>{physical.coverage === "unrecorded" ? "Physical activity was not recorded for this historical session." : "Reports are optional. Missing entries leave the physical record incomplete."}</p>
  {#if physical.path && contexts.length}
    <div class="report-actions">
      {#each Object.entries(labels) as [kind, label]}
        <button type="button" onclick={() => start(kind)}>Record {label.toLowerCase()}</button>
      {/each}
    </div>
  {/if}

  {#if expanded && physical.path && context}
    <form onsubmit={record}>
      <h4>{correctionId ? "Correct" : "New"} {labels[type].toLowerCase()}</h4>
      <label>Season and point in play
        <select bind:value={contextId} required>
          {#each contexts as item (item.id)}<option value={item.id}>{item.label}</option>{/each}
        </select>
      </label>
      <label>Event time (optional, local time) <input type="datetime-local" bind:value={occurred} /></label>

      {#snippet playerField(field, optional = false)}
        <label>{fieldLabels[field]}
          <select id={`observation-${field}`} bind:value={data[field]} required={!optional}>
            <option value={null}>{optional ? "Bank / no player" : "Select a player"}</option>
            {#each players as player (player.id)}<option value={player.id}>{player.user.name}</option>{/each}
          </select>
        </label>
      {/snippet}

      {#if type === "auction_result"}
        <label>Painting
          <select bind:value={data.card_id} required>
            <option value={null}>Select a played painting</option>
            {#each context.cards as card (card.id)}<option value={card.id}>{card.label}</option>{/each}
          </select>
        </label>
        {@render playerField("buyer_id")}
        <label>Winning bid <input type="number" min="0" step="1" required bind:value={data.winning_bid} /></label>
      {:else if type === "payment"}
        {@render playerField("payer_id")}
        {@render playerField("payee_id", true)}
        <label>Amount <input id="observation-amount" type="number" min="0" step="1" required bind:value={data.amount} /></label>
      {:else}
        {@render playerField("player_id")}
        <label>Round score <input type="number" min="0" step="1" required bind:value={data.score} /></label>
      {/if}

      <button class="btn btn-primary" disabled={busy}>Save report</button>
      <button type="button" onclick={() => expanded = false}>Cancel</button>
    </form>
  {/if}

  <ul>
    {#each physical.observations as report (report.id)}
      <li>
        <strong>{labels[report.type]}</strong> · {report.phase.replaceAll("_", " ")} ·
        {report.provenance === "correction" ? "Corrected report" : "Participant report"}
        <dl>
          {#each Object.entries(report.data) as [field, value]}
            <dt>{fieldLabels[field]}</dt>
            <dd>{field === "card_id" ? report.cardLabel : field.endsWith("_id") ? (participants[value] ?? "Bank") : value}</dd>
          {/each}
        </dl>
        Recorded by {participants[report.actorId]} at <time datetime={report.recordedAt}>{new Date(report.recordedAt).toLocaleString()}</time>
        {#if report.occurredAt}<span> · Event at <time datetime={report.occurredAt}>{new Date(report.occurredAt).toLocaleString()}</time></span>{/if}
        {#if physical.path}<button type="button" onclick={() => correct(report)}>Correct</button>{/if}
      </li>
    {/each}
  </ul>
</section>

<style>
  form, label { display: grid; gap: .4rem; }
  form { max-width: 25rem; }
  .report-actions { display: flex; flex-wrap: wrap; gap: .4rem; }
  dt { font-weight: 600; }
</style>
