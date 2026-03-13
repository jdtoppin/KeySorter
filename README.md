# KeySorter

A World of Warcraft addon that automatically sorts raid members into balanced Mythic+ groups.

Built for raid leaders who organize weekly M+ events and need to quickly form balanced 5-man groups from a raid of 10-40 players.

## Features

- **Roster Scanning** — Pulls M+ rating, average key level, and per-dungeon breakdown for every raid member using in-game APIs
- **Auto-Sort** — Forms balanced groups (1 tank, 1 healer, 3 DPS) using a snake-draft algorithm that distributes players by M+ score
- **Utility Balancing** — Ensures each group has battle rez and bloodlust coverage when possible, swapping DPS between groups within a ±50 score tolerance
- **Score Filters** — Filter the roster view by score ranges (<500 through 3.5k+)
- **Leader Sync** — Broadcast group assignments to raid assistants via addon comms
- **Permission Gated** — Only raid leaders and assistants can scan, sort, and sync
- **Minimap Button** — Draggable "KS" button on the minimap for quick access

## Dependencies

- [AbstractFramework](https://github.com/enderneko/AbstractFramework) by enderneko — must be installed as a separate addon

## Usage

1. Install [AbstractFramework](https://github.com/enderneko/AbstractFramework) into `Interface/AddOns/AbstractFramework`
2. Install KeySorter into `Interface/AddOns/KeySorter`
3. Form a raid group
4. Type `/ks` to open the KeySorter window, or click the **KS** minimap button
5. Click **Scan** to collect M+ data from all raid members
6. Click **Sort** to generate balanced groups
7. Click **Sync** to share assignments with assistants
8. Use the **Roster** and **Groups** tabs to review data

## Commands

| Command | Description |
|---------|-------------|
| `/ks` | Toggle main window |
| `/ks scan` | Scan raid roster for M+ data |
| `/ks sort` | Sort members into balanced groups |
| `/ks sync` | Sync groups to raid assistants |
| `/ks about` | Show credits and license info |
| `/ks help` | List available commands |

## How Sorting Works

1. Players are separated into tank, healer, and DPS pools
2. Each pool is sorted by M+ score (descending)
3. Number of groups = `min(tanks, healers, floor(dps/3))`
4. Tanks and healers are assigned round-robin (highest score first)
5. DPS are distributed via snake draft (1->N, N->1, repeat) to balance average group scores
6. A utility pass swaps DPS between groups to improve battle rez / bloodlust coverage without exceeding a ±50 score difference

## Project Structure

```
KeySorter/
├── KeySorter.toc       # Addon metadata
├── Core.lua            # Init, events, slash commands, SavedVariables
├── Data.lua            # Constants (class utilities, score thresholds)
├── Scanner.lua         # Raid roster scanning, M+ data collection
├── Sorter.lua          # Group formation algorithm
├── Comm.lua            # Leader/assistant sync via addon comms
└── UI/
    ├── MainFrame.lua   # Main window, tabs, buttons
    ├── RosterView.lua  # Scrollable roster with sortable columns
    ├── GroupView.lua    # Group cards display
    ├── About.lua       # Credits and license acknowledgments
    └── Minimap.lua     # Minimap button
```

## Acknowledgments

This addon uses [AbstractFramework](https://github.com/enderneko/AbstractFramework) by enderneko, licensed under GPL-3.0.

## License

[GNU General Public License v3.0](LICENSE)
