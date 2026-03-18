# KeySorter

A World of Warcraft addon that automatically sorts raid members into balanced Mythic+ groups.

Built for raid leaders who organize weekly M+ events and need to quickly form balanced 5-man groups from a raid of 10-40 players.

## Features

### Roster View
- Auto-scans raid members on join — pulls M+ score, average key level, item level, and class utilities
- Works solo too — your character shows up without needing a group
- Sortable columns: name, score, iLvl, avg key, runs, role, utility
- Filter dropdowns for score range, role, and utility type
- Shift-hover any member for a dungeon breakdown tooltip with linked alts
- Click any member to open their full character profile

### Group Builder
- Forms balanced 5-man groups (1 tank, 1 healer, 3 DPS) with one click
- **Sort All** re-sorts all unlocked groups from scratch
- **Sort New** only places unassigned players into empty groups without touching existing ones
- Three sort modes: **Skill Matched**, **Balanced** (snake draft), or **Gear** (item level)
- Battle Rez and Bloodlust balanced automatically — utility pulled from unassigned first
- Responsive card grid that reflows when you resize the window
- Drag and drop members between groups — swaps sync to WoW raid subgroups
- Mark groups as done with a tick toggle to preserve them during re-sorts
- Smart roster reconciliation — new players go to Unassigned, leavers removed
- Per-group Announce button to post assignments to raid chat

### Character History
- Persistent database of every player who has joined your raids
- Browse, search, sort, and filter all historical characters
- Filter by score range, role, or utility type
- Last seen displayed in weekly format (Today, 2d ago, 1w ago, 3w ago)
- Click any character to view their full profile, notes, and alt links

### Character Detail
- Responsive two-column layout: overview, utilities, timed key breakdown, notes, and alt linking on the left; dungeon breakdown on the right
- Collapses to single column when the window is narrow
- Season scores displayed from persistent history — tracks across season transitions
- Add notes and link alts directly from the detail view

### Season Score Tracking
- M+ scores saved permanently per season in SavedVariables
- Historical scores survive season transitions — when a new season launches, update three lines in `Data.lua`
- Character detail shows all seasons with recorded scores

### Addon Communication
- Group assignments synced to raid assistants automatically via addon messages
- Multi-part message chunking handles large raids (40+ players)
- Sender permission validation — only leaders/assistants can broadcast
- Guild version check notifies members when updates are available

### Settings
- **UI Scale** slider (0.5x–2.0x)
- Customizable Welcome and Gather announcement messages
- Preview Mode with configurable player count for testing without a raid
- Live Simulation — watch groups form in real time as fake players join
- Clear All History with confirmation dialog

### Other
- Sidebar navigation with animated gradient highlights
- Smooth fade in/out window animation, ESC to close
- Window resize persists across sessions
- Confirmation dialog for destructive actions
- Minimap button with support for both circular and square minimaps
- Custom tooltip system with cyan accent border
- Permission gated — sort, apply, sync, and announce restricted to leaders/assistants

## Usage

1. Install KeySorter into `Interface/AddOns/KeySorter`
2. Form a raid group (or open solo to see your own data)
3. Type `/ks` to open the KeySorter window, or click the minimap button
4. The **Roster** view auto-populates as players join
5. Click **Groups** — use **Sort All** to form groups, or **Sort New** to place newcomers
6. Mark groups as done, then re-sort as new players arrive
7. Click **Announce** to post group assignments to raid chat
8. Visit **History** to browse all players who have ever joined your raids

## Commands

| Command | Description |
|---------|-------------|
| `/ks` | Toggle main window |
| `/ks sort` | Sort into groups (Sort All) |
| `/ks apply` | Move players to raid subgroups |
| `/ks announce` | Post all groups to raid chat |
| `/ks announce N` | Post group N to raid chat |
| `/ks sync` | Force sync groups to assistants |
| `/ks preview` | Open settings (preview mode) |
| `/ks settings` | Open settings |
| `/ks about` | Show about page |
| `/ks help` | Print command list to chat |

## How Sorting Works

Three sort modes are available via the toggle on the Groups toolbar:

- **Skill Matched** (default) — Groups players of similar skill together. Top-scored tank, healer, and 3 DPS form Group 1, next best form Group 2, etc.
- **Balanced** — Snake draft (1→N, N→1) distributes skill evenly so each group gets a mix of high and low scorers.
- **Gear** — Sorts by item level instead of M+ score (iLvl primary, score tiebreak). Useful early in a season.

All modes share these steps:

1. Players are separated into Tanks, Healers, and DPS pools, each sorted by the selected criteria
2. Number of groups is determined by the scarcest role
3. Tanks and healers assigned in order; DPS distributed by mode
4. A utility pass pulls the highest-scored utility player from unassigned, then swaps DPS between groups to cover Battle Rez and Bloodlust gaps
5. Locked/done groups are fully excluded from sorting, utility balancing, and reconciliation
6. Extra players go to Unassigned — use **Sort New** to form groups from them without touching existing groups

## Data Sources

- **Raider.IO** (primary) — M+ score via `mplusCurrent.score`, timed key brackets, per-dungeon runs. Data bundled locally with the Raider.IO addon.
- **Blizzard API** (fallback) — `C_PlayerInfo.GetPlayerMythicPlusRatingSummary` provides best run per dungeon.
- **Item Level** — Collected via background inspect with backoff retry, cached in SavedVariables for returning players.

## Project Structure

```
KeySorter/
├── KeySorter.toc           # Addon metadata
├── Core.lua                # Init, events, slash commands, SavedVariables, preview data
├── Data.lua                # Constants (utilities, thresholds, dungeons, season tracking)
├── Widgets.lua             # UI widgets (buttons, dropdowns, sliders, tooltips, confirm dialog)
├── Scanner.lua             # Roster scanning, M+ data, season score persistence
├── Sorter.lua              # Group formation, utility balancing, reconciliation
├── Comm.lua                # Addon comms with message chunking and permission validation
├── Media/                  # TGA textures (AF icons, arrows, tick, gradient, logos)
├── scripts/                # Asset generation (generate_tga.py, generate_logo.py)
├── .pkgmeta                # CurseForge packager config
├── .github/workflows/      # GitHub Actions release automation
└── UI/
    ├── Sidebar.lua         # Sidebar navigation with animated highlights
    ├── MainFrame.lua       # Main window, content area, toolbar, resize handling
    ├── RosterView.lua      # Sortable roster with filters
    ├── GroupView.lua       # Responsive group cards with drag-and-drop and frame pooling
    ├── PlayersView.lua     # Character History — historical player database
    ├── CharacterDetail.lua # Responsive character profile overlay
    ├── Settings.lua        # Settings panel (scale, announcements, preview, simulation)
    ├── About.lua           # Features, sort logic, commands, changelog, credits
    └── Minimap.lua         # Minimap button (circular and square support)
```

## Requirements

- World of Warcraft (Midnight, Interface 120001)
- Optional: [Raider.IO](https://raider.io/addon) for enhanced M+ data

## Installation

### Manual
Download the latest release from [GitHub Releases](https://github.com/jdtoppin/KeySorter/releases) and extract to `Interface/AddOns/KeySorter`.

### CurseForge
Coming soon.

## Acknowledgments

UI components inspired by [AbstractFramework](https://github.com/enderneko/AbstractFramework) by enderneko (GPLv3).

## License

[GNU General Public License v3.0](LICENSE)
