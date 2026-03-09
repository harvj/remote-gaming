<script>
  export let initSession

  const session = initSession

  const containerId = `session-${session.uid}-row`

  const showPlayerCount = session.playerCount > 0
  const showWinner = session.winnerImagePath && session.winnerInitials

  let playerCountClass = "badge"

  if (session.active) playerCountClass += " badge-bisque"
  if (session.completed) playerCountClass += " badge-darkgreen"
</script>

<div id={containerId} class="session-row">

  <div class="session-left">

    {#if showPlayerCount}
      <span class={playerCountClass}>
        {session.playerCount}er
      </span>
    {/if}

    {#if showWinner}
      <img
        class="winner-icon"
        src={session.winnerImagePath}
        height="20"
      />

      <span class="badge gold">
        {session.winnerInitials}
      </span>
    {/if}

    <span class="session-link">
      <a href={session.uri}>{session.uid}</a>
    </span>

  </div>

  <div class="session-right">

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

    {#if !session.completed}
      <a
        href={session.uri}
        data-method="delete"
        class="btn-ghost danger"
      >
        <i class="fa-solid fa-trash"></i>
      </a>
    {/if}

  </div>

</div>
