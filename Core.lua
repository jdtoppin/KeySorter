local addonName, KS = ...

KS.roster = {}
KS.groups = {}
KS.unassigned = {}
KS.previewMode = false
KS.previewPlayerCount = 25

---------------------------------------------------------------------------
-- Inspect queue: background ilvl collection for raid members
---------------------------------------------------------------------------
local inspectQueue = {}
local inspectBusy = false
local INSPECT_INTERVAL = 1.5 -- seconds between inspects

local function ProcessInspectQueue()
    if inspectBusy or #inspectQueue == 0 then return end
    if InCombatLockdown() then return end

    local unit = tremove(inspectQueue, 1)
    if unit and UnitExists(unit) and UnitIsConnected(unit) and CheckInteractDistance(unit, 1) then
        inspectBusy = true
        NotifyInspect(unit)
    elseif #inspectQueue > 0 then
        C_Timer.After(0.1, ProcessInspectQueue)
    end
end

local function QueueInspect(unit)
    if UnitIsUnit(unit, "player") then return end
    -- Don't queue duplicates
    for _, queued in ipairs(inspectQueue) do
        if queued == unit then return end
    end
    table.insert(inspectQueue, unit)
    ProcessInspectQueue()
end

local function QueueAllMembers()
    if KS.previewMode then return end
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsUnit(unit, "player") then
            QueueInspect(unit)
        end
    end
end

local function OnInspectReady(guid)
    inspectBusy = false

    -- Find the unit and update ilvl in roster
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        for _, member in ipairs(KS.roster) do
            if member.unit and UnitExists(member.unit) and UnitGUID(member.unit) == guid then
                local inspectIlvl = C_PaperDollInfo.GetInspectItemLevel(member.unit)
                if inspectIlvl and inspectIlvl > 0 then
                    member.ilvl = math.floor(inspectIlvl)
                    -- Cache for future sessions
                    if KeySorterDB and KeySorterDB.ilvlCache and member.name then
                        KeySorterDB.ilvlCache[member.name] = member.ilvl
                    end
                    if KS.UpdateRosterView then KS.UpdateRosterView() end
                end
                break
            end
        end
    end

    ClearInspectPlayer()

    -- Continue processing queue
    if #inspectQueue > 0 then
        C_Timer.After(INSPECT_INTERVAL, ProcessInspectQueue)
    end
end

---------------------------------------------------------------------------
-- Main event frame
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("INSPECT_READY")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            KeySorterDB = KeySorterDB or {}
            KeySorterDB.point = KeySorterDB.point or { "CENTER", nil, "CENTER", 0, 0 }
            KeySorterDB.filterIdx = KeySorterDB.filterIdx or 1
            KeySorterDB.minimapPos = KeySorterDB.minimapPos or 225
            KeySorterDB.ilvlCache = KeySorterDB.ilvlCache or {}
            KeySorterDB.uiScale = KeySorterDB.uiScale or 1.0
            self:UnregisterEvent("ADDON_LOADED")
            KS.CreateMinimapButton()
            print("|cff00ccffKeySorter|r loaded. Type |cff00ff00/ks|r or |cff00ff00/ks help|r for commands.")
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if KS.previewMode then return end
        KS.ScanRoster()
        -- Reconcile: remove leavers, add joiners to unassigned
        if #KS.groups > 0 then
            KS.ReconcileGroups()
            if KS.UpdateGroupView then KS.UpdateGroupView() end
        end
        if KS.mainFrame and KS.mainFrame:IsShown() then
            KS.UpdatePermissionState()
        end
        -- Queue inspects for ilvl when members join
        QueueAllMembers()
    elseif event == "INSPECT_READY" then
        local guid = ...
        OnInspectReady(guid)
    end
end)

function KS.IsPermitted()
    if KS.previewMode then return true end
    if not IsInRaid() then return true end
    local raidIdx = UnitInRaid("player")
    if not raidIdx then return true end
    local _, rank = GetRaidRosterInfo(raidIdx + 1)
    return rank and rank > 0
end

function KS.UpdatePermissionState()
    if not KS.mainFrame then return end
    local permitted = KS.IsPermitted()
    if KS.sortButtonGroups then KS.sortButtonGroups:SetEnabled(permitted) end
end

local function EnsureMainFrame()
    if not KS.mainFrame then
        KS.CreateMainFrame()
    end
