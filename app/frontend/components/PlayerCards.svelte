<script>
  import ModernArtHand from "./ModernArtHand.svelte"
  import ModernArtCard from "./ModernArtCard.svelte"
  export let session
  export let displayPlayer
  export let groupCardsBy
  export let sortCardsBy
  export let showInactiveCards
  export let playable
  export let ongroup
  export let onsort
  export let ontoggle
  export let onplay
  export let embedded = false

  $: active = displayPlayer.activeCards ?? []
  $: inactive = displayPlayer.inactiveCards ?? []
  $: groups = group(active, groupCardsBy, sortCardsBy)
  $: inactiveGroups = group(inactive, groupCardsBy, sortCardsBy)

  const groupOrder = { status: "status", name: "nameSort", value: "valueSort", dealtDuringState: "dealtAt" }

  function compare(a, b, by) {
    return (a[by] > b[by]) - (a[by] < b[by]) || a.id - b.id
  }

  function group(cards, key, sort) {
    const groups = new Map()
    for (const card of [...cards].sort((a, b) => compare(a, b, groupOrder[key]))) {
      if (!groups.has(card[key])) groups.set(card[key], [])
      groups.get(card[key]).push(card)
    }
    return [...groups].map(([title, items]) => [title, items.sort((a, b) => compare(a, b, sort))])
  }
</script>

<section class="player-cards" class:panel={!embedded} class:ghost={!embedded}>
  {#if !embedded}
    <h3>{displayPlayer.user.name}’s cards</h3>
    <p>{active.length} cards in hand</p>
  {/if}

  {#snippet cardGroups(entries, actionable)}
    <div class:compact={embedded}>
      {#each entries as [title, cards] (title)}
        <div class="hand-group">
          {#if title}<h4>{title}</h4>{/if}
          <ul class="hand" role="list">
            {#each cards as card (card.id)}
              <li>
                {#if session.game.key === "modern_art" || embedded}
                  <ModernArtCard {card} onplay={actionable ? onplay : null} disabled={card.validAction !== "play"} />
                {:else}
                  <button class="btn btn-primary {card.color ?? ''}" type="button" data-card-id={card.id}
                    disabled={!actionable || card.validAction !== "play"}
                    onclick={() => onplay(card)}>
                    <i class={"fas fa-" + card.iconClass} aria-hidden="true"></i>
                    {card.name} · {card.value}
                  </button>
                {/if}
              </li>
            {/each}
          </ul>
        </div>
      {/each}
    </div>
  {/snippet}

  {#if session.game.key === "modern_art"}
    <ModernArtHand uid={session.uid} cards={active}>
      {#snippet children(entries)}
        {@render cardGroups(entries, playable)}
      {/snippet}
    </ModernArtHand>
  {:else}
    <p>
      Grouped by <button type="button" onclick={ongroup}>{session.terms[groupCardsBy]}</button>
      and sorted by <button type="button" onclick={onsort}>{session.terms[sortCardsBy]}</button>
    </p>
    {@render cardGroups(groups, playable)}
  {/if}
  {#if inactive.length}
    <button type="button" aria-expanded={showInactiveCards} onclick={ontoggle}>
      {showInactiveCards ? "Hide" : "Show"} inactive cards
    </button>
    {#if showInactiveCards}{@render cardGroups(inactiveGroups, false)}{/if}
  {/if}
</section>

<style>
  .compact { display: flex; flex-wrap: wrap; gap: .55rem 1.05rem; }
  .compact h4 { margin: .35rem 0 .3rem; font-size: .78rem; }
  .compact .hand { margin: 0; }
  .hand-group { margin-top: .4rem; }
  .hand { display: flex; flex-wrap: wrap; gap: .4rem; list-style: none; padding: 0; }
</style>
