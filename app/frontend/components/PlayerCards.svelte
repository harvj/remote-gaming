<script>
  import CardGroup from "./CardGroup.svelte";

  export let session;
  export let displayPlayer;
  export let currentUser;
  export let loading;
  export let groupCardsBy;
  export let sortCardsBy;
  export let showInactiveCards;

  $: activeCards = groupCards(displayPlayer?.activeCards ?? [])
  $: inactiveCards = groupCards(displayPlayer?.inactiveCards ?? []);

  function groupCards(cards) {

    const groups = {};

    for (const card of cards) {

      const key = card[groupCardsBy];

      if (!groups[key]) groups[key] = [];

      groups[key].push(card);
    }

    return Object.entries(groups).map(([title, cards]) => ({
      title,
      cards
    }));
  }
</script>


<div class="player-cards">

  <h3>{displayPlayer.user.name}'s cards</h3>

  {#each activeCards as group}

    <CardGroup
      title={group.title}
      cards={group.cards}
      {loading}
    />

  {/each}


  {#if showInactiveCards}

    {#each inactiveCards as group}

      <CardGroup
        title={group.title}
        cards={group.cards}
        {loading}
      />

    {/each}

  {/if}

</div>
