local addonName, KS = ...

-- Class utilities
KS.BREZ = {
    DRUID = true,
    DEATHKNIGHT = true,
    WARLOCK = true,
    PALADIN = true,
}

KS.LUST = {
    MAGE = true,
    SHAMAN = true,
    HUNTER = true,
    EVOKER = true,
}

KS.SHROUD = {
    ROGUE = true,
}

-- Score thresholds for filtering
KS.SCORE_THRESHOLDS = {
    { label = "All Scores", min = 0,    max = 99999 },
    { label = "<500",    min = 0,    max = 499 },
    { label = "500-1k",  min = 500,  max = 999 },
    { label = "1k-1.5k", min = 1000, max = 1499 },
    { label = "1.5k-2k", min = 1500, max = 1999 },
    { label = "2k-2.5k", min = 2000, max = 2499 },
    { label = "2.5k-3k", min = 2500, max = 2999 },
    { label = "3k-3.5k", min = 3000, max = 3499 },
    { label = "3.5k+",   min = 3500, max = 99999 },
}

-- Season 1 Midnight dungeon challengeModeIDs → short names (fallback for tooltip)
KS.DUNGEON_NAMES = {
    [507] = "Magister's Terrace",
    [508] = "Windrunner Spire",
    [509] = "Maisara Caverns",
    [510] = "Nexus Point Xenas",
    [511] = "Seat of the Triumvirate",
    [512] = "Algeth'ar Academy",
    [513] = "Skyreach",
    [514] = "Pit of Saron",
}

-- Ordered list of dungeon IDs for consistent tooltip display
KS.DUNGEON_IDS = { 507, 508, 509, 510, 511, 512, 513, 514 }

-- Item level color gradient anchors (WoW quality colors)
-- Midnight Season 1 — adjust ILVL_MAX if mythic raid cap differs
KS.ILVL_MAX = 289
KS.ILVL_COLORS = {
    -- { ilvl, r, g, b }
    -- Smooth gradient: Gray → Green → Blue → Purple
    { ilvl = 207, r = 0.62, g = 0.62, b = 0.62 },  -- Gray (poor / fresh max level)
    { ilvl = 230, r = 0.12, g = 1.00, b = 0.00 },  -- Green (uncommon / normal dungeon)
    { ilvl = 250, r = 0.00, g = 0.44, b = 0.87 },  -- Blue (rare / heroic dungeon / low M+)
    { ilvl = 270, r = 0.39, g = 0.33, b = 0.90 },  -- Blue-purple (high M+ / normal raid)
    { ilvl = 289, r = 0.64, g = 0.21, b = 0.93 },  -- Purple (epic / mythic raid)
}

-- Role icons (atlas)
KS.ROLE_ICONS = {
    TANK = "roleicon-tiny-tank",
    HEALER = "roleicon-tiny-healer",
    DAMAGER = "roleicon-tiny-dps",
}

-- Utility swap threshold (max score difference allowed)
KS.SWAP_THRESHOLD = 50

-- Sort modes
KS.SORT_MODES = {
    { key = "matched",  label = "Skill Matched", desc = "Group players of similar skill level together." },
    { key = "balanced", label = "Balanced",       desc = "Distribute skill levels evenly across groups (snake draft)." },
}
KS.sortMode = "matched"

-- Class colors fallback
KS.CLASS_COLORS = RAID_CLASS_COLORS
