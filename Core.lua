local addonName, KS = ...

---@type AbstractFramework
local AF = _G.AbstractFramework

KS.AF = AF
KS.roster = {}
KS.groups = {}
KS.unassigned = {}

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
        if KS.mainFrame and KS.mainFrame:IsShown() then
            KS.UpdatePermissionState()
        end
    end
end)

function KS.IsPermitted()
    if not IsInRaid() then return true end -- allow in party/solo for testing
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
    elseif cmd == "about" or cmd == "credits" then
        EnsureMainFrame()
        KS.ToggleAbout()
    elseif cmd == "help" then
        PrintHelp()
    else
        print(format("|cff00ccffKeySorter|r: Unknown command '%s'. Type |cff00ff00/ks help|r for usage.", cmd))
    end
end
