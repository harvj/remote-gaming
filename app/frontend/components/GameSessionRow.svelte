<script>
  import RelativeTime from "../helpers/RelativeTime.svelte";

  export let session

  const containerId = `session-${session.uid}-row`

  const showPlayerCount = session.playerCount > 0
  const showWinner = session.winnerImagePath && session.winnerInitials

</script>

<div id={containerId} class="session-row">

  <div class="session-left">
    {#if showPlayerCount}
      <span class="badge">
        {session.playerCount}er
      </span>
    {/if}

    {#if showWinner}
      <img
        class="winner-icon"
        src={session.winnerImagePath}
        height="20" alt=""
      />

      <span class="badge gold">
        {session.winnerInitials}
      </span>
    {/if}

    <span class="session-link">
      <a href={session.uri}>{session.uid}</a>
      {#if session.branch} <span>· Branch</span>{/if}
    </span>
  </div>

  <div class="session-right">
    {#if session.waiting}
      <div class="session-date">
        <RelativeTime timestamp={session.createdAt} />
      </div>
    {/if}

    {#if session.active}
      <div class="session-date">
        {session.startedAtDate}
      </div>
    {/if}

    {#if session.completed}
      <div class="session-date">
        {session.completedAtDate}
      </div>
    {/if}

  </div>

</div>

<style>
  .session-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 6px 0;
  }

  .session-left {
    display: flex;
    align-items: center;
    gap: .5rem;
  }

  .session-right {
    display: flex;
    align-items: center;
    gap: .75rem;
  }

  .session-date {
    font-size: .85rem;
    color: var(--muted);
  }
</style>
