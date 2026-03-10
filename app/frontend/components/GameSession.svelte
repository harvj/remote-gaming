<script>
  export let session;
</script>

<div id="{`session_${session.uid}`}">

  <header class="page-header">
    <h2 class="page-title">
      {session.uid}
    </h2>
  </header>

  <p>
    <strong>State:</strong> {session.state}
  </p>

  {#if session.currentPlayer}
    <p><strong>Current player:</strong> {session.currentPlayer.user.name}</p>
  {/if}

  <h2>Players</h2>
  <ul>
    {#each session.players || [] as player}
      <li>
        {player.user.name}
        {#if player.turnOrder} — turn {player.turnOrder}{/if}
        {#if player.actionPrompt} — {player.actionPrompt}{/if}
      </li>
    {/each}
  </ul>

  <h2>Recent Events</h2>
  <ul>
    {#each session.playHistory || session.frames || [] as frame}
      <li>
        {frame.action}
        {#if frame.actingPlayer} — {frame.actingPlayer.user.name}{/if}
        {#if frame.state} — {frame.state}{/if}
      </li>
    {/each}
  </ul>

</div>
