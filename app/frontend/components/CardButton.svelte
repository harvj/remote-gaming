<script>
  export let card;
  export let loading;

  function cardClass() {
    return `
      btn btn-primary my-1
      ${card.color || ""}
      ${card.played || card.discarded ? "deemphasized" : ""}
    `;
  }
</script>


<button class={cardClass()}>

  {#if loading.has(card.id)}

    <i class="fas fa-spinner fa-pulse"></i>

  {:else}

    <i class={"fas fa-" + card.iconClass}></i>
    {card.name}

  {/if}

</button>
