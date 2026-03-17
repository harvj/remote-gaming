<script>
  export let session;
  export let currentUser;
  export let displayPlayer;

  function isCurrentPlayer(player) {
    if (!session.started) return false;
    if (session.completed) return false;

    return player.id === session.currentPlayerId;
  }

  function playerButtonClass(player) {
    return `
      btn mr-2 mb-2 text-dark
      ${player.winner ? "btn-warning" : "btn-light"}
    `;
  }

  function handlePlayerClick(player) {
    if (!session.allowDisplayPlayerSwitching) return;
    displayPlayer = player;
  }
</script>


<div class="player-list">

  {#each session.players as player}

    <button
      class={playerButtonClass(player)}
      on:click|preventDefault={() => handlePlayerClick(player)}
    >

      <div>

        {#if player.turnOrder}
          <span class="badge badge-secondary">
            {player.turnOrder}
          </span>
        {/if}

        {#if isCurrentPlayer(player)}
          <i class="fas fa-user-clock"></i>
        {/if}

        {#if player.winner}
          <i class="fas fa-trophy"></i>
        {/if}

        {player.user.name}

      </div>

    </button>

  {/each}

</div>
