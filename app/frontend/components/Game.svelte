<script>
  import GameSessionRow from "../components/GameSessionRow.svelte"

  export let game
  export let paths
  export let token

  let showArchived = false

  const waitingSessions = game.sessions.filter(s => s.waiting)
  const activeSessions = game.sessions.filter(s => s.active)
  const completedSessions = game.sessions.filter(s => s.completed)

  function toggleArchived() {
    showArchived = !showArchived
  }
</script>

<div class="game" id={`game-${game.key}`}>

  <header class="game-header">
    <h2>{game.name}</h2>

    <form method="post" action={paths.gameSessionsPath}>
      <input type="hidden" name="authenticity_token" value={token} />
      <input type="hidden" name="game_key" value={game.key} />

      <button type="submit" class="new-game">
        New Game
      </button>
    </form>
  </header>

  {#if waitingSessions.length > 0}
    <section class="panel sessions waiting">
      <h5>Waiting for players...</h5>

      {#each waitingSessions as session (session.uid)}
        <GameSessionRow initSession={session}/>
      {/each}
    </section>
  {/if}

  {#if activeSessions.length > 0}
    <section class="sessions active">
      <h5>In Progress</h5>

      {#each activeSessions as session (session.uid)}
        <GameSessionRow initSession={session}/>
      {/each}
    </section>
  {/if}

  {#if completedSessions.length > 0}
    <section class="sessions completed">
      <h5>Completed</h5>

      {#each completedSessions as session (session.uid)}
        {#if !session.archived || showArchived}
          <GameSessionRow initSession={session}/>
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

.game {
  max-width: 900px;
  margin: auto;
}

.game-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.new-game {
  padding: 10px 18px;
  background: black;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 16px;
}

.sessions {
  margin-top: 24px;
  padding: 16px;
  border-radius: 8px;
}

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
