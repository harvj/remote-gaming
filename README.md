# remote-gaming

Remote Gaming is a **tabletop companion platform** for multiplayer board and card games.

Unlike platforms such as **BoardGameArena**, Remote Gaming does **not attempt to fully simulate games in the browser**. Instead it focuses on the parts of tabletop play that benefit most from software support:

- managing game sessions
- hidden card / deck state
- turn order and phases
- action history
- lightweight coordination for players

Players still use the **physical game components** and track resources like money or board position themselves.

This allows games to be supported with **far less UI complexity** while still providing meaningful digital assistance.

---

# Philosophy

Remote Gaming sits between:

```
fully manual tabletop play
and
fully automated browser implementations
```

The system models **session flow and hidden information**, not every rule or resource in the game.

Example:

For **Modern Art**, the system handles:

- card distribution
- hand state
- turn order
- auction card play history

But it **does not track player money or auction outcomes**, which remain part of the physical tabletop experience.

---

# Architecture

The backend is built around a **game session engine** that models state transitions and player actions.

Each game runs inside a `GameSession` and is controlled by a game-specific rule engine under `Play::*`.

---

## Architecture Overview

        Player Action
             │
             ▼
       Play::<Game>
    (game rule engine)
             │
             ▼
      SessionFrame
       (event log)
             │
             ▼
       GameSession
    (current session state)
             │
             ▼
      Representers
        (API layer)
             │
             ▼
          Svelte UI

The system records **game actions as events** and exposes structured session state to the frontend.

---

# Core Components

## GameSession

Represents a running game.

Responsibilities include:

- managing the player roster
- tracking the current state of the game
- maintaining turn order
- managing decks and cards
- storing event history

A `GameSession` is the primary container for gameplay.

---

## Play Engine

Game rules live under:


```
Play::<Game>
```

Examples:


Play::ModernArt
Play::Pandemic
Play::Arkham


Each game defines:

- phase sequences
- player actions
- card behavior
- game-specific rule hooks

The shared engine logic lives in `Play::Base`.

---

## Event History

Every significant action is recorded as a **SessionFrame**.

Examples:


card_played
player_passed
season_started
turn_advanced


Frames record:

- the action taken
- the acting player
- any affected player
- the session state
- an optional subject (such as a card)

This event log allows:

- play history
- debugging
- analytics
- replay possibilities

---

## Services

Mutation logic is handled through service objects rather than controllers.

Examples:


Services::Create
Services::Update
Services::Build


Services return structured response objects and isolate domain mutations from controllers.

---

## Representers

API serialization is handled through representers instead of controller JSON.

Examples:


Representers::Player
Representers::SessionFrame


Representers define the exact structure exposed to the frontend.

---

## Query Objects

Game statistics and analytics live under:


Query::*


These classes contain reporting queries that do not belong in domain models.

Examples include:

- player performance stats
- turn order statistics
- card usage patterns

---

# Stack

Current implementation:


Rails 8
PostgreSQL
Svelte


The Rails backend manages game sessions and exposes structured game state while the Svelte frontend provides the user interface.

---

# Current Games

Initial supported games:


Modern Art
Pandemic
Arkham Horror (encounter generator)


The engine is designed so new games can be implemented by adding a new `Play::<Game>` class.

---

# Status

This repository is the **modern rebuild** of an earlier prototype.

The previous implementation lives in:


remote-gaming-v1


The new version modernizes the stack and simplifies the frontend while preserving the core game session engine architecture.

If you'd like, I can also give yo
