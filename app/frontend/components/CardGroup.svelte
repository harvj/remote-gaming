<script>
  import CardButton from "./CardButton.svelte";

  export let title;
  export let cards;
  export let loading;
</script>


<div class="card-group">

  <div class="badge badge-light p-2 mt-2">
    {title}
  </div>

  <div class="cards">

    {#each cards as card}

      <CardButton
        {card}
        {loading}
      />

    {/each}

  </div>

</div>