end

local function ToggleUI()
    EnsureMainFrame()
    if KS.mainFrame:IsShown() then
        KS.mainFrame:FadeOut()
    else
        KS.mainFrame:FadeIn()
        KS.UpdatePermissionState()
    end
end

local function PrintHelp()
    print("|cff00ccffKeySorter|r commands:")
    print("  |cff00ff00/ks|r — toggle window")
    print("  |cff00ff00/ks sort|r — sort into groups")
    print("  |cff00ff00/ks apply|r — move players to raid subgroups")
    print("  |cff00ff00/ks announce|r — post all groups to raid chat")
    print("  |cff00ff00/ks announce N|r — post group N to raid chat")
    print("  |cff00ff00/ks sync|r — force sync groups to assistants (normally automatic)")
    print("  |cff00ff00/ks preview|r — open settings (preview mode)")
    print("  |cff00ff00/ks about|r — credits & license info")
    print("  |cff00ff00/ks help|r — show this help")
end

---------------------------------------------------------------------------
-- Apply groups: move players into raid subgroups
---------------------------------------------------------------------------
function KS.ApplyGroups()
    if #KS.groups == 0 then
        print("|cff00ccffKeySorter|r: No groups to apply. Sort first.")
        return
    end
    if KS.previewMode then
        print("|cff00ccffKeySorter|r: Cannot apply in preview mode.")
        return
    end
    if not IsInRaid() then
        print("|cff00ccffKeySorter|r: Must be in a raid to apply groups.")
        return
    end
    if not KS.IsPermitted() then
        print("|cff00ccffKeySorter|r: Only raid leader/assistants can apply groups.")
        return
    end

    for groupIdx, group in ipairs(KS.groups) do
        local members = {}
        if group.tank then table.insert(members, group.tank) end
        if group.healer then table.insert(members, group.healer) end
        for _, d in ipairs(group.dps) do table.insert(members, d) end

        for _, member in ipairs(members) do
            for ri = 1, GetNumGroupMembers() do
                local raidName = GetRaidRosterInfo(ri)
                if raidName and raidName == member.name then
                    local _, _, currentGroup = GetRaidRosterInfo(ri)
                    if currentGroup ~= groupIdx then
                        SetRaidSubgroup(ri, groupIdx)
                    end
                    break
                end
            end
        end
    end

    print("|cff00ccffKeySorter|r: Groups applied to raid subgroups.")
end

---------------------------------------------------------------------------
-- Announce groups: post assignments to raid chat
---------------------------------------------------------------------------
function KS.AnnounceGroup(groupIdx)
    local group = KS.groups[groupIdx]
    if not group then return end

    if not KS.previewMode then
        if not IsInRaid() then
            print("|cff00ccffKeySorter|r: Must be in a raid to announce.")
            return
        end
        if not KS.IsPermitted() then
            print("|cff00ccffKeySorter|r: Only raid leader/assistants can announce.")
            return
        end
    end

    local function Output(msg)
        if KS.previewMode then
            print("|cff00ccff[Preview]|r " .. msg)
        else
            SendChatMessage(msg, "RAID")
        end
    end

    local names = {}
    if group.tank then table.insert(names, group.tank.name .. " (T)") end
    if group.healer then table.insert(names, group.healer.name .. " (H)") end
    for _, d in ipairs(group.dps) do table.insert(names, d.name) end
    Output(format("Group %d: %s", groupIdx, table.concat(names, ", ")))
end

