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

</script>

<div id={`game-${game.key}`}>

  <header class="page-header">
    <h1 class="page-title">Sessions</h1>

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
      <h5 class="panel-title">
        Waiting for players<span class="ellipsis"></span>
      </h5>

      {#each waitingSessions as session (session.uid)}
        <GameSessionRow {session}/>
      {/each}
    </section>
  {/if}

  {#if activeSessions.length > 0}
    <section class="panel active">
      <h5 class="panel-title">
        In Progress<span class="ellipsis"></span>
      </h5>

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
        <button type="button" onclick={toggleArchived}>
          {showArchived ? "Hide" : "Show"} Archived
        </button>
      </div>
    </section>
  {/if}

</div>

<style>

.archive-toggle {
  margin-top: 10px;
}

</style>
