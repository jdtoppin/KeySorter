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

    print(format("|cff00ccffKeySorter|r: Scanned %d member(s).", #KS.roster))
end

function KS.ScanUnit(unit, name, raidIndex)
    local _, classFile = UnitClass(unit)
    local role = UnitGroupRolesAssigned(unit)
    if role == "NONE" then role = "DAMAGER" end

    local score = 0
    local runs = {}
    local totalKeyLevel = 0
    local numTimed = 0
    local numUntimed = 0

    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if summary then
        score = summary.currentSeasonScore or 0
        if summary.runs then
            for _, run in ipairs(summary.runs) do
                runs[run.challengeModeID] = {
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
        end
    end

    local numRuns = numTimed + numUntimed
    local avgKeyLevel = numRuns > 0 and (totalKeyLevel / numRuns) or 0

    -- Item level: GetAverageItemLevel works for "player", others need inspect
    local ilvl = 0
    if UnitIsUnit(unit, "player") then
        local overall, equipped = GetAverageItemLevel()
        ilvl = math.floor(equipped or overall or 0)
    elseif C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local inspectIlvl = C_PaperDollInfo.GetInspectItemLevel(unit)
        ilvl = inspectIlvl and math.floor(inspectIlvl) or 0
    end

    local entry = {
        name = name,
        unit = unit,
        classFile = classFile,
        role = role,
        score = score,
        runs = runs,
        avgKeyLevel = avgKeyLevel,
        numRuns = numRuns,
        numTimed = numTimed,
        numUntimed = numUntimed,
        ilvl = ilvl,
        raidIndex = raidIndex,
        hasBrez = KS.BREZ[classFile] or false,
        hasLust = KS.LUST[classFile] or false,
        hasShroud = KS.SHROUD[classFile] or false,
    }

    table.insert(KS.roster, entry)
end
