# Collapsible Sidebar Navigation — Design Spec

**Date:** 2026-03-14
**Status:** Draft
**Inspiration:** [BFInfinite by enderneko](https://github.com/enderneko/BFInfinite) sidebar menu pattern

## Overview

Replace KeySorter's title bar tab system with a collapsible sidebar navigation inspired by BFInfinite. The sidebar holds all navigation (Roster, Groups, Settings, About) with icons and text. When collapsed, only icons are shown. Settings becomes an inline panel instead of a popup. The sidebar header replaces the title bar as the drag handle and branding area.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Icons | Custom TGA (tintable) | Consistent with existing arrow/lock assets |
| Toggle location | Bottom of sidebar (chevron) | Intuitive, unobtrusive |
| Collapse animation | Animated (~150ms) | Polished, matches Switch toggle pattern |
| Persist state | `KeySorterDB.sidebarCollapsed` | Remembers preference across sessions |
| Title bar | Removed; sidebar header replaces it | Sidebar header shows branding + drag handle |
| Settings | Inline content panel | No more popup; scales with UI |

## Layout

### Expanded (~140px sidebar)

```
┌──────────────┬─────────────────────────[X]┐
│ [KeySorter]  │                             │
├──────────────┤                             │
│ 📋 Roster    │                             │
│ ⊞ Groups     │      Content Area           │
│ ───────────  │                             │
│ ⚙ Settings   │                             │
│ ℹ About      │                             │
│              │                             │
│  ◀◀ Collapse │                          [↘]│
└──────────────┴─────────────────────────────┘
```

### Collapsed (~32px sidebar)

```
┌────┬───────────────────────────────[X]┐
│[KS]│                                  │
├────┤                                  │
│ 📋 │                                  │
│ ⊞  │        Content Area              │
│ ── │                                  │
│ ⚙  │                                  │
│ ℹ  │                                  │
│    │                                  │
│ ▶▶ │                               [↘]│
└────┴──────────────────────────────────┘
```

### Structure

- **Sidebar header**: displays logo texture — `LogoFull.tga` (expanded) / `LogoKS.tga` (collapsed). Acts as the drag handle for the entire main frame. Has a 1px bottom border separator.
- **Close button**: anchored to top-right corner of the main frame (outside the sidebar, in the content area corner).
- **Resize handle**: bottom-right corner of the main frame (unchanged).
- **Content area**: fills remaining space to the right of the sidebar. All tab content panels (Roster, Groups, Settings, About) are parented here with `SetAllPoints()`. Only the active panel is visible.
- **Groups toolbar**: remains inside the Groups content area as a toolbar at the top, not part of the sidebar.

## Sidebar Component (`UI/Sidebar.lua`)

### `KS.CreateSidebar(parent)`

Creates and returns the sidebar frame. Parameters:

- `parent` — the main frame

### Internal Structure

The sidebar is a plain `Frame` (not `CreateBorderedFrame`) anchored to the left side of the parent:
- **Expanded width**: 140px
- **Collapsed width**: 32px
- **Background**: `CreateTexture` with `SetColorTexture(0.06, 0.06, 0.06, 0.95)` filling the frame
- **Right edge border**: a separate 1px-wide `CreateTexture` anchored to `TOPRIGHT`/`BOTTOMRIGHT` with color `(0.25, 0.25, 0.25, 1)`. Not using `BackdropTemplate` since we only want the right edge, not a full border.

### Sidebar Header

- **Height**: 28px, with 1px bottom border
- **Expanded**: shows `Media/LogoFull.tga` texture (128x16), centered vertically, left-padded
- **Collapsed**: shows `Media/LogoKS.tga` texture (32x32), centered
- **Drag handling**: header is a `Frame` with `EnableMouse(true)` and `RegisterForDrag("LeftButton")`. OnDragStart calls `parent:StartMoving()`, OnDragStop calls `parent:StopMovingOrSizing()` and saves position. Replaces the old title bar as the drag handle.

### Navigation Buttons

4 buttons arranged vertically below the header, with a 1px separator between Groups and Settings:

| Button | Icon TGA | Value |
|---|---|---|
| Roster | `Media/IconRoster.tga` | `"roster"` |
| Groups | `Media/IconGroups.tga` | `"groups"` |
| *separator* | — | — |
| Settings | `Media/IconSettings.tga` | `"settings"` |
| About | `Media/IconAbout.tga` | `"about"` |

**Button layout (expanded):**
- Height: 28px
- Anchor: `TOPLEFT`/`TOPRIGHT` with 6px horizontal inset
- Icon: 16x16 texture, 8px from left edge, vertically centered
- Label: `GameFontHighlightSmall`, 8px right of icon, vertically centered
- Spacing: 2px gap between buttons

**Button layout (collapsed):**
- Same height (28px)
- Icon: centered horizontally, label hidden

### Button Visual States

All states use the same cyan gradient overlay (consistent between expanded and collapsed):

**Gradient highlight texture:**
- A pre-rendered TGA texture (`Media/GradientH.tga`, 64x4, white-to-transparent horizontal gradient) anchored to `TOPLEFT`/`BOTTOMLEFT` of the button
- Tinted cyan via `SetVertexColor(0, 0.8, 1)` — the TGA provides the alpha gradient, vertex color provides the hue
- This avoids `SetGradient`/`SetGradientAlpha` which have API compatibility issues across WoW versions

**States:**
- **Default**: gradient width = 1px (invisible), icon gray `(0.5, 0.5, 0.5)`, text gray `(0.6, 0.6, 0.6)`
- **Hover** (not selected): gradient animates to 7px width, icon brightens to white, text brightens to white
- **Selected**: gradient animates to full button width, icon tinted cyan `(0, 0.8, 1)`, text white
- **Push effect**: 1px downward shift on click

**Animation**: OnUpdate-based width interpolation over ~150ms (same pattern as `KS.CreateSwitch`).

### Collapse Toggle Button

- Anchored to the bottom of the sidebar, full width, 24px tall
- 1px top border separator
- **Expanded**: shows `◀◀` text (or a custom chevron), labeled "Collapse"
- **Collapsed**: shows `▶▶` text (or chevron), no label
- On click: toggles `KeySorterDB.sidebarCollapsed`, triggers animated resize. Clicks are ignored while an animation is in progress (debounced).

### Collapse/Expand Animation

- Width tweens from 140px ↔ 32px over ~150ms via OnUpdate timer
- During animation: content area anchor adjusts smoothly (anchored to sidebar's right edge)
- On animation complete:
  - **Collapsing**: hide button labels, swap logo to `LogoKS.tga`
  - **Expanding**: show button labels, swap logo to `LogoFull.tga`
- Labels and logo swap at the midpoint of the animation (~75ms in) to avoid visual jank

### Tab Switching

`KS.SetTab(tabName)` is updated to:
1. Hide all content panels
2. Show the selected panel
3. Update sidebar button states (deselect old, select new with gradient animation)

Content panels are lazy-loaded: created on first selection, then shown/hidden thereafter.

## Settings Migration

`UI/Settings.lua` is converted from a popup (`UIParent`-parented dialog) to an inline content panel:

- **Parent**: the shared content area frame (same as Roster/Groups/About)
- **Anchoring**: `SetAllPoints()` to the content area
- **No frame strata override** (was `DIALOG`)
- **No movability** (no drag scripts)
- **No close button** (switch tabs via sidebar to leave settings)
- **No `UISpecialFrames`** (ESC no longer closes it separately)
- **Scrollable**: wrap settings content in a `KS.CreateScrollFrame` since the content area may be shorter than the full settings list
- **`KS.CreateSettingsFrame(parent)`** now takes a parent parameter

The settings content itself (sliders, rows, labels) remains unchanged.

## CharacterDetail Migration

`UI/CharacterDetail.lua` currently anchors its overlay to the main frame with a hardcoded title bar offset (`TOPLEFT, 1, -29`). With the title bar removed:

- **Parent**: stays `KS.mainFrame`
- **Anchoring**: changed to cover the content area only — `TOPLEFT` anchored to the content area frame, `BOTTOMRIGHT` anchored to the main frame
- **Frame level**: remains `KS.mainFrame:GetFrameLevel() + 10` (renders above sidebar and content)

The back button and all content inside CharacterDetail remain unchanged.

## ESC Behavior

`KeySorterMainFrame` remains in `UISpecialFrames` — pressing ESC still closes the entire addon window. This is unchanged.

## Minimum Frame Width

The current minimum width of 500px is updated to **540px** to ensure at least 400px of content area when the sidebar is expanded (140px sidebar + 400px content). When collapsed (32px sidebar), content gets 508px — more than sufficient.

## Slash Command Updates

- `/ks settings` (and `/ks preview`): updated to call `KS.SetTab("settings")` and show the main frame, instead of `KS.ToggleSettings()`
- `KS.ToggleSettings()` is removed (no more standalone settings popup)

## Content Panel Loading

Content panels are **eagerly loaded** on main frame creation (matching current behavior). Roster, Groups, and About views are created immediately. Settings is created immediately as an inline panel. This avoids complexity from lazy-loading and matches the existing pattern.

## Media Assets

7 new TGA textures:

| File | Size | Description |
|---|---|---|
| `Media/LogoFull.tga` | 128×16 | "KeySorter" text with cyan glow behind |
| `Media/LogoKS.tga` | 32×32 | "KS" text with cyan glow behind |
| `Media/IconRoster.tga` | 16×16 | People/list silhouette |
| `Media/IconGroups.tga` | 16×16 | 2×2 grid/boxes |
| `Media/IconSettings.tga` | 16×16 | Gear |
| `Media/IconAbout.tga` | 16×16 | Circled "i" |
| `Media/GradientH.tga` | 64×4 | White-to-transparent horizontal gradient (for sidebar button highlights) |

All white on transparent, tintable via `SetVertexColor`. Logo TGAs have a soft cyan glow (gaussian blur of text shape composited behind white text).

## MainFrame Changes

`UI/MainFrame.lua` is restructured:

### Removed
- Title bar frame and all its contents (tab buttons, settings button, about button, close button, title text)
- `TITLEBAR_H`, `TOOLBAR_H`, `CONTENT_Y_NO_TOOLBAR`, `CONTENT_Y_WITH_TOOLBAR` constants
- `CreateTab()` helper function
- Tab button mutual exclusion logic

### Added
- Sidebar via `KS.CreateSidebar(f)`
- Content area frame anchored to sidebar's right edge
- Close button anchored to top-right of main frame
- Resize handle (unchanged, already migrated)

### Updated
- `KS.SetTab()` — updated to work with sidebar button states and content panel visibility
- Content panels anchor to the shared content area frame instead of the main frame directly
- `KS.CreateRosterView`, `KS.CreateGroupView`, `KS.CreateAboutView` receive the content area as parent
- Groups toolbar is created inside the Groups content panel, not as a sibling of the tab system

## TOC Change

Add `UI/Sidebar.lua` before `UI/MainFrame.lua` in `KeySorter.toc`:

```
UI/Sidebar.lua
UI/MainFrame.lua
```

## SavedVariables

Add to `KeySorterDB` initialization in `Core.lua`:

```lua
KeySorterDB.sidebarCollapsed = KeySorterDB.sidebarCollapsed or false
```
