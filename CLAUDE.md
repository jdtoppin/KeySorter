# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KeySorter is a World of Warcraft addon that automatically sorts raid members into balanced Mythic+ groups. Built for raid leaders running weekly M+ events with 10-40 players.

## Architecture

- **Core.lua** — Addon init, event handling, slash commands, SavedVariables, inspect queue for ilvl, preview mode data generation (uses real Raider.IO base score table for realistic correlations)
- **Data.lua** — Constants: class utilities (brez/lust/shroud), score thresholds, dungeon IDs/names, ilvl color gradient, role icons, sort modes
- **Scanner.lua** — Raid roster scanning. Uses Raider.IO addon data when available, falls back to `C_PlayerInfo.GetPlayerMythicPlusRatingSummary`. Auto-scans on GROUP_ROSTER_UPDATE
- **Sorter.lua** — Group formation algorithm with two modes (skill matched / balanced snake draft). Respects locked groups. Utility balancing pass for brez/lust coverage. `ReconcileGroups()` handles roster changes without re-sorting
- **Comm.lua** — Addon communication via `C_ChatInfo.SendAddonMessage` on RAID channel. Auto-syncs after sort and drag-and-drop. Prefix: "KeySorter"
- **Widgets.lua** — UI widget library: BorderedFrame, Button (with animated highlight, text/border highlight colors), Dropdown (arrow icons, shared singleton list), Slider (fill bar, accent thumb), Switch (animated segmented toggle), CheckButton (icon toggle), ScrollFrame (5px thin cyan scrollbar), CloseButton, ResizeButton, custom Tooltip system
- **UI/Sidebar.lua** — Sidebar navigation with gradient highlights, icon + label buttons, animated selection state
- **UI/MainFrame.lua** — Main window with sidebar, content area, groups toolbar (Sort button, sort mode switch), fade in/out animation, ESC-to-close via OnKeyDown
- **UI/RosterView.lua** — Scrollable roster with sortable columns (including role/utility), filter dropdowns, arrow TGA sort indicators
- **UI/GroupView.lua** — Responsive group cards (reflow on resize) with drag-and-drop (styled cursor, source overlay, drop flash), lock toggle, inline BR/BL tags, per-group announce
- **UI/CharacterDetail.lua** — Two-column overlay (overview/utilities left, runs/dungeons right), falls back to single column when narrow
- **UI/Settings.lua** — Inline scrollable settings panel with UI Scale slider (0.5x-2.0x) and preview mode controls
- **UI/About.lua** — Feature cards, sort logic explanation, slash commands table, credits
- **UI/Minimap.lua** — Minimap button with support for both circular and square minimaps
- **Media/** — TGA textures: arrows, sidebar icons (from AbstractFramework), gradient, lock
- **scripts/generate_tga.py** — Python script to generate TGA icon assets

## Key Patterns

- Shared addon table: `local addonName, KS = ...` in every file
- SavedVariables: `KeySorterDB` (window position, filter state, minimap position, ilvl cache, uiScale, sidebarCollapsed)
- Permission gating: `KS.IsPermitted()` checks raid leader/assistant rank
- Preview mode: `KS.previewMode` generates fake data with realistic score correlations for UI testing
- Group data model: `KS.groups[i] = { tank, healer, dps = {}, locked }` and `KS.unassigned = {}`
- Member data model: `{ name, classFile, role, score, runs, avgKeyLevel, numTimed, numUntimed, ilvl, hasBrez, hasLust, hasShroud, dataSource, utilityCount, ... }`
- Widget animation pattern: OnUpdate-based interpolation (not AnimationGroup Alpha, which has quirks with SetAlpha)
- Backdrop: single shared `KS.BACKDROP` table replaces old `BACKDROP_BUTTON`/`BACKDROP_PANEL`
- Tooltips: `KS.ShowTooltip(owner, anchor, linesTable)` with `{text}`, `{text, r,g,b}`, or `{"left","right"}` line formats
- Sidebar icons: AbstractFramework TGA files (Menu1, Layout, Settings, Info_Round) — white on transparent, tinted via SetVertexColor

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

- Interface version: 120001 (Midnight expansion)
- Frame types matter: use `Button` (not `Frame`) when needing `RegisterForClicks`
- `RegisterForDrag` works on plain `Frame` with `EnableMouse(true)`
- `BackdropTemplate` required for backdrop support on frames
- `SetParent(nil)` orphans frames but doesn't destroy children — use explicit cleanup
- Addon messages (`C_ChatInfo.SendAddonMessage`) are invisible to players, rate limited at ~4KB/s
- `C_AddOns.GetAddOnMetadata(addonName, "Version")` reads version from TOC at runtime
- Raid subgroups max at 5 players
- AnimationGroup Alpha animations have quirks with manual `SetAlpha` — use OnUpdate-based fading instead
- `SetScript("OnUpdate")` only works on Frames, not Textures — animate textures via parent frame's OnUpdate
- WoW fonts don't support Unicode symbols (☰⊞⚙ℹ render as squares) — use TGA textures or game icons instead
- `UISpecialFrames` causes WoW to call `Hide()` directly, conflicting with fade animations — use OnKeyDown for ESC handling instead
- Sidebar icons from AbstractFramework are white on transparent TGA, tintable via `SetVertexColor` and `SetDesaturated`
