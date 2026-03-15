local addonName, KS = ...

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500
local TOOLBAR_H = 30

function KS.CreateMainFrame()
    local f = CreateFrame("Frame", "KeySorterMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    local p = KeySorterDB.point
    f:SetPoint(p[1], UIParent, p[3], p[4], p[5])

    f:SetBackdrop(KS.BACKDROP)
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    ---------------------------------------------------------------------------
    -- Sidebar
    ---------------------------------------------------------------------------
    local sidebar = KS.CreateSidebar(f)

    -- Register sidebar action buttons
    KS.SidebarActions = {
        gather = function()
            if KS.previewMode then
                print("|cff00ccff[Preview]|r Please gather at Silvermoon by the Weekly Vendors for group sorting!")
            elseif IsInRaid() and KS.IsPermitted() then
                SendChatMessage("Please gather at Silvermoon by the Weekly Vendors for group sorting!", "RAID")
                print("|cff00ccffKeySorter|r: Gather announcement sent.")
            elseif IsInRaid() then
                print("|cff00ccffKeySorter|r: Only raid leader/assistants can send gather announcements.")
            else
                print("|cff00ccffKeySorter|r: Must be in a raid to send gather announcements.")
            end
        end,
    }

    ---------------------------------------------------------------------------
    -- Content area (fills space to the right of sidebar)
    ---------------------------------------------------------------------------
    local contentArea = CreateFrame("Frame", nil, f)
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    contentArea:SetPoint("BOTTOMRIGHT", -1, 1)
    contentArea:SetClipsChildren(true)  -- clip content that overflows when window is narrow
    KS.contentArea = contentArea

    ---------------------------------------------------------------------------
    -- Close button (top-right of main frame)
    ---------------------------------------------------------------------------
    local close = KS.CreateCloseButton(f)
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetFrameLevel(contentArea:GetFrameLevel() + 20)
    close:SetOnClick(function() f:FadeOut() end)

    ---------------------------------------------------------------------------
    -- Content panels (all share the content area)
    ---------------------------------------------------------------------------
    local tabContents = {}

    -- Roster content (toolbar shares row with close button, so no top padding needed)
    local rosterContent = CreateFrame("Frame", nil, contentArea)
    rosterContent:SetPoint("TOPLEFT", 8, -4)
    rosterContent:SetPoint("BOTTOMRIGHT", -8, 8)
    rosterContent:Hide()
    tabContents["roster"] = rosterContent

    -- Groups content (toolbar shares row with close button)
    local groupsWrapper = CreateFrame("Frame", nil, contentArea)
    groupsWrapper:SetPoint("TOPLEFT", 0, 0)
    groupsWrapper:SetPoint("BOTTOMRIGHT", 0, 0)
    groupsWrapper:Hide()
    tabContents["groups"] = groupsWrapper

    -- Groups toolbar (top row, same level as close button)
    local groupsToolbar = CreateFrame("Frame", nil, groupsWrapper)
    groupsToolbar:SetPoint("TOPLEFT", 4, -4)
    groupsToolbar:SetPoint("TOPRIGHT", -30, -4)
    groupsToolbar:SetHeight(TOOLBAR_H)

    -- Groups content below toolbar
    local groupContent = CreateFrame("Frame", nil, groupsWrapper)
    groupContent:SetPoint("TOPLEFT", 8, -(TOOLBAR_H + 6))
    groupContent:SetPoint("BOTTOMRIGHT", -8, 8)

    -- Settings content
    local settingsContent = CreateFrame("Frame", nil, contentArea)
    settingsContent:SetPoint("TOPLEFT", 0, -4)
    settingsContent:SetPoint("BOTTOMRIGHT", 0, 0)
    settingsContent:Hide()
    tabContents["settings"] = settingsContent

    -- About content
    local aboutContent = CreateFrame("Frame", nil, contentArea)
    aboutContent:SetPoint("TOPLEFT", 8, -4)
    aboutContent:SetPoint("BOTTOMRIGHT", -8, 8)
    aboutContent:Hide()
    tabContents["about"] = aboutContent

    ---------------------------------------------------------------------------
    -- Groups toolbar controls: Sort, Switch
    ---------------------------------------------------------------------------
    local sortBtnGroups = KS.CreateButton(groupsToolbar, "Sort", "accent", 52, 22)
    sortBtnGroups:SetPoint("LEFT", 6, 0)
    sortBtnGroups:SetAnimatedHighlight(true)
    sortBtnGroups:SetBorderHighlightColor(0, 0.8, 1, 1)
    sortBtnGroups:SetTextHighlightColor(1, 1, 1)
    sortBtnGroups:SetOnClick(function()
        if not KS.previewMode and #KS.roster == 0 then KS.ScanRoster() end
        if #KS.roster > 0 then
            KS.SortGroups()
            if not KS.previewMode then KS.ApplyGroups() end
            if KS.UpdateGroupView then KS.UpdateGroupView() end
        end
    end)
    KS.sortButtonGroups = sortBtnGroups
    KS.SetTooltip(sortBtnGroups, "ANCHOR_BOTTOM", {"Sort Groups", "Sort players using the selected mode and move them into raid subgroups.", "1 tank, 1 healer, 3 DPS per group. BR/BL balanced where possible."})

    local switchOptions = {}
    for _, mode in ipairs(KS.SORT_MODES) do
        table.insert(switchOptions, { text = mode.label, value = mode.key })
    end
    local sortSwitch = KS.CreateSwitch(groupsToolbar, 240, 22, switchOptions)
    sortSwitch:SetPoint("LEFT", sortBtnGroups, "RIGHT", 8, 0)
    sortSwitch:SetSelectedValue(KS.sortMode)
    sortSwitch:SetOnSelect(function(value)
        KS.sortMode = value
        -- Re-sort immediately with the new mode
        if #KS.roster > 0 then
            KS.SortGroups()
            if not KS.previewMode then KS.ApplyGroups() end
            if KS.UpdateGroupView then KS.UpdateGroupView() end
        end
    end)
    KS.SetTooltip(sortSwitch, "ANCHOR_BOTTOM", {"Sort Mode", "Click to toggle sort algorithm."})

    ---------------------------------------------------------------------------
    -- Tab switching
    ---------------------------------------------------------------------------
    local aboutCreated = false
    local settingsCreated = false

    local function SetTabInternal(tab)
        for name, content in pairs(tabContents) do
            if name == tab then content:Show() else content:Hide() end
        end
        sidebar:SelectButton(tab)

        -- Lazy-create About and Settings after frame is shown (needs actual width for text wrap)
        if tab == "about" and not aboutCreated then
            aboutCreated = true
            C_Timer.After(0, function()
                KS.CreateAboutView(aboutContent)
            end)
        elseif tab == "settings" and not settingsCreated then
            settingsCreated = true
            C_Timer.After(0, function()
                KS.CreateSettingsView(settingsContent)
            end)
        end

        if tab == "groups" then
            -- Auto-sort if no groups exist yet
            if #KS.groups == 0 then
                if not KS.previewMode and #KS.roster == 0 then
                    KS.ScanRoster()
                end
                if #KS.roster > 0 then
                    KS.SortGroups()
                    if not KS.previewMode then KS.ApplyGroups() end
                end
            end
            -- Always re-render groups view (data may have changed on another tab)
            if KS.UpdateGroupView then KS.UpdateGroupView() end
        end
    end
    KS.SetTab = SetTabInternal

    ---------------------------------------------------------------------------
    -- Store references and build views
    ---------------------------------------------------------------------------
    KS.mainFrame = f
    KS.rosterContent = rosterContent
    KS.groupContent = groupContent
    KS.aboutContent = aboutContent
    KS.settingsContent = settingsContent

    KS.CreateRosterView(rosterContent)
    KS.CreateGroupView(groupContent)
    -- About and Settings are lazy-loaded on first tab visit
    -- (text wrapping needs actual frame width, which is 0 at init)

    -- Resize handle
    f:SetResizable(true)
    f:SetResizeBounds(540, 350, 1000, 800)

    local resizer = KS.CreateResizeButton(f)
    resizer:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
    end)

    -- Fade animations (OnUpdate-based, avoids AnimationGroup alpha quirks)
    local FADE_IN_DURATION = 0.15
    local FADE_OUT_DURATION = 0.12
    local fadeElapsed = 0
    local fadeDirection = nil  -- "in", "out", or nil

    local function StopFade()
        fadeDirection = nil
        f:SetScript("OnUpdate", nil)
    end

    local function FadeOnUpdate(self, dt)
        fadeElapsed = fadeElapsed + dt
        if fadeDirection == "in" then
            local t = math.min(fadeElapsed / FADE_IN_DURATION, 1)
            self:SetAlpha(t)
            if t >= 1 then StopFade() end
        elseif fadeDirection == "out" then
            local t = math.min(fadeElapsed / FADE_OUT_DURATION, 1)
            self:SetAlpha(1 - t)
            if t >= 1 then
                StopFade()
                self:Hide()
                self:SetAlpha(1)
            end
        end
    end

    function f:FadeIn()
        StopFade()
        self:SetAlpha(0)
        self:Show()
        fadeElapsed = 0
        fadeDirection = "in"
        self:SetScript("OnUpdate", FadeOnUpdate)
    end
    function f:FadeOut()
        if fadeDirection == "out" then return end
        StopFade()
        fadeElapsed = 0
        fadeDirection = "out"
        self:SetScript("OnUpdate", FadeOnUpdate)
    end

    -- Auto-scan on first show
    f:SetScript("OnShow", function()
        if not KS.previewMode and #KS.roster == 0 then
            KS.ScanRoster()
        end
        KS.UpdatePermissionState()
    end)

    -- Apply saved UI scale
    if KeySorterDB and KeySorterDB.uiScale then
        f:SetScale(KeySorterDB.uiScale)
    end

    SetTabInternal("roster")

    -- Handle ESC to close (don't use UISpecialFrames — it conflicts with fade animations)
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(true)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" and self:IsShown() then
            self:SetPropagateKeyboardInput(false)
            self:FadeOut()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    f:Hide()
end
