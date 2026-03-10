<script>
  import GameSessionRow from "../components/GameSessionRow.svelte"

  export let game
  export let paths
  export let token

  let showArchived = false

  $: waitingSessions = game.sessions.filter(s => s.waiting)
  $: activeSessions = game.sessions.filter(s => s.active)
  $: completedSessions = game.sessions.filter(s => s.completed)

  function toggleArchived() {
    showArchived = !showArchived
  }

  function handleDelete(event) {
    const uid = event.detail

    game.sessions = game.sessions.filter(s => s.uid !== uid)
  }
</script>

<div id={`game-${game.key}`}>

  <header class="page-header">
    <h2 class="page-title">Sessions</h2>

    <form method="post" action={paths.gameSessionsPath}>
      <input type="hidden" name="authenticity_token" value={token} />
      <input type="hidden" name="game_key" value={game.key} />

      <button type="submit" class="btn btn-primary">
        Create New +
      </button>
    </form>
  </header>

  {#if waitingSessions.length > 0}
    <section class="panel waiting">
      <h5 class="panel-title">Waiting for players...</h5>

      {#each waitingSessions as session (session.uid)}
        <GameSessionRow {session} on:deleted={handleDelete}/>
      {/each}
    </section>
  {/if}

  {#if activeSessions.length > 0}
    <section class="panel active">
      <h5>In Progress</h5>

      {#each activeSessions as session (session.uid)}
        <GameSessionRow {session}/>
      {/each}
    </section>
  {/if}

  {#if completedSessions.length > 0}
    <section class="panel completed">
      <h5>Completed</h5>

      {#each completedSessions as session (session.uid)}
        {#if !session.archived || showArchived}
          <GameSessionRow {session}/>
        {/if}
      {/each}

      <div class="archive-toggle">
        <a href="#" on:click|preventDefault={toggleArchived}>
          {showArchived ? "Hide" : "Show"} Archived
        </a>
      </div>
    </section>
  {/if}

</div>

<style>

.waiting {
  background: var(--panel);
}

.active {
  background: #ffeaa7;
}

.completed {
  background: #c8f7c5;
}

.archive-toggle {
  margin-top: 10px;
}

</style>
