<script>
  import { createEventDispatcher } from "svelte"
  import RelativeTime from "../helpers/RelativeTime.svelte";

  export let session

  const containerId = `session-${session.uid}-row`

  const showPlayerCount = session.playerCount > 0
  const showWinner = session.winnerImagePath && session.winnerInitials

  let playerCountClass = "badge"

  if (session.active) playerCountClass += " badge-bisque"
  if (session.completed) playerCountClass += " badge-darkgreen"

  const dispatch = createEventDispatcher()
  const csrfToken = document.querySelector("meta[name='csrf-token']").content

  async function destroySession() {
    const res = await fetch(session.uri, {
      method: "DELETE",
      headers: { "X-CSRF-Token": csrfToken }
    })

    if (res.ok) {
      dispatch("deleted", session.uid)
    }
  }
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

    {#if !session.completed}
      <a
        href={session.uri}
        data-method="delete"
        class="btn-ghost danger"
        on:click|preventDefault={() => destroySession()}
      >
        <i class="fa-solid fa-trash"></i>
      </a>
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
