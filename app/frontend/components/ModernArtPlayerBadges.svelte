<script>
  export let metadata
</script>
{#if metadata}
  <ul class="badges" aria-label="Player badges">
    {#if metadata.turnOrder != null}<li class="badge" aria-label="Seat order">#{metadata.turnOrder}</li>{/if}
    {#if metadata.role?.imagePath}
      <li><img src={metadata.role.imagePath} alt={metadata.role.name} title={metadata.role.name} height="24" /></li>
    {:else if metadata.role}<li class="badge {metadata.role.color ?? ''}">{metadata.role.name}</li>{/if}
    {#if metadata.captain}<li class="badge">Captain</li>{/if}
    {#if metadata.winner}<li class="badge gold">Winner</li>{/if}
    {#if metadata.score != null}<li class="badge black" title="Recorded score">{metadata.score}</li>{/if}
    {#each metadata.badges ?? [] as badge}
      <li class="badge {badge.color ?? ''}" title={badge.icon_class?.replaceAll("-", " ") ?? "Statistic"}>
        {#if badge.icon_class}<i class={"fas fa-" + badge.icon_class} aria-hidden="true"></i>{/if}
        {badge.symbol ?? ""} {badge.value}
      </li>
    {/each}
    {#if metadata.lastWinDate}<li class="badge {metadata.lastWinDateClass}" title="Recorded last win">{metadata.lastWinDate}</li>{/if}
  </ul>
{/if}
<style>
  .badges { display: flex; align-items: center; flex-wrap: wrap; gap: .35rem .45rem; list-style: none; padding: 0; margin: .5rem 0; }
  img { display: block; width: auto; height: 24px; }
  .badge.red { background: #ff0000; color: #fff; }
  .badge.crimson { background: crimson; color: #fff; }
  .badge.orange { background: #fd6a02; color: #fff; }
  .badge.gold { background: goldenrod; color: #111; }
  .badge.green { background: #4ac948; color: #fff; }
  .badge.magenta { background: #e514a3; color: #fff; }
  .badge.white { background: #fff; color: #111; }
  .badge.bisque { background: bisque; color: #111; }
  .badge.darkgreen { background: darkgreen; color: #fff; }
  .badge.brown { background: #8b4513; color: #fff; }
  .badge.black { background: #111; color: #fff; }
  .badge.green1 { background: #69b34c; color: #fff; }
  .badge.green2 { background: #acb334; color: #fff; }
  .badge.yellow1 { background: #c9a036; color: #fff; }
  .badge.yellow2 { background: #fab733; color: #fff; }
  .badge.orange1 { background: #ff8e15; color: #fff; }
  .badge.orange2 { background: #ff4e11; color: #fff; }
  .badge.red1 { background: #ff0d0d; color: #fff; }
  .badge.lite-metal { color: hsl(from #d1d322 h s calc(l - 20)); background: hsl(from #d1d322 h s calc(l + 30)); }
  .badge.yoko { color: hsl(from #5be67e h s calc(l - 30)); background: hsl(from #5be67e h s calc(l + 25)); }
  .badge.cristin-p { color: hsl(from #ff0000 h s calc(l - 20)); background: hsl(from #ff0000 h s calc(l + 35)); }
  .badge.karl-gitter { color: hsl(from #c0afef h s calc(l - 20)); background: hsl(from #c0afef h s calc(l + 10)); }
  .badge.krypto { color: hsl(from #d7ae85 h s calc(l - 30)); background: hsl(from #d7ae85 h s calc(l + 20)); }
</style>
