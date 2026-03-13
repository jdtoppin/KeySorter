local addonName, KS = ...

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
            self:UnregisterEvent("ADDON_LOADED")
            print("|cff00ccffKeySorter|r loaded. Type |cff00ff00/ks|r to open.")
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

SLASH_KEYSORTER1 = "/ks"
SLASH_KEYSORTER2 = "/keysorter"
SlashCmdList["KEYSORTER"] = function(msg)
    if not KS.mainFrame then
        KS.CreateMainFrame()
    end
    if KS.mainFrame:IsShown() then
        KS.mainFrame:Hide()
    else
        KS.mainFrame:Show()
        KS.UpdatePermissionState()
    end
end
