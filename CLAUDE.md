# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KeySorter is a World of Warcraft addon that automatically sorts raid members into balanced Mythic+ groups. Built for raid leaders running weekly M+ events with 10-40 players.

## Architecture

- **Core.lua** — Addon init, event handling, slash commands, SavedVariables, inspect queue for ilvl (with backoff retry), preview mode data generation (uses real Raider.IO base score table for realistic correlations), `ApplyGroups()` with swap-based raid subgroup assignment
- **Data.lua** — Constants: class utilities (brez/lust/shroud), score thresholds, dungeon IDs/names, ilvl color gradient, role icons, sort modes, season tracking (`CURRENT_SEASON`, `SEASON_ORDER`, `SEASON_LABELS`)
- **Scanner.lua** — Raid roster scanning with cross-realm name handling. Uses Raider.IO addon data (`mplusCurrent.score`) when available, falls back to `C_PlayerInfo.GetPlayerMythicPlusRatingSummary`. Auto-scans on GROUP_ROSTER_UPDATE. Persists season scores to `KeySorterDB.seasonScores` (never pruned). Preview mode skips DB writes.
- **Sorter.lua** — Group formation algorithm with three modes (skill matched / balanced snake draft / gear). Shared helpers: `KS.CalcGroupsNeeded()`, `KS.MakeSortComparator()`. `SortGroups()` (Sort All) and `SortUnassigned()` (Sort New). Respects locked groups. Utility balancing pulls from unassigned first. `ReconcileGroups()` handles roster changes without re-sorting.
- **Comm.lua** — Addon communication via `C_ChatInfo.SendAddonMessage` on RAID channel. Multi-part chunking for messages > 255 bytes. Sender permission validation. `CreateStubMember()` looks up `knownChars` for correct classFile. Auto-syncs after sort and drag-and-drop. Guild version check and hello handshake on join. Prefix: "KeySorter"
- **Widgets.lua** — UI widget library: BorderedFrame, Button (with animated highlight, text/border highlight colors), Dropdown (arrow icons, shared singleton list), Slider (fill bar, accent thumb), Switch (animated segmented toggle), CheckButton (icon toggle), ScrollFrame (5px thin cyan scrollbar, deferred width init), CloseButton, ResizeButton, ConfirmDialog (dimmer overlay + Yes/No), custom Tooltip system (RGB validation on line format detection)
- **UI/Sidebar.lua** — Sidebar navigation with gradient highlights, icon + label buttons, animated selection state, notification dot pulse (suppressed when Groups tab selected)
- **UI/MainFrame.lua** — Main window with sidebar, content area, groups toolbar (Sort All + Sort New buttons, sort mode switch), fade in/out animation, ESC-to-close via OnKeyDown (propagation reset on fade-out), resize with TOPLEFT re-anchor and size persistence
- **UI/RosterView.lua** — Scrollable roster with sortable columns (stable name tiebreaker), filter dropdowns, arrow TGA sort indicators
- **UI/GroupView.lua** — Responsive group cards (reflow on resize) with drag-and-drop (OnUpdate only active during drag, frame pooling), mark-done toggle with tick icon, inline BR/BL tags, per-group announce, OnUpdate-based flash animation
- **UI/PlayersView.lua** — Historical character database view (create-once, refresh on tab enter). Sortable/filterable table with search, score/role/utility filters, "Last Seen" column (weekly format). Click opens CharacterDetail.
- **UI/CharacterDetail.lua** — Responsive two-column overlay (overview/utilities/timed key breakdown/notes/alt linking left, dungeons right), collapses to single column when narrow (throttled rebuild on resize), dynamic season score display from `seasonScores` DB
- **UI/Settings.lua** — Inline scrollable settings: General (UI Scale), Announcements (message editors with dynamic width), Preview Mode, Live Simulation, Coming Soon placeholders, Character History (clear with confirm dialog)
- **UI/About.lua** — Feature cards (Roster, Group Builder, Character History, Smart Data), sort logic explanation, slash commands table, credits
- **UI/Minimap.lua** — Minimap button with support for both circular and square minimaps
- **Media/** — TGA textures: arrows, sidebar icons (from AbstractFramework), gradient, tick, lock, warning, circle, resize grip, generated IconPlayers
- **scripts/generate_tga.py** — Python script to generate TGA icon assets (only generates IconPlayers and non-AF assets; AF icons must not be overwritten)

## Key Patterns

- Shared addon table: `local addonName, KS = ...` in every file
- SavedVariables: `KeySorterDB` (point, filterIdx, minimapPos, ilvlCache, uiScale, welcomeMsg, gatherMsg, notes, alts, knownChars, seasonScores, frameWidth, frameHeight)
- Season tracking: `KS.CURRENT_SEASON` in Data.lua, scores persisted in `KeySorterDB.seasonScores` (never pruned, kept forever). Update `CURRENT_SEASON`, `SEASON_ORDER`, `SEASON_LABELS` when a new season launches.
- Permission gating: `KS.IsPermitted()` checks raid leader/assistant rank
- Preview mode: `KS.previewMode` generates fake data with realistic score correlations for UI testing. Preview data is NOT written to knownChars or seasonScores.
- Group data model: `KS.groups[i] = { tank, healer, dps = {}, locked }` and `KS.unassigned = {}`
- Member data model: `{ name, classFile, role, score, seasonScores, runs, avgKeyLevel, ilvl, hasBrez, hasLust, hasShroud, dataSource, utilityCount, ... }`
- Widget animation pattern: OnUpdate-based interpolation (not AnimationGroup Alpha, which has quirks with SetAlpha)
- Backdrop: single shared `KS.BACKDROP` table replaces old `BACKDROP_BUTTON`/`BACKDROP_PANEL`
- Tooltips: `KS.ShowTooltip(owner, anchor, linesTable)` with `{text}`, `{text, r,g,b}` (RGB must be 0-1), or `{"left","right"}` line formats
- Confirm dialog: `KS.ShowConfirmDialog(text, onConfirm, onCancel)` — singleton, FULLSCREEN_DIALOG strata, OnUpdate fade-in
- Sidebar icons: AbstractFramework TGA files — white on transparent, tinted via SetVertexColor. Do NOT regenerate AF icons with the Python script.
- Frame lifecycle: prefer pooling and reuse over `SetParent(nil)` orphaning. WoW frames cannot be destroyed.
- Cross-realm names: Scanner appends `-realm` for cross-realm players to ensure consistent DB lookups
- ApplyGroups: uses `SwapRaidSubgroup` for full subgroups, `SetRaidSubgroup` for groups with room, multi-pass resolution
- Comm chunking: messages > 255 bytes split into `SYNC_P|part|total|data` chunks, reassembled by receiver
- OnUpdate efficiency: only set OnUpdate handlers when actively needed (e.g., during drag), clear when done

## Packaging

```bash
# Build release zip (excludes dev files)
rm -rf /tmp/KeySorter-release
mkdir -p /tmp/KeySorter-release/KeySorter
git archive HEAD | tar -x -C /tmp/KeySorter-release/KeySorter
cd /tmp/KeySorter-release
# Remove dev-only files
rm -rf KeySorter/.claude KeySorter/.superpowers KeySorter/docs KeySorter/scripts KeySorter/.gitignore KeySorter/.git-rewrite KeySorter/CLAUDE.md
zip -r KeySorter-v<VERSION>.zip KeySorter/
```

No external library dependencies. Release via `gh release create`.

## WoW Addon Development Notes

- Interface version: 120001 (Midnight expansion)
- Frame types matter: use `Button` (not `Frame`) when needing `RegisterForClicks`
- `RegisterForDrag` works on plain `Frame` with `EnableMouse(true)`
- `BackdropTemplate` required for backdrop support on frames
- `SetParent(nil)` orphans frames but doesn't destroy children — prefer pooling/hiding over orphaning
- Addon messages (`C_ChatInfo.SendAddonMessage`) are invisible to players, rate limited at ~4KB/s, max 255 bytes per message (chunk if larger)
- `C_AddOns.GetAddOnMetadata(addonName, "Version")` reads version from TOC at runtime
- Raid subgroups max at 5 players; `SetRaidSubgroup` fails silently on full groups — use `SwapRaidSubgroup` for swaps
- AnimationGroup Alpha animations have quirks with manual `SetAlpha` — use OnUpdate-based fading instead
- `SetScript("OnUpdate")` only works on Frames, not Textures — animate textures via parent frame's OnUpdate
- WoW fonts don't support Unicode symbols (☰⊞⚙ℹ render as squares) — use TGA textures or game icons instead
- `UISpecialFrames` causes WoW to call `Hide()` directly, conflicting with fade animations — use OnKeyDown for ESC handling instead
- Sidebar icons from AbstractFramework are white on transparent TGA, tintable via `SetVertexColor` and `SetDesaturated`
- RaiderIO API: scores in `mkp.mplusCurrent.score` / `mkp.mplusPrevious.score` (not top-level `currentScore`/`previousScore`)
- `UnitName(unit)` returns `name, realm` — append realm for cross-realm players to avoid DB collisions
- `KeySorterDB.point` stores `"UIParent"` at index 2 (not nil) for safe serialization
