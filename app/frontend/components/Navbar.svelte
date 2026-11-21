<script>
  import { watchApplications } from "../shell_applications.js";
  import { onMount, onDestroy } from "svelte";

  export let currentUser = null;
  export let currentGame = null;
  export let loginPath = null;
  export let csrfToken = null;

  let menuOpen = false;
  let menuEl;
  let menuButton;

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
    if (event.key === "Escape" && menuOpen && menuEl?.contains(document.activeElement)) {
      menuButton.focus();
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
    <a class="brand" href="/">remote-gaming.</a>

    {#if currentGame}
      <span class="separator">|</span>
      <span class="game-title">
        <a href={currentGame.uri}>{currentGame.name}</a>
      </span>
    {/if}
  </div>

  <div class="nav-right">
    {#if currentUser}
      {#if !currentUser.canonical}<div>Logged in as <strong>{currentUser.name}</strong></div>{/if}
      <div class="nav-menu" bind:this={menuEl}>
        <button
          type="button"
          class={currentUser.canonical ? "shell-account-button" : "gear-button"}
          bind:this={menuButton}
          aria-label={currentUser.canonical ? currentUser.name : "Open user menu"}
          aria-controls={menuOpen ? "navbar-account-controls" : undefined}
          aria-expanded={menuOpen}
          on:click|stopPropagation={toggleMenu}
        >
          {#if currentUser.canonical}
            <span class="shell-session-dot" aria-hidden="true"></span>
            <span class="shell-username">{currentUser.name}</span>
            <span aria-hidden="true">⌄</span>
          {:else}
            <i class="fa-solid fa-gear"></i>
          {/if}
        </button>

        {#if menuOpen}
          <div class="dropdown-menu" id="navbar-account-controls">
            {#if currentUser.applicationsPath}
              <section aria-label="Applications" data-shell-applications={currentUser.applicationsPath} use:watchApplications hidden>
                <strong>Applications</strong><ul></ul>
              </section>
            {/if}
            {#if currentUser.profilePath}
              <a href={currentUser.profilePath} class="dropdown-item" on:click={closeMenu}>
                {currentUser.canonical ? "Remote Gaming settings" : "Profile"}
              </a>
            {/if}

            {#if currentUser.accountPath}
              <a href={currentUser.accountPath} class="dropdown-item">Account Settings</a>
            {/if}

            <form method="post" action={currentUser.logoutPath} class="dropdown-form">
              <input type="hidden" name="_method" value="delete" />
              {#if csrfToken}
                <input type="hidden" name="authenticity_token" value={csrfToken} />
              {/if}

              <button type="submit" class="dropdown-item dropdown-button">
                {currentUser.canonical ? "Log Out" : "Logout"}
              </button>
            </form>
          </div>
        {/if}
      </div>
    {:else if loginPath}
      <a class="nav-login" href={loginPath}>Log In</a>
    {/if}
  </div>
</div>
