<script>
  export let session
  export let currentUser
  export let selectedPlayerId
  export let onselect
</script>

<ul class="player-list" role="list">
  {#each session.players as player (player.id)}
    <li>
      <button class="btn {player.winner ? 'btn-warning' : 'btn-light'}"
        disabled={!session.allowDisplayPlayerSwitching}
        aria-pressed={session.allowDisplayPlayerSwitching ? selectedPlayerId === player.id : undefined}
        onclick={() => onselect(player.id)}>
        {#if player.turnOrder}<span class="badge">{player.turnOrder}</span>{/if}
        {player.user.name}
        {#if player.role?.imagePath}
          <img src={player.role.imagePath} alt={player.role.name} height="24" />
        {:else if player.role}
          <span class="badge {player.role.color ?? ''}">{player.role.name}</span>
        {/if}
        {#if player.captain}<span class="badge">Captain</span>{/if}
        {#if session.active && player.id === session.currentPlayerId}<span class="badge">Current turn</span>{/if}
        {#if player.winner}<span class="badge">Winner</span>{/if}
        {#if player.score != null}<span class="badge">{player.score}</span>{/if}
        {#each player.badges ?? [] as badge}
          {#if currentUser?.config?.showAllBadges || !badge.hideable}
            <span class="badge {badge.color ?? ''}">
              <i class={"fas fa-" + badge.icon_class} aria-hidden="true"></i>
              {badge.symbol ?? ""}
              {currentUser?.config?.showBadgeValues ? badge.value : ""}
            </span>
          {/if}
        {/each}
        {#if currentUser?.config?.showAllBadges && player.lastWinDate}
          <span class="badge {player.lastWinDateClass}">{player.lastWinDate}</span>
        {/if}
      </button>
    </li>
  {/each}
</ul>

<style>
  .player-list { display: flex; flex-wrap: wrap; list-style: none; gap: .5rem; padding: 0; }
  .player-list button:disabled { opacity: 1; cursor: default; }
</style>
