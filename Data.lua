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
    { label = "All",     min = 0,    max = 99999 },
    { label = "<500",    min = 0,    max = 499 },
    { label = "500-1k",  min = 500,  max = 999 },
    { label = "1k-1.5k", min = 1000, max = 1499 },
    { label = "1.5k-2k", min = 1500, max = 1999 },
    { label = "2k+",     min = 2000, max = 99999 },
}

-- Role icons (atlas)
KS.ROLE_ICONS = {
    TANK = "roleicon-tiny-tank",
    HEALER = "roleicon-tiny-healer",
    DAMAGER = "roleicon-tiny-dps",
}

-- Utility swap threshold (max score difference allowed)
KS.SWAP_THRESHOLD = 50

-- Class colors fallback
KS.CLASS_COLORS = RAID_CLASS_COLORS
