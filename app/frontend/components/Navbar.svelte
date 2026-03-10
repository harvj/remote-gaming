<script>
  import { onMount, onDestroy } from "svelte";

  export let currentUser = null;
  export let currentGame = null;
  export let rootPath = "/";
  export let loginPath = "/login";
  export let csrfToken = null;

  let menuOpen = false;
  let menuEl;

  function toggleMenu() {
    menuOpen = !menuOpen;
  }

  function closeMenu() {
    menuOpen = false;
  }

  function handleDocumentClick(event) {
    if (!menuEl) return;
    if (!menuEl.contains(event.target)) {
      closeMenu();
    }
  }

  function handleEscape(event) {
    if (event.key === "Escape") {
      closeMenu();
    }
  }

  onMount(() => {
    document.addEventListener("click", handleDocumentClick);
    document.addEventListener("keydown", handleEscape);
  });

  onDestroy(() => {
    document.removeEventListener("click", handleDocumentClick);
    document.removeEventListener("keydown", handleEscape);
  });
</script>

<div class="nav-inner">
  <div class="nav-left">
    <a class="brand" href={rootPath}>remote-gaming</a>

    {#if currentGame}
      <span class="separator">|</span>
      <span class="game-title">
        <a href={currentGame.uri}>{currentGame.name}</a>
      </span>
    {/if}
  </div>

  <div class="nav-right">
    {#if currentUser}
      <div>Logged in as <strong>{currentUser.name}</strong></div>
      <div class="nav-menu" bind:this={menuEl}>
        <button
          type="button"
          class="gear-button"
          aria-label="Open user menu"
          aria-expanded={menuOpen}
          on:click|stopPropagation={toggleMenu}
        >
          <i class="fa-solid fa-gear"></i>
        </button>

        {#if menuOpen}
          <div class="dropdown-menu">
            <a href={currentUser.profilePath} class="dropdown-item" on:click={closeMenu}>
              Profile
            </a>

            <form method="post" action={currentUser.logoutPath} class="dropdown-form">
              <input type="hidden" name="_method" value="delete" />
              {#if csrfToken}
                <input type="hidden" name="authenticity_token" value={csrfToken} />
              {/if}

              <button type="submit" class="dropdown-item dropdown-button">
                Logout
              </button>
            </form>
          </div>
        {/if}
      </div>
    {:else}
      <a href={loginPath}>Log in</a>
    {/if}
  </div>
</div>
