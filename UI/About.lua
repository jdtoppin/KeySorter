local addonName, KS = ...

local aboutFrame

function KS.ToggleAbout()
    if not aboutFrame then
        KS.CreateAboutFrame()
    end
    if aboutFrame:IsShown() then
        aboutFrame:Hide()
    else
        aboutFrame:Show()
    end
end

function KS.CreateAboutFrame()
    aboutFrame = CreateFrame("Frame", "KeySorterAboutFrame", UIParent, "BackdropTemplate")
    aboutFrame:SetSize(360, 260)
    aboutFrame:SetFrameStrata("DIALOG")
    aboutFrame:SetMovable(true)
    aboutFrame:EnableMouse(true)
    aboutFrame:SetClampedToScreen(true)
    aboutFrame:SetPoint("CENTER")

    aboutFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    aboutFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    aboutFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    aboutFrame:RegisterForDrag("LeftButton")
    aboutFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    aboutFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Close
    local close = KS.CreateButton(aboutFrame, "X", "red", 24, 24)
    close:SetPoint("TOPRIGHT", -6, -4)
    close:SetOnClick(function() aboutFrame:Hide() end)

    -- Title
    local title = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("KeySorter")
    title:SetTextColor(0, 0.8, 1)

    local version = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)
    version:SetText("v1.0.0")
    version:SetTextColor(0.6, 0.6, 0.6)

    -- Content
    local y = -40
    local function AddLine(text, r, g, b, font)
        local fs = aboutFrame:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetPoint("TOPRIGHT", -16, y)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        if r then fs:SetTextColor(r, g, b) end
        y = y - (fs:GetStringHeight() + 6)
        return fs
    end

    AddLine("Automatically sort raid members into balanced M+ groups.", 0.8, 0.8, 0.8)
    y = y - 4

    AddLine("Author", 0, 0.8, 1, "GameFontNormal")
    AddLine("Josiah Toppin", 0.9, 0.9, 0.9)
    y = y - 4

    AddLine("License", 0, 0.8, 1, "GameFontNormal")
    AddLine("GNU General Public License v3.0", 0.9, 0.9, 0.9)
    y = y - 4

    AddLine("Commands", 0, 0.8, 1, "GameFontNormal")
    AddLine("|cff00ff00/ks|r  Toggle window\n|cff00ff00/ks scan|r  Scan raid roster\n|cff00ff00/ks sort|r  Sort into groups\n|cff00ff00/ks sync|r  Sync to assistants\n|cff00ff00/ks about|r  This window", 0.9, 0.9, 0.9)

    table.insert(UISpecialFrames, "KeySorterAboutFrame")
    aboutFrame:Hide()
end
