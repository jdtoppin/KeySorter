# KeySorter

A World of Warcraft addon that automatically sorts raid members into balanced Mythic+ groups.

Built for raid leaders who organize weekly M+ events and need to quickly form balanced 5-man groups from a raid of 10-40 players.

## Features

- **Auto-Scan Roster** — Automatically detects raid members as they join or leave, pulling M+ rating, average key level, timed/untimed runs, item level, and class utilities using Raider.IO data (with Blizzard API fallback)
- **Auto-Sort into Groups** — Forms balanced 5-man groups (1 tank, 1 healer, 3 DPS) sorted by skill tier so that players of similar M+ score are grouped together
- **Utility Balancing** — Ensures each group has battle rez and bloodlust coverage when possible, swapping DPS between adjacent groups within a score threshold
- **Group Locking** — Lock individual groups to preserve their composition when re-sorting after new players join. Locked groups are excluded from the sort algorithm but still support drag-and-drop adjustments
- **Drag and Drop** — Manually move players between groups by dragging their name to another group slot
- **Character Detail** — Click any player name (roster or group view) to see a full breakdown: dungeon-by-dungeon results, key thresholds (+5/+10/+15/+20 timed runs), past season score, item level, and class utilities
- **Per-Group Announce** — Announce each group independently to raid chat, useful when cycling players in and out during large events
- **Score & Role Filters** — Filter the roster by score range, role, class utility, or minimum timed runs
- **Item Level Caching** — Persists item level data across sessions via SavedVariables, so returning players show their ilvl immediately even before inspect range
- **Leader Sync** — Broadcast group assignments to raid assistants via addon comms
- **Permission Gated** — Sort, apply, sync, and announce are restricted to raid leaders and assistants
- **Preview Mode** — Generate fake raid data (1-40 players) to test the UI and sort algorithm without being in a raid. Configure in Settings
- **Minimap Button** — Standard circular minimap button with tracking border for quick access

## Usage

1. Install KeySorter into `Interface/AddOns/KeySorter`
2. Form a raid group
3. Type `/ks` to open the KeySorter window, or click the minimap button
4. The **Roster** tab auto-populates as players join — click column headers to sort, use filters to narrow the view
5. Switch to the **Groups** tab and click **Sort** to generate balanced groups and move players into raid subgroups
6. Lock groups you're happy with, then re-sort as new players join
7. Click the **Announce** button on each group card to post that group to raid chat
8. Use **Sync** to share assignments with other assistants

## Commands

| Command | Description |
|---------|-------------|
| `/ks` | Toggle main window |
| `/ks sort` | Sort into groups |
| `/ks apply` | Move players to raid subgroups |
| `/ks announce` | Post all groups to raid chat |
| `/ks announce N` | Post group N to raid chat |
| `/ks sync` | Sync groups to assistants |
| `/ks preview` | Open settings (preview mode) |
| `/ks about` | Show overview and command reference |
| `/ks help` | Print command list to chat |

## How Sorting Works

1. Players are separated into three pools: Tanks, Healers, and DPS
2. Each pool is sorted by M+ score (descending), with item level as a tiebreaker
3. The number of groups is determined by the scarcest role — the maximum number of complete groups that can be formed with 1 tank, 1 healer, and 3 DPS each
4. Players are assigned by skill tier — the highest-scored tank, healer, and top 3 DPS form Group 1, the next best form Group 2, and so on
5. If the raid is not a perfect multiple of 5, extra players go to the Unassigned section (raid subgroups hold a maximum of 5)
6. A utility balancing pass checks each group for battle rez and bloodlust coverage — if a group is missing a utility, the algorithm swaps a DPS with another group that has a surplus, preferring adjacent groups and staying within a score threshold
7. Locked groups are fully excluded from the sort and utility pass, preserving their exact composition

## Data Sources

- **Raider.IO** (primary) — When installed, provides M+ score, total timed/untimed runs, and key level thresholds (+5, +10, +15, +20). Data is bundled locally with the Raider.IO addon, no network calls required
- **Blizzard API** (fallback) — `C_PlayerInfo.GetPlayerMythicPlusRatingSummary` provides best run per dungeon when Raider.IO is not available
- **Item Level** — Collected via background inspect when players are in range. Cached in SavedVariables for returning players

## Project Structure

```
KeySorter/
├── KeySorter.toc          # Addon metadata
├── Core.lua               # Init, events, slash commands, SavedVariables, preview data
├── Data.lua               # Constants (class utilities, score thresholds, dungeon IDs)
├── Widgets.lua            # UI widget library (buttons, dropdowns, sliders, tooltips)
├── Scanner.lua            # Raid roster scanning, M+ data collection, ilvl caching
├── Sorter.lua             # Group formation algorithm with lock support
├── Comm.lua               # Leader/assistant sync via addon comms
└── UI/
    ├── MainFrame.lua      # Main window, tab system, resize, apply/announce
    ├── RosterView.lua     # Sortable roster with filters
    ├── GroupView.lua      # Group cards with drag-and-drop and locking
    ├── CharacterDetail.lua# Full character breakdown overlay
    ├── Settings.lua       # Settings page (preview mode toggle, player count)
    ├── About.lua          # Overview, sort logic, commands reference
    └── Minimap.lua        # Circular minimap button
```

## Requirements

- World of Warcraft (Midnight, Interface 120000)
- Optional: [Raider.IO](https://raider.io/addon) for enhanced M+ data

## License

[GNU General Public License v3.0](LICENSE)
