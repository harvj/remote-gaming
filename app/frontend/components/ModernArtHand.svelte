<script>
  import { onMount } from "svelte"

  let { uid, cards, known = true, children } = $props()
  const sortModes = [
    { label: "Recorded order" },
    { label: "Artist", field: "name" },
    { label: "Auction type", field: "value" }
  ]
  let sortIndex = $state(0)
  let groupByArtist = $state(false)
  const sort = $derived(sortModes[sortIndex])
  const preferenceKey = $derived(`modern-art.hand.${uid}`)
  const groups = $derived.by(() => {
    const { field } = sort
    const ordered = field ? [...cards].sort((first, second) => first[field].localeCompare(second[field])) : cards
    if (!groupByArtist) return [["", ordered]]

    const byArtist = new Map()
    for (const card of ordered) {
      if (!byArtist.has(card.name)) byArtist.set(card.name, [])
      byArtist.get(card.name).push(card)
    }
    return [...byArtist]
  })

  function savePreferences() {
    try { sessionStorage.setItem(preferenceKey, JSON.stringify({ sortIndex, groupByArtist })) }
    catch { /* The preferences still apply to this view. */ }
  }

  function cycleSort() {
    sortIndex = (sortIndex + 1) % sortModes.length
    savePreferences()
  }

  onMount(() => {
    try {
      const preferences = JSON.parse(sessionStorage.getItem(preferenceKey))
      if (preferences && Number.isInteger(preferences.sortIndex) && sortModes[preferences.sortIndex]) {
        sortIndex = preferences.sortIndex
        groupByArtist = preferences.groupByArtist === true
      }
    } catch { /* Use the default hand presentation. */ }
  })
</script>

{#if known}
  <div class="hand-options">
    <button type="button" onclick={cycleSort}>Sort hand: {sort.label}</button>
    <label><input type="checkbox" checked={groupByArtist} onchange={(event) => {
      groupByArtist = event.currentTarget.checked
      savePreferences()
    }} /> Group by artist</label>
  </div>
{/if}
{@render children(groups)}

<style>
  .hand-options { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem 1rem; margin-top: .5rem; }
  label { display: inline-flex; align-items: center; gap: .35rem; min-height: 44px; }
  button {
    min-height: 44px; padding: .45rem .65rem; border: 1px solid var(--oak-line);
    border-radius: var(--oak-radius-control); color: var(--oak-text); background: #493628; font: inherit;
  }
</style>
