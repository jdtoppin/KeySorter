# Abstract Framework UI Refresh — Design Spec

**Date:** 2026-03-14
**Status:** Draft
**Inspiration:** [AbstractFramework by enderneko](https://github.com/enderneko/AbstractFramework) (GPLv3)

## Overview

Rewrite KeySorter's widget system to match the visual style and interaction patterns of Abstract Framework (AF). This is an **adapt & rewrite** approach — no AF code is copied. We study AF's design patterns and reimplement them from scratch within KeySorter's `KS` namespace, using our existing cyan accent color (`0, 0.8, 1`).

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Integration approach | Adapt & rewrite (not embed) | Keep self-contained, no AF dependency |
| Accent color | Keep cyan (`0, 0.8, 1`) | Consistent with existing identity |
| Tooltips | Hybrid — custom frames for KS UI, GameTooltip for items/spells | Future-proof without losing styled look |
| Arrow assets | Create our own TGA files | Avoid needing to use AF's media assets |
| Migration strategy | Big bang | Small addon, no external API consumers |
| Attribution | About page credit, no code-level copyright needed | No AF code is copied |

## Media Assets

Three new 16×16 white TGA textures (tintable via `SetVertexColor`):

- `Media/ArrowUp.tga` — upward triangle for sort ascending / dropdown open
- `Media/ArrowDown.tga` — downward triangle for sort descending / dropdown closed
- `Media/Lock.tga` — padlock silhouette for group lock toggle

## Foundation Layer (Widgets.lua)

The existing `BACKDROP_PANEL` and `BACKDROP_BUTTON` constants and all manual `SetBackdrop`/`SetBackdropColor`/`SetBackdropBorderColor` patterns are **removed** — both in UI consumer files and internally within Widgets.lua (ScrollFrame, Slider, Button internals). All replaced by `CreateBorderedFrame` or direct backdrop setup within widget constructors.

### KS.CreateBorderedFrame(parent, width, height, bgColor, borderColor)

BackdropTemplate frame with 1px solid border using plain white8x8 texture.

- **Defaults:** background `(0.1, 0.1, 0.1, 0.9)`, border `(0, 0, 0, 1)`
- **Stores:** `_bgColor`, `_borderColor` for hover highlight system
- **Methods:** `SetBorderColor(r,g,b,a)`, `SetBackgroundColor(r,g,b,a)`

### KS.SetBackdropHighlight(frame, borderHighlight, bgHighlight)

Hooks OnEnter/OnLeave on a frame to brighten border and/or background on hover. Stores original colors, restores on leave.

### KS.CreateButton(parent, text, color, width, height)

Built on BorderedFrame with `Button` frame type. Keeps existing color presets (accent, green, red, widget, gray_hover, dark, blue) and adds:

- `SetTextHighlightColor(r,g,b)` — changes text color on hover, reverts on leave
- `SetBorderHighlightColor(r,g,b,a)` — changes border color on hover, reverts on leave
- `LockHighlight()` / `UnlockHighlight()` — locked hover state tracking
- Push effect: text shifts down 1px on MouseDown, back up on MouseUp
- Disabled state: grayed text, no interaction

### Custom Tooltip System (Hybrid)

**KS.Tooltip** — a custom GameTooltip frame (using GameTooltipTemplate) with:
- Dark background `(0.1, 0.1, 0.1, 0.9)`
- Cyan border (accent color)
- First line = cyan-colored title, subsequent lines = white body text
- Support for `{left, right}` double-column lines

**KS.ShowTooltip(owner, anchor, lines)** — positions and shows the custom tooltip. `lines` is a table where:
- String entries are single-line text (white)
- Table entries `{"left text", "right text"}` are double-column lines (gold left, white right)
- Table entries `{text, r, g, b}` (4 elements) are color-tinted single lines
- First entry is always the title (cyan colored)

This is a **breaking change** from the current `KS.ShowTooltip(owner, title, ...)` varargs signature. All callsites are updated in the big bang.

**KS.SetTooltip(widget, anchor, lines)** — stores tooltip data (`_tooltipLines`, `_tooltipAnchor`) on the widget frame, then hooks OnEnter/OnLeave (once, tracked by `_tooltipHooked` flag). `lines` is a table in the same format as `ShowTooltip`. The hook reads the stored table on each enter, so callers can update tooltip content by reassigning `widget._tooltipLines` without re-hooking.

Replaces `KS.AddTooltip()`. All existing `KS.AddTooltip(frame, title, line1, line2, ...)` callsites (MainFrame, GroupView) are migrated to `KS.SetTooltip(frame, "ANCHOR_TOP", {"title", "line1", "line2"})` format.

**KS.HideTooltip()** — hides the custom tooltip.

Standard `GameTooltip` remains available for item/spell display if ever needed.

### Arrow Textures

- `Media/ArrowUp.tga` and `Media/ArrowDown.tga` — 16×16 white triangles
- Used by dropdowns (toggle indicator) and roster column headers (sort direction)
- Tinted via `SetVertexColor` to match context (cyan for active sort, gray for dropdown)

## Interactive Components

### KS.CreateDropdown(parent, width)

Constructor takes only parent and width. Items and callbacks are set via methods after creation (matches current consumer pattern in RosterView).

- **Trigger:** BorderedFrame with label text + ArrowDown.tga icon on right
- **Arrow:** swaps to ArrowUp.tga when list is open
- **List:** shared singleton frame with global name `KeySorterDropdownList` (only one dropdown open at a time), scroll-capable. Global name required for `UISpecialFrames` ESC-to-close.
- **Items:** `{ { text, value, icon? } }` — each is a button with transparent bg, hover highlight
- **Selected state:** accent border highlight on the selected item in the list
- **Closes on:** ESC (UISpecialFrames), click outside (closer frame), item selection
- **Push effect:** on the trigger button
- **Height:** fixed at 22px (matching current consumer usage), not configurable via constructor. This is a **breaking change** — callers no longer pass height.
- **Methods:** `SetItems(items)`, `SetSelected(value)`, `GetSelected()`, `SetOnSelect(callback)` — method names match the current API (`SetSelected`/`GetSelected`, not `SetSelectedValue`/`GetSelectedValue`)

### KS.CreateSlider(parent, label, min, max, step, width)

Parameter order matches the current implementation (`label, min, max, step, width`). This is **not** a breaking change.

- **Layout:** label text left, value display right (cyan colored)
- **Track:** dark bar with 1px border
- **Fill:** cyan bar showing progress from min to current value
- **Thumb:** squared (12×14px), draggable, brightens on hover
- **Mouse wheel:** increment/decrement by step
- **Edit box:** below the slider for direct value entry. Numeric-only input (`SetNumeric(true)`). On enter or focus-lost, value is clamped to min/max, rounded to nearest step, and `SetOnChange` fires. Invalid/empty input reverts to current value.
- **Methods:** `SetValue(v)`, `GetValue()`, `SetOnChange(fn)`

### KS.CreateSwitch(parent, width, height, options)

- **Container:** BorderedFrame with horizontally arranged option buttons
- **Options:** `{ { text, value } }` — buttons auto-size to fill width equally
- **Selection:** selected button gets cyan highlight fill (animated via AnimationGroup, 0.15s linear height tween from bottom); deselected shrinks highlight to 1px line via same animation
- **Behavior:** radio-button (one active at a time)
- **Methods:** `SetSelectedValue(value)`, `SetOnSelect(fn)`
- **Replaces:** the current sort mode toggle button in MainFrame

### KS.CreateCheckButton(parent, icon, size, callback)

- **Frame:** small bordered frame (default 16×16) that toggles on/off
- **Checked:** icon texture tinted cyan, border brightens
- **Unchecked:** icon dimmed/hidden, border reverts to default
- **Push effect:** on click
- **Methods:** `SetChecked(bool)`, `IsChecked()`, `SetOnToggle(fn)`
- **Lock variant:** uses `Media/Lock.tga` for group lock toggle in GroupView

### KS.CreateCloseButton(parent)

- Icon-based "×" button, hover turns red
- Push effect on click

### KS.CreateResizeButton(parent)

- Corner grip texture, hover brightens
- Consistent with bordered frame styling

### KS.CreateScrollFrame (unchanged logic, visual update)

The existing `KS.CreateScrollFrame` keeps its current API and scroll behavior. Visual updates only:

- Scrollbar thumb: hover brightens to cyan accent, matching other interactive elements
- Scrollbar track: uses bordered frame styling (`0.1, 0.1, 0.1` bg, 1px border)
- No API changes — all 4 callsites (RosterView, GroupView, About, CharacterDetail) remain unchanged

## Drag and Drop Visual Upgrade (GroupView)

Logic stays the same (swap members between group slots). Visual style upgraded:

### Drag Cursor (moverTip)
- BorderedFrame with cyan border following cursor via OnUpdate
- Contains: role/class icon (left) + member name text (right)
- Replaces the current plain text floating frame

### Source Highlighting
- Dimmed overlay (semi-transparent dark layer) on the source slot
- Cyan brightened border on source slot

### Drop Target Highlighting
- Slots under cursor get cyan border highlight + subtle background brightening
- No highlight on invalid/empty targets

### Drop Feedback
- On successful drop: brief cyan flash on both swapped slots using an AnimationGroup (0.3s alpha fade from 0.5 → 0 on an overlay texture)
- On cancel (dropped outside): source overlay clears, member snaps back

### Unchanged
- Swap logic (source ↔ target member exchange)
- `RegisterForDrag("LeftButton")` on member lines
- `FindDropTarget()` iterating member lines for mouse-over detection
- `KS.AutoSync()` after drop

## Consumer Updates

All UI files updated in one pass to use the new widget system:

### UI/MainFrame.lua
- Sort mode button → `KS.CreateSwitch()` with "Skill Matched" / "Balanced" options
- Close button → `KS.CreateCloseButton()`
- Resize handle → `KS.CreateResizeButton()`
- Title bar and tab panels → `KS.CreateBorderedFrame()`

### UI/GroupView.lua
- Group cards → `KS.CreateBorderedFrame()` with hover highlights
- Lock text button → `KS.CreateCheckButton()` with lock icon
- Announce buttons → `KS.CreateButton()` with border highlight on hover
- Drag cursor → styled moverTip (bordered frame + icon + name)
- Drop targets → cyan border highlight system
- Member lines → hover highlights via `SetBackdropHighlight`

### UI/RosterView.lua
- 4 filter dropdowns → `KS.CreateDropdown()` with arrow icons
- Sort direction indicators → ArrowUp/ArrowDown.tga replacing `^`/`v` unicode
- Column headers → hover highlights
- Roster rows → hover highlights

### UI/Settings.lua
- Player count slider → `KS.CreateSlider()` with edit box
- Preview toggle → `KS.CreateButton()` with new styling
- Frame → `KS.CreateBorderedFrame()`
- Close button → `KS.CreateCloseButton()`

### UI/About.lua
- Add attribution: "UI components inspired by AbstractFramework by enderneko (GPLv3)"
- Frame → `KS.CreateBorderedFrame()`

### UI/CharacterDetail.lua
- Frame → `KS.CreateBorderedFrame()`
- Close button → `KS.CreateCloseButton()`

### All Tooltips
- `KS.AddTooltip()` callsites (MainFrame, GroupView) migrated to `KS.SetTooltip(frame, anchor, linesTable)`
- Simple button/widget tooltips → `KS.SetTooltip()` with custom tooltip frame
- `KS.ShowMemberTooltip()` — uses custom tooltip frame with colored lines via `{text, r, g, b}` format for class colors, role text, dungeon stats. All current `GameTooltip:AddLine`/`AddDoubleLine` calls converted to the lines table format.

## Attribution

- **In-game About page:** Credit line — "UI components inspired by AbstractFramework by enderneko (GPLv3)"
- **No code-level attribution needed:** We are reimplementing from scratch, not copying AF source code
- **License:** KeySorter remains GPLv3 (no change)
