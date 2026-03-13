local addonName, KS = ...

KS.roster = {}
KS.groups = {}
KS.unassigned = {}
KS.previewMode = false

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

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
        -- Auto-refresh roster when group composition changes
        if KS.previewMode then return end
        if KS.mainFrame and KS.mainFrame:IsShown() then
            KS.ScanRoster()
            KS.UpdatePermissionState()
        end
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
    if KS.sortButton then KS.sortButton:SetEnabled(permitted) end
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
    print("  |cff00ff00/ks sync|r — sync groups to assistants")
    print("  |cff00ff00/ks apply|r — move players to subgroups + announce")
    print("  |cff00ff00/ks preview|r — toggle preview mode (fake 25-man data)")
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
        if #KS.roster == 0 then
            KS.ScanRoster()
        end
        KS.SortGroups()
        EnsureMainFrame()
        KS.mainFrame:Show()
        KS.UpdatePermissionState()
    elseif cmd == "sync" then
        KS.SendSync()
    elseif cmd == "apply" then
        KS.ApplyGroups()
    elseif cmd == "preview" or cmd == "test" then
        KS.TogglePreview()
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
}

local PREVIEW_CLASSES = {
    "WARRIOR", "HUNTER", "MAGE", "ROGUE", "PRIEST",
    "PALADIN", "SHAMAN", "WARLOCK", "DEATHKNIGHT", "DRUID",
    "MONK", "DEMONHUNTER", "EVOKER",
}

function KS.TogglePreview()
    KS.previewMode = not KS.previewMode
    EnsureMainFrame()

    if KS.previewMode then
        KS.GeneratePreviewData()
        print("|cff00ccffKeySorter|r: Preview mode |cff00ff00ON|r — showing fake 25-player raid.")
    else
        wipe(KS.roster)
        wipe(KS.groups)
        wipe(KS.unassigned)
        print("|cff00ccffKeySorter|r: Preview mode |cffff0000OFF|r — data cleared.")
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

    local numPlayers = 25 -- enough for 5 groups
    -- Role distribution: 5 tanks, 5 healers, 15 DPS
    local roles = {}
    for i = 1, 5 do roles[i] = "TANK" end
    for i = 6, 10 do roles[i] = "HEALER" end
    for i = 11, numPlayers do roles[i] = "DAMAGER" end

    for i = 1, numPlayers do
        local classFile = PREVIEW_CLASSES[math.random(#PREVIEW_CLASSES)]
        local score = math.random(200, 3500)
        local numRuns = math.random(0, 8)
        local totalKeyLevel = 0

        local runs = {}
        for r = 1, numRuns do
            local level = math.random(2, 15)
            totalKeyLevel = totalKeyLevel + level
            runs[r * 100] = {
                level = level,
                timed = math.random() > 0.3,
                score = math.random(50, 300),
            }
        end

        local avgKeyLevel = numRuns > 0 and (totalKeyLevel / numRuns) or 0

        table.insert(KS.roster, {
            name = PREVIEW_NAMES[i] or ("Player" .. i),
            unit = "player",
            classFile = classFile,
            role = roles[i],
            score = score,
            runs = runs,
            avgKeyLevel = avgKeyLevel,
            numRuns = numRuns,
            raidIndex = i,
            hasBrez = KS.BREZ[classFile] or false,
            hasLust = KS.LUST[classFile] or false,
            hasShroud = KS.SHROUD[classFile] or false,
        })
    end
end
