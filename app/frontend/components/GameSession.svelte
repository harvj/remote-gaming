<script>
  import { onMount } from "svelte";
  import { cable } from "../lib/cable"
  import PlayerList from "./PlayerList.svelte";
  import PlayerCards from "./PlayerCards.svelte";

  export let session
  export let token
  export let paths
  export let currentUser

  let subscription
  let loading = new Set();

  let loggedInPlayer = null
  let displayPlayer = null;
  let playerParams = {};
  let cardParams = {};

  let groupCardsBy
  let sortCardsBy
  let showInactiveCards

  $: window.sessionDebug = session
  $: window.playerDebug = loggedInPlayer

  /* --------------------------
     Reactive updates
  ---------------------------*/

  $: if (!session) {
    console.error("GameSession missing session prop");
  }

  $: if (session) {
    displayPlayer =
      loggedInPlayer ||
      session.players?.find(p => p.id === session.currentPlayerId) ||
      session.players?.[0] ||
      null
    showInactiveCards = session.showInactiveCards;
  }

  $: if (session?.players) {
    const updated = session.players.find(p => p.id === displayPlayer?.id)
    if (updated) displayPlayer = updated
  }

  $: if (session?.game) {
    groupCardsBy = session.game.groupCardsBy
    sortCardsBy = session.game.sortCardsBy
  }

  $: loggedInPlayer =
    currentUser &&
    session?.players?.find(p => p.user.username === currentUser?.username
  )

  /* --------------------------
     Backend interaction
  ---------------------------*/

  async function applyAction(path, params = {}, loadingKey = null, method = "PATCH") {
    if (loadingKey) loading.add(loadingKey);

    try {
      const res = await fetch(path, {
        method: method,
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify(params)
      });

      const data = await res.json();

      if (data.status === "success") {
        session = data.content.session;
      }

    } catch (err) {
      console.error(err);
    } finally {
      if (loadingKey) loading.delete(loadingKey);
    }
  }

  function updateSession() {
    applyAction(session.uri, updateParams(), "session");
  }

  function addPlayer() {
    applyAction(paths.playersPath, updateParams(), "join", "POST")
    reconnect()
  }

  function leavePlayer() {
    applyAction(
      loggedInPlayer.playerPath,
      { player_action: "leave_session" },
      "leave"
    )
    reconnect()
  }

  function updateParams() {
    return {
      uid: session.uid,
      authenticity_token: token,
      player: playerParams,
      card: cardParams
    };
  }

  /* --------------------------
     ActionCable subscription
  ---------------------------*/

  function connect() {
    if (!session?.uid) return

    subscription = cable.subscriptions.create(
      {
        channel: "GameSessionChannel",
        uid: session.uid
      },
      {
        received(data) {
          console.log("cable update", data)
          session = data
        }
      }
    )
  }

  function disconnect() {
    if (subscription) {
      subscription.unsubscribe()
      subscription = null
    }
  }

  function reconnect() {
    disconnect()
    connect()
  }

  onMount(() => {
    connect()

    return () => {
      disconnect()
    }
  })
</script>


<div id={`game-session-${session.uid}`}>

  <!-- session header -->

  <div class="page-header">

    <h2 class="page-title">
      Session: <span class="name">{session.uid}</span>
    </h2>

    {#if loggedInPlayer && session.playable && !session.started}

      <button
        class="btn btn-primary"
        on:click|preventDefault={updateSession}
      >

        {#if loading.has("session")}
          <i class="fas fa-spinner fa-pulse"></i>
        {:else}
          {session.nextActionPrompt}
        {/if}

      </button>

    {:else}

      {#if session.completed}
        completed: {session.completedAt}
      {:else}
        <div>
          {session.state}
          {#if session.waiting}
            <span class="ellipsis"></span>
          {/if}
        </div>
      {/if}

    {/if}

  </div>


  <section class="panel ghost row-split">
    <!-- player list -->

    <div class="row-left gap-sm">
      <PlayerList
        {session}
        {currentUser}
        bind:displayPlayer
      />
    </div>

    <div class="row-right">
      {#if currentUser && session.joinable}

        {#if loggedInPlayer && !session.started}

          <!-- Leave -->

          <button
            class="btn btn-primary"
            on:click|preventDefault={leavePlayer}
          >
            {#if loading.has("leave")}
              <i class="fas fa-spinner fa-pulse"></i>
            {:else}
              Leave
            {/if}
          </button>

        {:else if !loggedInPlayer}

          <!-- Join -->

          <button
            class="btn btn-primary"
            on:click|preventDefault={addPlayer}
          >
            {#if loading.has("join")}
              <i class="fas fa-spinner fa-pulse"></i>
            {:else}
              Join
            {/if}
          </button>

        {/if}

      {/if}
    </div>

  </section>

  {#if !currentUser}
    <section class="panel ghost">
      <a href="{paths.loginPath}">Log in to join this session</a>
    </section>
  {/if}

  <!-- cards -->

  {#if displayPlayer && session.started}

    <PlayerCards
      {session}
      {displayPlayer}
      {currentUser}
      {loading}
      {groupCardsBy}
      {sortCardsBy}
      {showInactiveCards}
    />

  {/if}

</div>
