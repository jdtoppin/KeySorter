local addonName, KS = ...

function KS.ScanRoster()
    wipe(KS.roster)

    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then
        -- Solo: scan just the player
        local name, realm = UnitName("player")
        if realm and realm ~= "" then
            name = name .. "-" .. realm
        end
        KS.ScanUnit("player", name)
        if KS.UpdateRosterView then KS.UpdateRosterView() end
        return
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        if not UnitExists(unit) then
            if prefix == "party" and i == numMembers then
                unit = "player"
            else
                break
            end
        end
        -- Use UnitName for the name to stay consistent with the unit ID
        -- (GetRaidRosterInfo can have different ordering during roster changes)
        local name, realm = UnitName(unit)
        if realm and realm ~= "" and realm ~= GetRealmName() then
            name = name .. "-" .. realm
        end
        if name and UnitIsConnected(unit) then
            KS.ScanUnit(unit, name, i)
        end
    end

    if KS.UpdateRosterView then
        KS.UpdateRosterView()
    end
end

-- Try Raider.IO first, returns true + populated entry fields if successful
local function ScanFromRaiderIO(unit, entry)
    if not RaiderIO or not RaiderIO.GetProfile then return false end

    local profile = RaiderIO.GetProfile(unit)
    if not profile or not profile.success then return false end

    local mkp = profile.mythicKeystoneProfile
    if not mkp or not mkp.hasRenderableData then return false end

    entry.score = mkp.mplusCurrent and mkp.mplusCurrent.score or mkp.currentScore or 0

    -- Run counts at key level thresholds
    entry.keystoneFivePlus = mkp.keystoneFivePlus or 0
    entry.keystoneTenPlus = mkp.keystoneTenPlus or 0
    entry.keystoneFifteenPlus = mkp.keystoneFifteenPlus or 0
    entry.keystoneTwentyPlus = mkp.keystoneTwentyPlus or 0

    -- Per-dungeon data from sortedDungeons (filter to S1 Midnight dungeons only)
    local s1DungeonSet = {}
    for _, id in ipairs(KS.DUNGEON_IDS) do s1DungeonSet[id] = true end

    local totalKeyLevel = 0
    local numDungeons = 0

    if mkp.sortedDungeons then
        for _, d in ipairs(mkp.sortedDungeons) do
            if d.dungeon and d.level and d.level > 0 then
                local mapID = d.dungeon.id or d.dungeon.challengeModeID
                -- Only track S1 Midnight dungeons
                if mapID and s1DungeonSet[mapID] then
                    entry.runs[mapID] = {
                        level = d.level,
                        timed = d.chests and d.chests > 0,
                        chests = d.chests or 0,
                        fractionalTime = d.fractionalTime,
                    }
                    totalKeyLevel = totalKeyLevel + d.level
                    numDungeons = numDungeons + 1
                end
            end
        end
    end

    entry.avgKeyLevel = numDungeons > 0 and (totalKeyLevel / numDungeons) or 0

    -- Total timed runs: sum of separate brackets (+5-9, +10-14, +15-19, +20+)
    entry.numRuns = (entry.keystoneFivePlus or 0)
                  + (entry.keystoneTenPlus or 0)
                  + (entry.keystoneFifteenPlus or 0)
                  + (entry.keystoneTwentyPlus or 0)
    entry.numTimed = entry.numRuns
    entry.numUntimed = 0
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
    if role == "NONE" then
        -- Fall back to spec role when no group role is assigned
        if UnitIsUnit(unit, "player") then
            local specIdx = GetSpecialization()
            if specIdx then
                role = GetSpecializationRole(specIdx) or "DAMAGER"
            else
                role = "DAMAGER"
            end
        else
            role = "DAMAGER"
        end
    end

    local level = UnitLevel(unit) or 0

    local entry = {
        name = name,
        unit = unit,
        classFile = classFile,
        role = role,
        level = level,
        score = 0,
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

    -- Fall back to cached ilvl if we didn't get a live value
    if entry.ilvl == 0 and KeySorterDB and KeySorterDB.ilvlCache and KeySorterDB.ilvlCache[name] then
        entry.ilvl = KeySorterDB.ilvlCache[name]
    end

    -- Cache any live ilvl we got
    if entry.ilvl > 0 and KeySorterDB and KeySorterDB.ilvlCache then
        KeySorterDB.ilvlCache[name] = entry.ilvl
    end

    -- Precompute utility count for roster sorting
    entry.utilityCount = (entry.hasBrez and 1 or 0) + (entry.hasLust and 1 or 0) + (entry.hasShroud and 1 or 0)

    -- Only persist to DB when tracking is enabled (raid + permitted + confirmed)
    if not KS.previewMode and KS.trackingEnabled then
        -- Track this character in the known characters database
        if KeySorterDB and KeySorterDB.knownChars and name then
            KeySorterDB.knownChars[name] = {
                classFile = classFile,
                score = entry.score,
                ilvl = entry.ilvl,
                role = role,
                lastSeen = time(),
            }
        end

        -- Persist season score (kept forever, never pruned)
        if KeySorterDB and KeySorterDB.seasonScores and name and entry.score > 0 then
            local ss = KeySorterDB.seasonScores[name] or {}
            ss[KS.CURRENT_SEASON] = math.max(ss[KS.CURRENT_SEASON] or 0, entry.score)
            KeySorterDB.seasonScores[name] = ss
        end
    end

    -- Attach a copy of season history to entry for UI display (avoid mutating DB)
    entry.seasonScores = {}
    local source = KeySorterDB and KeySorterDB.seasonScores and KeySorterDB.seasonScores[name]
    if source then
        for k, v in pairs(source) do entry.seasonScores[k] = v end
    end

    table.insert(KS.roster, entry)
end
