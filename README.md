# KeySorter

A World of Warcraft addon that automatically sorts raid members into balanced Mythic+ groups.

Built for raid leaders who organize weekly M+ events and need to quickly form balanced 5-man groups from a raid of 10-40 players.

## Features

### Sidebar Navigation
- Clean sidebar with icons for Roster, Groups, Settings, and About
- Animated gradient highlight on hover and selection
- Window opens and closes with a smooth fade animation

### Roster View
- Auto-scans raid members as they join, pulling M+ rating, average key level, timed/untimed runs, item level, and class utilities
- Sortable columns — click any header to sort (name, score, iLvl, avg key, timed, untimed, total, role, utility)
- Filter dropdowns for score range, role, utility type, and minimum timed runs
- Shift-hover any member for a detailed dungeon breakdown tooltip
- Click any member to open their full character profile

### Group Builder
- Forms balanced 5-man groups (1 tank, 1 healer, 3 DPS) with one click
- Two sort modes: **Skill Matched** (similar skill together) or **Balanced** (snake draft for even distribution)
- Battle Rez and Bloodlust coverage balanced automatically, shown inline on each member's name (BR/BL tags)
- Responsive card grid that reflows when you resize the window
- Drag and drop members between groups with styled cursor, source overlay, and flash animation
- Lock groups with a tick toggle to preserve them during re-sorts
- Smart roster reconciliation — new players go to Unassigned, leavers are removed, no disruptive re-sorts
- Per-group Announce button to post assignments to raid chat
- Auto-sort on first visit to the Groups tab

### Character Detail
- Two-column layout: overview and utilities on the left, run summary and dungeon breakdown on the right
- Falls back to single column when the window is narrow
- Dungeon table with level, timed/untimed status, and per-dungeon score

### Settings
- Inline scrollable panel (no popup)
- **UI Scale** slider (0.5x–2.0x) — scales the entire addon window
- Preview Mode with configurable player count for testing without a raid

### Other
- Custom tooltip system with cyan accent border
- Animated button highlights across all interactive elements
- Item level caching across sessions via SavedVariables
- Auto-sync group assignments to raid assistants via addon comms
- Permission gated — sort, apply, sync, and announce restricted to raid leaders and assistants
- Minimap button with support for both circular and square minimaps
- ESC to close

## Usage

1. Install KeySorter into `Interface/AddOns/KeySorter`
2. Form a raid group
3. Type `/ks` to open the KeySorter window, or click the minimap button
4. The **Roster** view auto-populates as players join — click column headers to sort, use filters to narrow the view
5. Click **Groups** in the sidebar — groups are automatically sorted on first visit
6. Lock groups you're happy with, then re-sort as new players join
7. Click **Announce** on each group card to post that group to raid chat
8. Group assignments are automatically synced to other assistants with the addon

## Commands

| Command | Description |
|---------|-------------|
| `/ks` | Toggle main window |
| `/ks sort` | Sort into groups |
| `/ks apply` | Move players to raid subgroups |
| `/ks announce` | Post all groups to raid chat |
| `/ks announce N` | Post group N to raid chat |
| `/ks sync` | Force sync groups to assistants |
| `/ks settings` | Open settings |
| `/ks about` | Show about page |
| `/ks help` | Print command list to chat |

## How Sorting Works

Two sort modes are available via the toggle on the Groups toolbar:

- **Skill Matched** (default) — Groups players of similar skill level together. The highest-scored tank, healer, and top 3 DPS form Group 1, the next best form Group 2, and so on.
- **Balanced** — Distributes skill levels evenly across groups using a snake draft (1→N, N→1, repeat), so each group gets a mix of high and low scorers.

Both modes share these steps:

1. Players are separated into three pools: Tanks, Healers, and DPS
2. Each pool is sorted by M+ score (descending), with item level as a tiebreaker
3. The number of groups is determined by the scarcest role
4. Tanks and healers are assigned in order (highest score to Group 1, etc.)
5. DPS are distributed according to the selected sort mode
6. Extra players go to the Unassigned card
7. A utility balancing pass ensures each group has battle rez and bloodlust coverage where possible
8. Locked groups are fully excluded from sorting and utility balancing

## Data Sources

- **Raider.IO** (primary) — M+ score, total timed/untimed runs, and key level thresholds. Data is bundled locally with the Raider.IO addon
- **Blizzard API** (fallback) — `C_PlayerInfo.GetPlayerMythicPlusRatingSummary` provides best run per dungeon
- **Item Level** — Collected via background inspect, cached in SavedVariables for returning players

## Project Structure

```
KeySorter/
├── KeySorter.toc          # Addon metadata
├── Core.lua               # Init, events, slash commands, SavedVariables, preview data
├── Data.lua               # Constants (class utilities, score thresholds, dungeon IDs)
├── Widgets.lua            # UI widget library (buttons, dropdowns, sliders, tooltips, scrollframes)
├── Scanner.lua            # Raid roster scanning, M+ data collection, ilvl caching
├── Sorter.lua             # Group formation algorithm with lock support and reconciliation
├── Comm.lua               # Leader/assistant sync via addon comms
├── Media/                 # TGA icon textures (arrows, lock, sidebar icons, gradient)
├── scripts/               # Asset generation tools
└── UI/
    ├── Sidebar.lua        # Sidebar navigation with animated highlights
    ├── MainFrame.lua      # Main window, content area, toolbar controls
    ├── RosterView.lua     # Sortable roster with filters and arrow sort indicators
    ├── GroupView.lua      # Responsive group cards with drag-and-drop and locking
    ├── CharacterDetail.lua# Two-column character breakdown overlay
    ├── Settings.lua       # Inline settings panel (UI scale, preview mode)
    ├── About.lua          # Feature cards, sort logic, commands, credits
    └── Minimap.lua        # Minimap button (circular and square support)
```

## Requirements

- World of Warcraft (Midnight, Interface 120001)
- Optional: [Raider.IO](https://raider.io/addon) for enhanced M+ data

## Acknowledgments

UI components inspired by [AbstractFramework](https://github.com/enderneko/AbstractFramework) by enderneko (GPLv3).

## License

[GNU General Public License v3.0](LICENSE)
