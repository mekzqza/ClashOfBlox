# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClashOfBlox is a Roblox game (Clash of Clans-inspired base builder) written in **Luau** (strict mode). The project uses **Rojo** to sync source files into Roblox Studio.

## Commands

All tools are managed via `aftman` (see `aftman.toml`).

```bash
rojo serve                      # Start dev server (sync to Roblox Studio)
rojo build -o "Game.rbxlx"     # Build to place file

wally install                   # Install Lua packages into Packages/

zap network.zap                 # Regenerate ZapServer.lua and ZapClient.lua from network.zap schema

selene src/                     # Lint
stylua src/                     # Format
``` 

> No test runner is wired up. `roblox/testez` is a dependency but no test files exist yet.

## Architecture

### Boot Lifecycle

Both server and client follow the same **Init → Start** two-phase lifecycle with timeout protection.

**Server** (`Server.server.luau`): Services are instantiated and booted in layers via `Promise.all`. Layers execute sequentially; services within a layer execute in parallel.

```
Layer 1 (Core):    ServerNetWorkHandler, CmdrService
Layer 2 (Data):    PlayerDataService
Layer 3 (GamePlay): GridService, BuildingService
```

**Client** (`Client.client.luau`): Same pattern but called "controllers". Categories: Core → Inputs → Gameplay → UI → Visuals → Dev (Dev skipped in production).

### Dependency Injection

- **Server**: `ServiceLocator` (ServerScriptService/Utils) — call `ServiceLocator:Get("ServiceName")` to fetch a service instance.
- **Client**: `ControllerLocator` (StarterPlayerScripts/Core) — same pattern client-side.
- Services/controllers must not call each other during `Init()`, only during `Start()` (dependencies are guaranteed ready by then).

### Networking (Zap)

`network.zap` is the **source of truth** for all remote calls. Never edit `ZapServer.lua` or `ZapClient.lua` directly — regenerate them with `zap network.zap`.

Flow: Client fires Zap remote → `ServerNetWorkHandler` receives it → emits on `EventBus` → relevant service handles it.

### EventBus

`ReplicatedStorage/SystemsShared/EventBus.luau` is the internal pub/sub bus. All event names are pre-registered in `ReplicatedStorage/Shared/Events.luau` — emitting an unregistered event throws an error (strict mode).

```lua
-- Emit
EventBus:Emit(Events.SOME_EVENT, player, payload)

-- Listen
EventBus:On(Events.SOME_EVENT, function(player, payload) ... end)

-- Player-scoped cleanup
EventBus:OnForPlayer(player, Events.SOME_EVENT, handler)
EventBus:CleanupPlayer(player)
```

### IdempotentGuard

`ReplicatedStorage/Utils/IdempotentGuard.luau` prevents double-initialization (important during Rojo hot-reload). Every service/controller creates one:

```lua
local guard = IdempotentGuard.new("ServiceName", true)
-- In Init():  if not guard:MarkInitialized() then return end
-- In Start(): if not guard:MarkStarted() then return end
```

### Data Layer

`PlayerDataService` wraps ProfileService. Key rules:
- Use `PlayerDataService:WaitForData(player, timeout)` before reading data in other services' `Start()`.
- Use `PlayerDataService:Set(player, "Coins", value)` — this fires `Events.LOCAL_PLAYER_DATA_CHANGED` automatically.
- Dot-notation keys (`"PlayerBuildings.id"`) work for nested access but **bypass validation rules** (rules only apply to root keys).
- `_version` is an internal field — never call `Increment` on it.

### Grid & Building Systems

- Grid cell size = **4 studs**. All positions snap to grid with a 0.5 stud offset.
- `GridService` tracks valid/occupied cells per zone. Each player owns one zone (assigned on join).
- `BuildingService` handles placement requests, reads footprint from `BuildingConfig.luau`, checks grid occupancy, then persists via `PlayerDataService`.
- Building dimensions and stats live in `ReplicatedStorage/Shared/BuildingConfig.luau`. Building type IDs are in `GameEnum.luau`.

## Key Conventions

- **Strict Luau types** are enforced (`.luaurc` sets `strict = true`). Add type annotations to all new functions.
- Services are plain tables with `__index` metatable, not OOP classes. `ServiceName.new()` returns the instance.
- Path aliases in `.luaurc`: `@SS` = `ServerScriptService`, `@RS` = `ReplicatedStorage`.
- `network.zap` schema drives the network layer — add new remotes there first, then regenerate.
