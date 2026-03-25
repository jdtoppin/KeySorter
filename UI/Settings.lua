local addonName, KS = ...

function KS.CreateSettingsView(parent)
    local scrollFrame, scrollChild = KS.CreateScrollFrame(parent, "KeySorterSettingsScroll")

    local y = -8

    local function AddSettingLabel(text, r, g, b, font)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetPoint("TOPRIGHT", -16, y)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        if r then fs:SetTextColor(r, g, b) end
        y = y - (fs:GetStringHeight() + 8)
        return fs
    end

    local function AddSettingRow(label, status)
        local row = CreateFrame("Frame", nil, scrollChild)
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

    -- Title
    local title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText("Settings")
    title:SetTextColor(0, 0.8, 1)
    y = y - 28

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    AddSettingLabel("General", 0, 0.8, 1, "GameFontNormal")

    local scaleSlider = KS.CreateSlider(scrollChild, "UI Scale", 0.2, 1.5, 0.01, 200)
    scaleSlider:SetPoint("TOPLEFT", 16, y)
    scaleSlider:SetFormat(function(v) return string.format("%.2f", v) end)
    scaleSlider:SetValue(KeySorterDB.uiScale or 1.0)
    scaleSlider:SetOnChange(function(val)
        KeySorterDB.uiScale = val
    end)
    scaleSlider:SetOnRelease(function(val)
        if KS.ApplyUIScale then
            KS.ApplyUIScale(val)
        end
    end)
    y = y - 48

    ---------------------------------------------------------------------------
    -- Announcements
    ---------------------------------------------------------------------------
    AddSettingLabel("Announcements", 0, 0.8, 1, "GameFontNormal")

    local function CreateMessageEditor(labelText, dbKey, yStart)
        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", 16, yStart)
        lbl:SetText(labelText)
        lbl:SetTextColor(0.7, 0.7, 0.7)
        yStart = yStart - 16

        local container = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        container:SetPoint("TOPLEFT", 16, yStart)
        container:SetPoint("TOPRIGHT", -16, yStart)
        container:SetHeight(50)
        container:SetBackdrop(KS.BACKDROP)
        container:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        container:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

        local sf = CreateFrame("ScrollFrame", nil, container)
        sf:SetPoint("TOPLEFT", 6, -4)
        sf:SetPoint("BOTTOMRIGHT", -6, 4)

        local box = CreateFrame("EditBox", nil, sf)
        C_Timer.After(0, function()
            local containerWidth = container:GetWidth()
            if containerWidth > 24 then
                box:SetWidth(containerWidth - 24)
            else
                box:SetWidth(280)
            end
        end)
        box:SetFontObject("GameFontHighlightSmall")
        box:SetAutoFocus(false)
        box:SetMultiLine(true)
        box:SetText(KeySorterDB[dbKey] or "")
        sf:SetScrollChild(box)

        local function UpdateHeight()
            local textHeight = box:GetHeight()
            if textHeight < 1 then textHeight = 50 end
            local h = math.max(50, math.min(textHeight + 12, 120))
            container:SetHeight(h)
        end

        box:SetScript("OnTextChanged", function(self)
            local numLines = select(2, self:GetText():gsub("\n", "\n")) + 1
            local lineHeight = select(2, self:GetFont()) or 12
            self:SetHeight(math.max(numLines * (lineHeight + 2), 40))
            UpdateHeight()
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(KeySorterDB[dbKey] or "")
            self:ClearFocus()
            UpdateHeight()
        end)

        C_Timer.After(0, function()
            local text = box:GetText()
            if text and #text > 0 then
                box:SetText(text)
            end
            UpdateHeight()
        end)

        return box, yStart - 58
    end

    local welcomeBox, yAfterWelcome = CreateMessageEditor("Welcome Message", "welcomeMsg", y)
    y = yAfterWelcome
    local gatherBox, yAfterGather = CreateMessageEditor("Gather Message", "gatherMsg", y)
    y = yAfterGather

    local saveStatus = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    saveStatus:SetTextColor(0, 0.8, 0)

    local saveBtn = KS.CreateButton(scrollChild, "Save Messages", "accent", 100, 22)
    saveBtn:SetAnimatedHighlight(true)
    saveBtn:SetPoint("TOPLEFT", 16, y)
    saveBtn:SetOnClick(function()
        KeySorterDB.welcomeMsg = welcomeBox:GetText()
        KeySorterDB.gatherMsg = gatherBox:GetText()
        welcomeBox:ClearFocus()
        gatherBox:ClearFocus()
        saveStatus:SetText("|cff00ff00Saved!|r")
        C_Timer.After(2, function()
            saveStatus:SetText("")
        end)
    end)
    saveStatus:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    y = y - 30

    ---------------------------------------------------------------------------
    -- Preview Mode
    ---------------------------------------------------------------------------
    AddSettingLabel("Preview Mode", 0, 0.8, 1, "GameFontNormal")

    local previewDesc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewDesc:SetPoint("TOPLEFT", 16, y)
    previewDesc:SetPoint("TOPRIGHT", -16, y)
    previewDesc:SetJustifyH("LEFT")
    previewDesc:SetText("Generate fake raid data to test the UI without a group.")
    previewDesc:SetTextColor(0.6, 0.6, 0.6)
    y = y - 20

    local previewStatus = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewStatus:SetPoint("TOPLEFT", 16, y)
    previewStatus:SetText(KS.previewMode and "|cff00ff00ON|r" or "|cffff0000OFF|r")

    local toggleBtn = KS.CreateButton(scrollChild, KS.previewMode and "Disable" or "Enable", "accent", 70, 22)
    toggleBtn:SetAnimatedHighlight(true)
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

    local countSlider = KS.CreateSlider(scrollChild, "Player Count", 1, 40, 1, 200)
    countSlider:SetPoint("TOPLEFT", 16, y)
    countSlider:SetValue(KS.previewPlayerCount or 25)
    countSlider:SetOnChange(function(val)
        KS.previewPlayerCount = val
        if KS.previewMode then
            KS.GeneratePreviewData()
            KS.ReconcileGroups()
            if KS.UpdateRosterView then KS.UpdateRosterView() end
            if KS.UpdateGroupView then KS.UpdateGroupView() end
            if KS.UpdateSortGlow then KS.UpdateSortGlow() end
            if KS.UpdateSidebarNotification then KS.UpdateSidebarNotification() end
        end
    end)
    y = y - 48

    ---------------------------------------------------------------------------
    -- Live Simulation
    ---------------------------------------------------------------------------
    AddSettingLabel("Live Simulation", 0, 0.8, 1, "GameFontNormal")

    local simDesc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    simDesc:SetPoint("TOPLEFT", 16, y)
    simDesc:SetPoint("TOPRIGHT", -16, y)
    simDesc:SetJustifyH("LEFT")
    simDesc:SetText("Simulate players gradually joining a raid. Shows how groups form in real time.")
    simDesc:SetTextColor(0.6, 0.6, 0.6)
    y = y - 20

    local simBtn = KS.CreateButton(scrollChild, "Start Simulation", "accent", 110, 22)
    simBtn:SetAnimatedHighlight(true)
    simBtn:SetPoint("TOPLEFT", 16, y)

    local simStatus = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    simStatus:SetPoint("LEFT", simBtn, "RIGHT", 12, 0)
    simStatus:SetText("")
    simStatus:SetTextColor(0.7, 0.7, 0.7)
    y = y - 30

    local simTargetSlider = KS.CreateSlider(scrollChild, "Target Players", 5, 40, 1, 200)
    simTargetSlider:SetPoint("TOPLEFT", 16, y)
    simTargetSlider:SetValue(KS.simTarget or 25)
    simTargetSlider:SetOnChange(function(val)
        KS.simTarget = val
    end)
    KS.simTarget = KS.simTarget or 25
    y = y - 48

    local simSpeedSlider = KS.CreateSlider(scrollChild, "Join Interval (sec)", 1, 10, 1, 200)
    simSpeedSlider:SetPoint("TOPLEFT", 16, y)
    simSpeedSlider:SetValue(KS.simSpeed or 3)
    simSpeedSlider:SetOnChange(function(val)
        KS.simSpeed = val
    end)
    KS.simSpeed = KS.simSpeed or 3

    local simTimer = nil
    local simCount = 0

    local function StopSimulation()
        if simTimer then
            simTimer:Cancel()
            simTimer = nil
        end
        simBtn:SetText("Start Simulation")
        simStatus:SetText(format("|cff888888Stopped at %d players|r", simCount))
    end

    local function SimulationTick()
        if simCount >= (KS.simTarget or 25) then
            StopSimulation()
            simStatus:SetText(format("|cff00ff00Simulation complete — %d players|r", simCount))
            return
        end

        -- Add 1-2 players per tick
        local toAdd = (math.random() > 0.6) and 2 or 1
        simCount = math.min(simCount + toAdd, KS.simTarget or 25)
        KS.previewPlayerCount = simCount
        KS.GeneratePreviewData()

        KS.ReconcileGroups()

        if KS.UpdateRosterView then KS.UpdateRosterView() end
        if KS.UpdateGroupView then KS.UpdateGroupView() end
        if KS.UpdateSortGlow then KS.UpdateSortGlow() end
        if KS.UpdateSidebarNotification then KS.UpdateSidebarNotification() end

        simStatus:SetText(format("|cff00ccff%d / %d players joined|r", simCount, KS.simTarget or 25))

        -- Update the player count slider to match
        countSlider:SetValue(simCount)
    end

    local function StartSimulation()
        -- Enable preview mode if not already
        if not KS.previewMode then
            KS.TogglePreview()
            previewStatus:SetText("|cff00ff00ON|r")
            toggleBtn:SetText("Disable")
        end

        -- Reset
        simCount = 0
        KS.previewPlayerCount = 0
        wipe(KS.roster)
        wipe(KS.groups)
        wipe(KS.incompleteGroups)
        wipe(KS.unassigned)
        if KS.UpdateRosterView then KS.UpdateRosterView() end
        if KS.UpdateGroupView then KS.UpdateGroupView() end

        simBtn:SetText("Stop")
        simStatus:SetText("|cff00ccffSimulation starting...|r")

        -- Start ticking
        simTimer = C_Timer.NewTicker(KS.simSpeed or 3, SimulationTick)
    end

    simBtn:SetOnClick(function()
        if simTimer then
            StopSimulation()
        else
            StartSimulation()
        end
    end)

    y = y - 48

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

    y = y - 8
    AddSettingLabel("Character History", 0, 0.8, 1, "GameFontNormal")

    local charCount = 0
    if KeySorterDB and KeySorterDB.knownChars then
        for _ in pairs(KeySorterDB.knownChars) do charCount = charCount + 1 end
    end
    local scoreCount = 0
    if KeySorterDB and KeySorterDB.seasonScores then
        for _ in pairs(KeySorterDB.seasonScores) do scoreCount = scoreCount + 1 end
    end
    AddSettingLabel(format("  %d characters tracked, %d with season scores", charCount, scoreCount), 0.6, 0.6, 0.6, "GameFontHighlightSmall")

    local clearBtn = KS.CreateButton(scrollChild, "Clear All History", "red", 120, 22)
    clearBtn:SetAnimatedHighlight(true)
    clearBtn:SetBorderHighlightColor(0.7, 0.15, 0.15, 1)
    clearBtn:SetPoint("TOPLEFT", 16, y)
    clearBtn:SetOnClick(function()
        KS.ShowConfirmDialog(
            "Are you sure you want to clear all character history?\n\nThis will delete all tracked characters, season scores, notes, and alt links. This cannot be undone.",
            function()
                wipe(KeySorterDB.knownChars)
                wipe(KeySorterDB.seasonScores)
                wipe(KeySorterDB.notes)
                wipe(KeySorterDB.alts)
                wipe(KeySorterDB.ilvlCache)
                print("|cff00ccffKeySorter|r: Character history cleared.")
            end
        )
    end)
    y = y - 30

    scrollChild:SetHeight(math.abs(y) + 16)
end
