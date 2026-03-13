# KeySorter

A World of Warcraft addon that automatically sorts raid members into balanced Mythic+ groups.

Built for raid leaders who organize weekly M+ events and need to quickly form balanced 5-man groups from a raid of 10-40 players.

## Features

- **Roster Scanning** — Pulls M+ rating, average key level, and per-dungeon breakdown for every raid member using in-game APIs
- **Auto-Sort** — Forms balanced groups (1 tank, 1 healer, 3 DPS) using a snake-draft algorithm that distributes players by M+ score
- **Utility Balancing** — Ensures each group has battle rez and bloodlust coverage when possible, swapping DPS between groups within a ±50 score tolerance
- **Score Filters** — Filter the roster view by score ranges (<500, 500-1k, 1k-1.5k, 1.5k-2k, 2k+)
- **Leader Sync** — Broadcast group assignments to raid assistants via addon comms
- **Permission Gated** — Only raid leaders and assistants can scan, sort, and sync

## Usage

1. Install the addon into your `Interface/AddOns/KeySorter` directory
2. Form a raid group
3. Type `/ks` to open the KeySorter window
4. Click **Scan** to collect M+ data from all raid members
5. Click **Sort** to generate balanced groups
6. Click **Sync** to share assignments with assistants
7. Use the **Roster** and **Groups** tabs to review data

## How Sorting Works

1. Players are separated into tank, healer, and DPS pools
2. Each pool is sorted by M+ score (descending)
3. Number of groups = `min(tanks, healers, floor(dps/3))`
4. Tanks and healers are assigned round-robin (highest score first)
5. DPS are distributed via snake draft (1→N, N→1, repeat) to balance average group scores
6. A utility pass swaps DPS between groups to improve battle rez / bloodlust coverage without exceeding a ±50 score difference

## Project Structure

```
KeySorter/
├── KeySorter.toc       # Addon metadata
├── Core.lua            # Init, events, slash command, SavedVariables
├── Data.lua            # Constants (class utilities, score thresholds)
├── Scanner.lua         # Raid roster scanning, M+ data collection
├── Sorter.lua          # Group formation algorithm
├── Comm.lua            # Leader/assistant sync via addon comms
└── UI/
    ├── MainFrame.lua   # Main window, tabs, buttons
    ├── RosterView.lua  # Scrollable roster with sortable columns
    └── GroupView.lua   # Group cards display
```

## Requirements

- World of Warcraft (The War Within / Midnight, Interface 120000)
- No external library dependencies
