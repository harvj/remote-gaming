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

[![CI](https://github.com/harvj/remote-gaming/actions/workflows/ci.yml/badge.svg)](https://github.com/harvj/remote-gaming/actions/workflows/ci.yml)

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

A session stores the current state of play, while game-specific engines define rules, phase transitions, and player actions. Significant actions are recorded as session events and exposed to the frontend as structured API data.

---

## Architecture Overview

        Player Action
             │
             ▼
    Game Specific Engine
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

This structure keeps the system centered on **state transitions and event history**, rather than tying it to a specific frontend.

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

## Game Engine

Game-specific rules live in dedicated engine classes.

Each game defines:

- phase sequences
- player actions
- card behavior
- game-specific rule hooks

The shared engine layer provides common session flow and transition behavior, while individual games implement their own rules on top of it.

---

## Session Events

Every significant action is recorded as a session event / frame.

Examples:

- card played
- player passed
- phase advanced
- turn advanced

This event history supports:

- play logs
- debugging
- analytics
- replay-friendly design

## Services

Mutation logic is handled through service objects where appropriate, keeping controllers thin and domain behavior explicit.

## Representers

API serialization is handled through representers that define the exact structures exposed to the frontend.

## Query Objects

Analytics and reporting queries live separately from the domain models.

---

# Stack

Current implementation:


- Rails 8
- PostgreSQL
- Svelte


The Rails backend manages game sessions and exposes structured game state while the Svelte frontend provides the user interface.

---

# Current Games

Initial supported games:

- Modern Art
- Pandemic

The goal is to support new games by implementing a new game-specific engine rather than building an entirely new application.

---

# Status

This repository is the **modern rebuild** of an earlier prototype.

The previous implementation lives in `remote-gaming-v1`

The new version modernizes the stack and simplifies the frontend while preserving the core game session engine architecture.