SLASH_KEYSORTER1 = "/ks"
SLASH_KEYSORTER2 = "/keysorter"
SlashCmdList["KEYSORTER"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "" then
        ToggleUI()
    elseif cmd == "sort" then
        if #KS.roster == 0 then KS.ScanRoster() end
        KS.SortGroups()
        EnsureMainFrame()
        KS.mainFrame:FadeIn()
        KS.UpdatePermissionState()
    elseif cmd == "apply" then
        KS.ApplyGroups()
    elseif cmd:match("^announce") then
        local num = cmd:match("^announce%s+(%d+)$")
        if num then
            local idx = tonumber(num)
            if idx and KS.groups[idx] then
                KS.AnnounceGroup(idx)
            else
                print(format("|cff00ccffKeySorter|r: Group %s does not exist.", num))
            end
        else
            for i = 1, #KS.groups do KS.AnnounceGroup(i) end
        end
    elseif cmd == "sync" then
        KS.SendSync()
    elseif cmd == "preview" or cmd == "test" or cmd == "settings" then
        EnsureMainFrame()
        KS.mainFrame:FadeIn()
        KS.SetTab("settings")
    elseif cmd == "about" or cmd == "credits" then
        EnsureMainFrame()
        KS.mainFrame:FadeIn()
        KS.SetTab("about")
    elseif cmd == "help" then
        PrintHelp()
    else
        print(format("|cff00ccffKeySorter|r: Unknown command '%s'. Type |cff00ff00/ks help|r for usage.", cmd))
    end
end

---------------------------------------------------------------------------
-- Preview mode: generate fake raid data for UI testing
---------------------------------------------------------------------------
local PREVIEW_NAMES = {
    "Thrallmar", "Sylvanas", "Jainara", "Voljin", "Garrosh",
    "Anduin", "Tyrande", "Malfurion", "Khadgar", "Illidan",
    "Vereesa", "Liadrin", "Lorthemar", "Thalyssra", "Alleria",
    "Magni", "Moira", "Falstad", "Gelbin", "Muradin",
    "Talanji", "Bwonsamdi", "Rokhan", "Gazlowe", "Calia",
    "Rexxar", "Chromie", "Wrathion", "Ebyssian", "Kalecgos",
    "Alexstrasza", "Nozdormu", "Ysera", "Merithra", "Vyranoth",
    "Xalatath", "Dagran", "Yrel", "Turalyon", "Lothraxion",
}

local PREVIEW_CLASSES = {
    "WARRIOR", "HUNTER", "MAGE", "ROGUE", "PRIEST",
    "PALADIN", "SHAMAN", "WARLOCK", "DEATHKNIGHT", "DRUID",
    "MONK", "DEMONHUNTER", "EVOKER",
}

-- Classes that can fill each role
local PREVIEW_TANK_CLASSES = { "WARRIOR", "PALADIN", "DEATHKNIGHT", "DRUID", "MONK", "DEMONHUNTER" }
local PREVIEW_HEALER_CLASSES = { "PRIEST", "PALADIN", "SHAMAN", "DRUID", "MONK", "EVOKER" }
local PREVIEW_DPS_CLASSES = PREVIEW_CLASSES -- all classes can DPS

function KS.TogglePreview()
    KS.previewMode = not KS.previewMode

    if KS.previewMode then
        KS.GeneratePreviewData()
        print("|cff00ccffKeySorter|r: Preview mode |cff00ff00ON|r.")
    else
        wipe(KS.roster)
        wipe(KS.groups)
        wipe(KS.unassigned)
        -- Re-scan real roster if in a group
        if GetNumGroupMembers() > 0 then
            KS.ScanRoster()
        end
        print("|cff00ccffKeySorter|r: Preview mode |cffff0000OFF|r.")
    end

    if KS.UpdateRosterView then KS.UpdateRosterView() end
    if KS.UpdateGroupView then KS.UpdateGroupView() end

    if not KS.mainFrame:IsShown() then
        KS.mainFrame:FadeIn()
    end
    KS.UpdatePermissionState()
end

-- Raider.IO base score per key level (timed exactly on time)
-- Source: https://support.raider.io/kb/frequently-asked-questions/what-is-the-base-score-value-for-each-level-keystone
local KEY_BASE_SCORE = {
    [2]=155, [3]=170, [4]=200, [5]=215, [6]=230, [7]=260, [8]=275, [9]=290,
    [10]=320, [11]=335, [12]=365, [13]=380, [14]=395, [15]=410, [16]=425,
    [17]=440, [18]=455, [19]=470, [20]=485, [21]=500, [22]=515, [23]=530,
    [24]=545, [25]=560,
}

function KS.GeneratePreviewData()
    wipe(KS.roster)
    -- Don't wipe groups/unassigned here — ReconcileGroups handles
    -- adding new members and removing departed ones

    local numPlayers = KS.previewPlayerCount or 25
    local numGroups = math.floor(numPlayers / 5)
    local numTanks = math.max(numGroups, 1)
    local numHealers = math.max(numGroups, 1)
    local numDungeons = #KS.DUNGEON_IDS

    for i = 1, numPlayers do
        local role, classPool
        if i <= numTanks then
            role = "TANK"
            classPool = PREVIEW_TANK_CLASSES
        elseif i <= numTanks + numHealers then
            role = "HEALER"
            classPool = PREVIEW_HEALER_CLASSES
        else
            role = "DAMAGER"
            classPool = PREVIEW_DPS_CLASSES
        end

        local classFile = classPool[math.random(#classPool)]

        -- Pick a target key level (2-20), then derive score from it
        -- This ensures score and key level are properly correlated
        local targetKeyLevel = math.random(2, 20)

        -- Number of dungeons completed: higher key = more likely to have all 8
        local minRuns = math.max(1, math.floor(targetKeyLevel / 4))
        local numRuns = math.min(numDungeons, math.random(minRuns, numDungeons))

        -- Timed ratio: higher keys = more skilled = higher timed ratio
        local timedChance = 0.4 + (targetKeyLevel / 20) * 0.45 -- 40% at +2, 85% at +20

        local runs = {}
        local numTimed = 0
        local numUntimed = 0
        local totalKeyLevel = 0
        local totalScore = 0

        local shuffled = {}
        for _, id in ipairs(KS.DUNGEON_IDS) do table.insert(shuffled, id) end
        for j = #shuffled, 2, -1 do
            local k = math.random(1, j)
            shuffled[j], shuffled[k] = shuffled[k], shuffled[j]
        end

        for r = 1, numRuns do
            local mapID = shuffled[r]
            -- Key level varies around target (+/- 2)
            local level = targetKeyLevel + math.random(-2, 2)
            level = math.max(2, math.min(level, 25))
            totalKeyLevel = totalKeyLevel + level

            local timed = math.random() < timedChance
            if timed then numTimed = numTimed + 1 else numUntimed = numUntimed + 1 end

            -- Per-dungeon score from the base table
            local baseScore = KEY_BASE_SCORE[level] or (155 + (level - 2) * 15)
            -- Timed runs get full score, untimed lose ~30%
            local runScore = timed and baseScore or math.floor(baseScore * 0.7)
            -- Small variance for time bonus/penalty
            runScore = runScore + math.random(-10, 15)

            totalScore = totalScore + runScore
            runs[mapID] = {
                level = level,
                timed = timed,
                score = runScore,
            }
        end

        local avgKeyLevel = numRuns > 0 and (totalKeyLevel / numRuns) or 0

        -- Item level correlates with key level
        -- +2 runners: ~207-230, +10 runners: ~250-265, +15 runners: ~265-280, +20: ~275-289
        local ilvlBase = 207 + (targetKeyLevel / 20) * 70
        local ilvl = math.floor(ilvlBase + (math.random() - 0.5) * 16)
        ilvl = math.max(207, math.min(ilvl, 289))

        -- Keystone thresholds: how many keys timed at each threshold
        local k5  = math.max(0, math.floor((targetKeyLevel - 3) * 6 + math.random(-5, 10)))
        local k10 = math.max(0, math.floor((targetKeyLevel - 8) * 4 + math.random(-3, 5)))
        local k15 = math.max(0, math.floor((targetKeyLevel - 13) * 3 + math.random(-2, 3)))
        local k20 = math.max(0, math.floor((targetKeyLevel - 18) * 2 + math.random(-1, 2)))

        table.insert(KS.roster, {
            name = PREVIEW_NAMES[i] or ("Player" .. i),
            unit = "player",
            classFile = classFile,
            role = role,
            score = totalScore,
            previousScore = math.floor(totalScore * (0.4 + math.random() * 0.5)),
            runs = runs,
            avgKeyLevel = avgKeyLevel,
            numRuns = numRuns,
            numTimed = numTimed,
            numUntimed = numUntimed,
            keystoneFivePlus = k5,
            keystoneTenPlus = k10,
            keystoneFifteenPlus = k15,
            keystoneTwentyPlus = k20,
            ilvl = ilvl,
            raidIndex = i,
            hasBrez = KS.BREZ[classFile] or false,
            hasLust = KS.LUST[classFile] or false,
            hasShroud = KS.SHROUD[classFile] or false,
            utilityCount = (KS.BREZ[classFile] and 1 or 0) + (KS.LUST[classFile] and 1 or 0) + (KS.SHROUD[classFile] and 1 or 0),
            dataSource = "raiderio",
        })
    end
end
