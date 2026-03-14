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
            self:UnregisterEvent("ADDON_LOADED")
            KS.CreateMinimapButton()
            print("|cff00ccffKeySorter|r loaded. Type |cff00ff00/ks|r or |cff00ff00/ks help|r for commands.")
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if KS.previewMode then return end
        if KS.mainFrame and KS.mainFrame:IsShown() then
            KS.ScanRoster()
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
    local _, rank = GetRaidRosterInfo(UnitInRaid("player") + 1)
    return rank and rank > 0
end

function KS.UpdatePermissionState()
    if not KS.mainFrame then return end
    local permitted = KS.IsPermitted()
    if KS.scanButton then KS.scanButton:SetEnabled(permitted) end
    if KS.sortButtonGroups then KS.sortButtonGroups:SetEnabled(permitted) end

    if KS.announceButton then KS.announceButton:SetEnabled(permitted) end
    if KS.syncButton then KS.syncButton:SetEnabled(permitted) end
end

local function EnsureMainFrame()
    if not KS.mainFrame then
        KS.CreateMainFrame()
    end
end

local function ToggleUI()
    EnsureMainFrame()
    if KS.mainFrame:IsShown() then
        KS.mainFrame:Hide()
    else
        KS.mainFrame:Show()
        KS.UpdatePermissionState()
    end
end

local function PrintHelp()
    print("|cff00ccffKeySorter|r commands:")
    print("  |cff00ff00/ks|r — toggle window")
    print("  |cff00ff00/ks scan|r — scan raid roster")
    print("  |cff00ff00/ks sort|r — sort into groups")
    print("  |cff00ff00/ks apply|r — move players to raid subgroups")
    print("  |cff00ff00/ks announce|r — post group assignments to raid chat")
    print("  |cff00ff00/ks sync|r — sync groups to assistants")
    print("  |cff00ff00/ks preview|r — open settings (preview mode)")
    print("  |cff00ff00/ks about|r — credits & license info")
    print("  |cff00ff00/ks help|r — show this help")
end

SLASH_KEYSORTER1 = "/ks"
SLASH_KEYSORTER2 = "/keysorter"
SlashCmdList["KEYSORTER"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "" then
        ToggleUI()
    elseif cmd == "scan" then
        KS.ScanRoster()
        EnsureMainFrame()
        KS.mainFrame:Show()
        KS.UpdatePermissionState()
    elseif cmd == "sort" then
        if #KS.roster == 0 then KS.ScanRoster() end
        KS.SortGroups()
        EnsureMainFrame()
        KS.mainFrame:Show()
        KS.UpdatePermissionState()
    elseif cmd == "apply" then
        KS.ApplyGroups()
    elseif cmd == "announce" then
        KS.AnnounceGroups()
    elseif cmd == "sync" then
        KS.SendSync()
    elseif cmd == "preview" or cmd == "test" then
        EnsureMainFrame()
        KS.ToggleSettings()
    elseif cmd == "about" or cmd == "credits" then
        EnsureMainFrame()
        KS.ToggleAbout()
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

    KS.mainFrame:Show()
    KS.UpdatePermissionState()
end

function KS.GeneratePreviewData()
    wipe(KS.roster)
    wipe(KS.groups)
    wipe(KS.unassigned)

    local numPlayers = KS.previewPlayerCount or 25
    -- Role distribution: ~1 tank per 5, ~1 healer per 5, rest DPS
    local numGroups = math.floor(numPlayers / 5)
    local numTanks = math.max(numGroups, 1)
    local numHealers = math.max(numGroups, 1)

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
        local score = math.random(200, 3500)
        local numRuns = math.random(0, 8)
        local totalKeyLevel = 0

        local runs = {}
        local numTimed = 0
        local numUntimed = 0
        -- Pick random dungeons from the season pool
        local shuffled = {}
        for _, id in ipairs(KS.DUNGEON_IDS) do table.insert(shuffled, id) end
        for j = #shuffled, 2, -1 do
            local k = math.random(1, j)
            shuffled[j], shuffled[k] = shuffled[k], shuffled[j]
        end
        for r = 1, numRuns do
            local mapID = shuffled[r] or (r * 100)
            local level = math.random(2, 15)
            totalKeyLevel = totalKeyLevel + level
            local timed = math.random() > 0.3
            if timed then numTimed = numTimed + 1 else numUntimed = numUntimed + 1 end
            runs[mapID] = {
                level = level,
                timed = timed,
                score = math.random(50, 300),
            }
        end

        table.insert(KS.roster, {
            name = PREVIEW_NAMES[i] or ("Player" .. i),
            unit = "player",
            classFile = classFile,
            role = role,
            score = score,
            previousScore = math.random(0, score),
            runs = runs,
            avgKeyLevel = numRuns > 0 and (totalKeyLevel / numRuns) or 0,
            numRuns = numRuns,
            numTimed = numTimed,
            numUntimed = numUntimed,
            keystoneFivePlus = math.random(0, 80),
            keystoneTenPlus = math.random(0, 40),
            keystoneFifteenPlus = math.random(0, 15),
            keystoneTwentyPlus = math.random(0, 5),
            ilvl = math.random(207, 289),
            raidIndex = i,
            hasBrez = KS.BREZ[classFile] or false,
            hasLust = KS.LUST[classFile] or false,
            hasShroud = KS.SHROUD[classFile] or false,
            dataSource = "raiderio",
        })
    end
end
