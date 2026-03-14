local addonName, KS = ...

function KS.ScanRoster()
    wipe(KS.roster)

    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then
        -- Solo: scan just the player
        KS.ScanUnit("player", UnitName("player"))
        return
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        if not UnitExists(unit) then
            if prefix == "party" and i == numMembers then
                unit = "player"
            else
                break -- shouldn't happen but be safe
            end
        end
        local name = GetRaidRosterInfo(i)
        if not name and prefix == "party" then
            name = UnitName(unit)
        end
        if name and UnitIsConnected(unit) then
            KS.ScanUnit(unit, name, i)
        end
    end

    if KS.UpdateRosterView then
        KS.UpdateRosterView()
    end

    local source = (RaiderIO and RaiderIO.GetProfile) and "Raider.IO" or "Blizzard API"
    print(format("|cff00ccffKeySorter|r: Scanned %d member(s) via %s.", #KS.roster, source))
end

-- Try Raider.IO first, returns true + populated entry fields if successful
local function ScanFromRaiderIO(unit, entry)
    if not RaiderIO or not RaiderIO.GetProfile then return false end

    local profile = RaiderIO.GetProfile(unit)
    if not profile or not profile.success then return false end

    local mkp = profile.mythicKeystoneProfile
    if not mkp or not mkp.hasRenderableData then return false end

    entry.score = mkp.currentScore or 0
    entry.previousScore = mkp.previousScore or 0

    -- Run counts at key level thresholds
    entry.keystoneFivePlus = mkp.keystoneFivePlus or 0
    entry.keystoneTenPlus = mkp.keystoneTenPlus or 0
    entry.keystoneFifteenPlus = mkp.keystoneFifteenPlus or 0
    entry.keystoneTwentyPlus = mkp.keystoneTwentyPlus or 0

    -- Per-dungeon data from sortedDungeons
    local totalKeyLevel = 0
    local numTimed = 0
    local numUntimed = 0

    if mkp.sortedDungeons then
        for _, d in ipairs(mkp.sortedDungeons) do
            if d.dungeon and d.level and d.level > 0 then
                local mapID = d.dungeon.id or d.dungeon.challengeModeID
                if mapID then
                    entry.runs[mapID] = {
                        level = d.level,
                        timed = d.chests and d.chests > 0,
                        chests = d.chests or 0,
                        fractionalTime = d.fractionalTime,
                    }
                end
                totalKeyLevel = totalKeyLevel + d.level
                if d.chests and d.chests > 0 then
                    numTimed = numTimed + 1
                else
                    numUntimed = numUntimed + 1
                end
            end
        end
    end

    local numRuns = numTimed + numUntimed
    entry.avgKeyLevel = numRuns > 0 and (totalKeyLevel / numRuns) or 0
    entry.numRuns = numRuns
    entry.numTimed = numTimed
    entry.numUntimed = numUntimed
    entry.dataSource = "raiderio"

    return true
end

-- Fallback: native Blizzard API (best run per dungeon only)
local function ScanFromBlizzard(unit, entry)
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if summary then
        entry.score = summary.currentSeasonScore or 0
        if summary.runs then
            local totalKeyLevel = 0
            local numTimed = 0
            local numUntimed = 0

            for _, run in ipairs(summary.runs) do
                entry.runs[run.challengeModeID] = {
                    level = run.bestRunLevel,
                    timed = run.finishedSuccess,
                    score = run.mapScore,
                }
                if run.bestRunLevel and run.bestRunLevel > 0 then
                    totalKeyLevel = totalKeyLevel + run.bestRunLevel
                    if run.finishedSuccess then
                        numTimed = numTimed + 1
                    else
                        numUntimed = numUntimed + 1
                    end
                end
            end

            local numRuns = numTimed + numUntimed
            entry.avgKeyLevel = numRuns > 0 and (totalKeyLevel / numRuns) or 0
            entry.numRuns = numRuns
            entry.numTimed = numTimed
            entry.numUntimed = numUntimed
        end
    end
    entry.dataSource = "blizzard"
end

function KS.ScanUnit(unit, name, raidIndex)
    local _, classFile = UnitClass(unit)
    local role = UnitGroupRolesAssigned(unit)
    if role == "NONE" then role = "DAMAGER" end

    local entry = {
        name = name,
        unit = unit,
        classFile = classFile,
        role = role,
        score = 0,
        previousScore = 0,
        runs = {},
        avgKeyLevel = 0,
        numRuns = 0,
        numTimed = 0,
        numUntimed = 0,
        keystoneFivePlus = 0,
        keystoneTenPlus = 0,
        keystoneFifteenPlus = 0,
        keystoneTwentyPlus = 0,
        ilvl = 0,
        raidIndex = raidIndex,
        hasBrez = KS.BREZ[classFile] or false,
        hasLust = KS.LUST[classFile] or false,
        hasShroud = KS.SHROUD[classFile] or false,
        dataSource = "none",
    }

    -- Try Raider.IO first, fall back to Blizzard API
    if not ScanFromRaiderIO(unit, entry) then
        ScanFromBlizzard(unit, entry)
    end

    -- Item level: GetAverageItemLevel works for "player", others need inspect
    if UnitIsUnit(unit, "player") then
        local overall, equipped = GetAverageItemLevel()
        entry.ilvl = math.floor(equipped or overall or 0)
    elseif C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local inspectIlvl = C_PaperDollInfo.GetInspectItemLevel(unit)
        entry.ilvl = inspectIlvl and math.floor(inspectIlvl) or 0
    end

    table.insert(KS.roster, entry)
end
