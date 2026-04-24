# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
mix setup          # Install deps + build assets (first-time setup)
mix phx.server     # Start dev server
iex -S mix phx.server  # Start in interactive Elixir shell
mix test           # Run all tests
mix test test/path/to/test_file.exs  # Run a single test file
mix test test/path/to/test_file.exs:42  # Run a single test by line
mix format         # Format code
mix assets.build   # Build CSS and JS
```

## Architecture

**MPG** is a multi-player real-time party games platform built with Phoenix LiveView. It supports three games:

1. **Things** — Players write funny responses to prompts; others guess who wrote what
2. **Quizoots** — AI-generated trivia quizzes on player-chosen topics
3. **Dinner Bingo** — Teams mark bingo cells by sharing stories matching conversation prompts

### Real-Time Stack

- **Phoenix LiveView** handles all real-time UI updates via WebSocket
- **Phoenix PubSub** broadcasts game state changes to all connected players
- **DynamicSupervisor + Registry** manages individual game sessions as supervised GenServer processes
- All game state is held in-memory (no database persistence during a game)
- **OpenAI Responses API** (via `openai_ex`) generates quiz questions and bingo cells

### Game Module Pattern

Each game (`:quizzes`, `:things`, `:bingos`) follows the same structure:

| Module | Role |
|--------|------|
| `MPG.{Game}.State` | Struct holding all game data |
| `MPG.{Game}` | Pure functions for state transitions |
| `MPG.{Game}.Session` | GenServer managing lifecycle, keyed by `server_id` |
| `MPGWeb.{Game}Live` | LiveView — mounts, handles events, renders HEEx |

Player action flow: `LiveView event → Session GenServer → PubSub broadcast → all LiveViews re-render`

### Key Conventions

- **Session IDs**: Random 5-digit integers (10000–99999)
- **Player identity**: HTTP session UUID assigned via `assign_session_id` plug in the router
- **AI mocking in tests**: Use `MPG.AI.MockClient` (via Mox); real OpenAI is never called in tests
- **Bingo types**: `"conversation"`, `"guilty"`, `"unique"` — selectable by the host before game starts
