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
    { key = "gear",     label = "Gear",           desc = "Group players by item level (useful early in a season)." },
}
KS.sortMode = "matched"

-- Class colors fallback
KS.CLASS_COLORS = RAID_CLASS_COLORS

-- Shared color/name helpers (used by RosterView, CharacterDetail, GroupView)
function KS.GetScoreColor(score)
    if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then return color.r, color.g, color.b end
    end
    if score >= 2500 then return 1, 0.5, 0
    elseif score >= 2000 then return 0.6, 0.2, 0.8
    elseif score >= 1500 then return 0, 0.4, 1
    elseif score >= 1000 then return 0, 0.8, 0
    elseif score >= 500 then return 1, 1, 1
    else return 0.6, 0.6, 0.6 end
end

function KS.GetIlvlColor(ilvl)
    local anchors = KS.ILVL_COLORS
    if not anchors or #anchors == 0 then return 1, 1, 1 end
    if ilvl <= anchors[1].ilvl then return anchors[1].r, anchors[1].g, anchors[1].b end
    if ilvl >= anchors[#anchors].ilvl then return anchors[#anchors].r, anchors[#anchors].g, anchors[#anchors].b end
    for i = 2, #anchors do
        if ilvl <= anchors[i].ilvl then
            local lo, hi = anchors[i - 1], anchors[i]
            local t = (ilvl - lo.ilvl) / (hi.ilvl - lo.ilvl)
            return lo.r + t * (hi.r - lo.r), lo.g + t * (hi.g - lo.g), lo.b + t * (hi.b - lo.b)
        end
    end
    return 1, 1, 1
end

function KS.GetDungeonName(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name then return name end
    end
    return KS.DUNGEON_NAMES[mapID] or ("Dungeon " .. mapID)
end
