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
    local numRuns = 0

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
                    numRuns = numRuns + 1
                end
            end
        end
    end

    local avgKeyLevel = numRuns > 0 and (totalKeyLevel / numRuns) or 0

    local entry = {
        name = name,
        unit = unit,
        classFile = classFile,
        role = role,
        score = score,
        runs = runs,
        avgKeyLevel = avgKeyLevel,
        numRuns = numRuns,
        raidIndex = raidIndex,
        hasBrez = KS.BREZ[classFile] or false,
        hasLust = KS.LUST[classFile] or false,
        hasShroud = KS.SHROUD[classFile] or false,
    }

    table.insert(KS.roster, entry)
end
