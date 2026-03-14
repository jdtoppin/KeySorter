local addonName, KS = ...

local settingsFrame

function KS.ToggleSettings()
    if not settingsFrame then
        KS.CreateSettingsFrame()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

function KS.CreateSettingsFrame()
    settingsFrame = CreateFrame("Frame", "KeySorterSettingsFrame", UIParent, "BackdropTemplate")
    settingsFrame:SetSize(360, 480)
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetMovable(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:SetClampedToScreen(true)
    settingsFrame:SetPoint("CENTER")

    settingsFrame:SetBackdrop(KS.BACKDROP_PANEL)
    settingsFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    settingsFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    settingsFrame:RegisterForDrag("LeftButton")
    settingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    settingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Close
    local close = KS.CreateButton(settingsFrame, "X", "red", 20, 20)
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetOnClick(function() settingsFrame:Hide() end)

    -- Title
    local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("Settings")
    title:SetTextColor(0, 0.8, 1)

    local y = -44

    ---------------------------------------------------------------------------
    -- Coming soon placeholder items
    ---------------------------------------------------------------------------
    local function AddSettingLabel(text, r, g, b, font)
        local fs = settingsFrame:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetPoint("TOPRIGHT", -16, y)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        if r then fs:SetTextColor(r, g, b) end
        y = y - (fs:GetStringHeight() + 8)
        return fs
    end

    local function AddSettingRow(label, status)
        local row = CreateFrame("Frame", nil, settingsFrame)
        row:SetPoint("TOPLEFT", 16, y)
        row:SetPoint("TOPRIGHT", -16, y)
        row:SetHeight(24)

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", 0, 0)
        lbl:SetText(label)
        lbl:SetTextColor(0.8, 0.8, 0.8)

        local tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tag:SetPoint("RIGHT", 0, 0)
        tag:SetText(status)
        tag:SetTextColor(0.4, 0.4, 0.4)

        y = y - 28
        return row
    end

    ---------------------------------------------------------------------------
    -- Preview Mode
    ---------------------------------------------------------------------------
    AddSettingLabel("Preview Mode", 0, 0.8, 1, "GameFontNormal")

    local previewDesc = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewDesc:SetPoint("TOPLEFT", 16, y)
    previewDesc:SetPoint("TOPRIGHT", -16, y)
    previewDesc:SetJustifyH("LEFT")
    previewDesc:SetText("Generate fake raid data to test the UI without a group.")
    previewDesc:SetTextColor(0.6, 0.6, 0.6)
    y = y - 20

    local previewStatus = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewStatus:SetPoint("TOPLEFT", 16, y)
    previewStatus:SetText(KS.previewMode and "|cff00ff00ON|r" or "|cffff0000OFF|r")

    local toggleBtn = KS.CreateButton(settingsFrame, KS.previewMode and "Disable" or "Enable", "accent", 70, 22)
    toggleBtn:SetPoint("LEFT", previewStatus, "RIGHT", 12, 0)
    toggleBtn:SetOnClick(function()
        KS.TogglePreview()
        if KS.previewMode then
            previewStatus:SetText("|cff00ff00ON|r")
            toggleBtn:SetText("Disable")
        else
            previewStatus:SetText("|cffff0000OFF|r")
            toggleBtn:SetText("Enable")
        end
    end)
    y = y - 30

    -- Player count slider
    local countSlider = KS.CreateSlider(settingsFrame, "Player Count", 5, 40, 5, 200)
    countSlider:SetPoint("TOPLEFT", 16, y)
    countSlider:SetValue(KS.previewPlayerCount or 25)
    countSlider:SetOnChange(function(val)
        KS.previewPlayerCount = val
        if KS.previewMode then
            KS.GeneratePreviewData()
            if KS.UpdateRosterView then KS.UpdateRosterView() end
            if KS.UpdateGroupView then KS.UpdateGroupView() end
        end
    end)
    y = y - 48

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    AddSettingLabel("General", 0, 0.8, 1, "GameFontNormal")
    AddSettingRow("Season Dungeon Pool", "|cff666666Coming Soon|r")
    AddSettingRow("Font", "|cff666666Coming Soon|r")
    AddSettingRow("Font Size", "|cff666666Coming Soon|r")

    y = y - 8
    AddSettingLabel("Data", 0, 0.8, 1, "GameFontNormal")
    AddSettingRow("Data Source Priority", "|cff666666Coming Soon|r")
    AddSettingRow("Export to Spreadsheet", "|cff666666Coming Soon|r")

    y = y - 8
    AddSettingLabel("Sorting", 0, 0.8, 1, "GameFontNormal")
    AddSettingRow("Swap Threshold", "|cff666666Coming Soon|r")
    AddSettingRow("Group Size", "|cff666666Coming Soon|r")

    table.insert(UISpecialFrames, "KeySorterSettingsFrame")
    settingsFrame:Hide()
end
