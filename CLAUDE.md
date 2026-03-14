# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KeySorter is a World of Warcraft addon that automatically sorts raid members into balanced Mythic+ groups. Built for raid leaders running weekly M+ events with 10-40 players.

## Architecture

- **Core.lua** — Addon init, event handling, slash commands, SavedVariables, inspect queue for ilvl, preview mode data generation
- **Data.lua** — Constants: class utilities (brez/lust/shroud), score thresholds, dungeon IDs/names, ilvl color gradient, role icons, sort modes
- **Scanner.lua** — Raid roster scanning. Uses Raider.IO addon data when available, falls back to `C_PlayerInfo.GetPlayerMythicPlusRatingSummary`. Auto-scans on GROUP_ROSTER_UPDATE
- **Sorter.lua** — Group formation algorithm with two modes (skill matched / balanced snake draft). Respects locked groups. Utility balancing pass for brez/lust coverage
- **Comm.lua** — Addon communication via `C_ChatInfo.SendAddonMessage` on RAID channel. Auto-syncs after sort and drag-and-drop. Prefix: "KeySorter"
- **Widgets.lua** — Reusable UI components: buttons (with color presets), dropdowns, sliders, scroll frames, tooltips
- **UI/MainFrame.lua** — Main window with tab system (Roster, Groups, About), title bar, resize handle, groups toolbar (Sort button, sort mode toggle)
- **UI/RosterView.lua** — Scrollable roster with sortable columns and filter dropdowns (score, role, utility, timed runs)
- **UI/GroupView.lua** — Group cards with drag-and-drop, lock toggle, per-group announce buttons, unassigned section
- **UI/CharacterDetail.lua** — Lazy-loaded overlay showing full character breakdown (dungeons, key thresholds, past season score)
- **UI/Settings.lua** — Settings page with preview mode toggle and player count slider
- **UI/About.lua** — Overview, sort logic explanation, command reference
- **UI/Minimap.lua** — Standard circular minimap button with MiniMap-TrackingBorder overlay

## Key Patterns

- Shared addon table: `local addonName, KS = ...` in every file
- SavedVariables: `KeySorterDB` (window position, filter state, minimap position, ilvl cache)
- Permission gating: `KS.IsPermitted()` checks raid leader/assistant rank
- Preview mode: `KS.previewMode` generates fake data for UI testing without a raid group
- Group data model: `KS.groups[i] = { tank, healer, dps = {}, locked }` and `KS.unassigned = {}`
- Member data model: `{ name, classFile, role, score, runs, avgKeyLevel, numTimed, numUntimed, ilvl, hasBrez, hasLust, hasShroud, dataSource, ... }`

## Packaging

```bash
# Build release zip
rm -rf /tmp/KeySorter-release
mkdir -p /tmp/KeySorter-release/KeySorter
git archive HEAD | tar -x -C /tmp/KeySorter-release/KeySorter
cd /tmp/KeySorter-release
zip -r KeySorter-v<VERSION>.zip KeySorter/
```

No external library dependencies. Release via `gh release create`.

## WoW Addon Development Notes

- Interface version: 120000 (Midnight expansion)
- Frame types matter: use `Button` (not `Frame`) when needing `RegisterForClicks` or `RegisterForDrag`
- `BackdropTemplate` required for backdrop support on frames
- `SetParent(nil)` orphans frames but doesn't destroy children — use explicit cleanup
- Addon messages (`C_ChatInfo.SendAddonMessage`) are invisible to players, rate limited at ~4KB/s
- `C_AddOns.GetAddOnMetadata(addonName, "Version")` reads version from TOC at runtime
- Raid subgroups max at 5 players
