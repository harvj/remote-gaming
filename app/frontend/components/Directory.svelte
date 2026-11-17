<script>
  let { title, games, gamePage } = $props()
</script>

<div class="directory">
  {#if gamePage}
    <a href="https://radioactivita.com/">Remote Gaming directory</a>
  {/if}
  <h1>{title}</h1>
  {#if !gamePage}<p>What are we playing?</p>{/if}
  <ul class:cards={!gamePage} role="list">
    {#each games as game (game.slug)}
      <li>
        {#if !gamePage}<h2>{game.title}</h2>{/if}
        <p>{game.description}</p>
        {#if game.available && !gamePage}
          <p class="status">Available · <a href={game.destination}>Open {game.title}</a></p>
        {:else if !game.available}
          <p class="status">Not yet available</p>
        {/if}
      </li>
    {/each}
  </ul>
</div>

<style>
  :global(body) {
    margin: 0;
    background: #f5f4ee;
    color: #242823;
    font: 1rem/1.55 system-ui, sans-serif;
  }

  .directory {
    max-width: 65rem;
    margin-inline: auto;
    padding: clamp(1rem, 6vw, 4rem);
  }

  h1, h2 { line-height: 1.15; }
  h1 { font-size: clamp(2rem, 7vw, 4rem); margin-block: 0.4em 0.2em; }
  h2 { margin-top: 0; font-size: 1.3rem; }
  ul { list-style: none; padding: 0; }

  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(100%, 17rem), 1fr));
    gap: 1rem;
    margin-top: 2rem;
  }

  .cards li {
    padding: 1.25rem;
    background: #fff;
    border: 1px solid #a9ada4;
    border-radius: 0.65rem;
  }

  .status { font-weight: 600; }
  a { color: #245339; text-underline-offset: 0.18em; }
  a:focus-visible { outline: 3px solid currentColor; outline-offset: 4px; }
</style>
