<script>
  export let season = null
</script>

<ol aria-label="Seasons">
  {#each [1, 2, 3, 4] as number}
    <li aria-current={number === season ? "step" : undefined} class:current={number === season}>Season {number}</li>
  {/each}
</ol>

<style>
  ol { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: .4rem; padding: 0; margin: 0; list-style: none; }
  li { border-radius: var(--oak-radius-control, 6px); background: var(--oak-nested, #342b22); padding: .55rem .3rem; text-align: center; font-size: .83rem; }
  .current { background: #e4c593; color: #322116; font-weight: 700; }
</style>
