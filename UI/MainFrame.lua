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

    -- Make the entire frame draggable
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        KeySorterDB.point = { point, nil, relPoint, x, y }
    end)

    ---------------------------------------------------------------------------
    -- Sidebar
    ---------------------------------------------------------------------------
    local sidebar = KS.CreateSidebar(f)

    -- Register sidebar action buttons
    KS.SidebarActions = {
        welcome = function()
            local msg = KeySorterDB.welcomeMsg or "Welcome to M+ night!"
            if KS.previewMode then
                print("|cff00ccff[Preview]|r " .. msg)
            elseif IsInRaid() and KS.IsPermitted() then
                SendChatMessage(msg, "RAID")
                print("|cff00ccffKeySorter|r: Welcome message sent.")
            elseif IsInRaid() then
                print("|cff00ccffKeySorter|r: Only raid leader/assistants can send announcements.")
            else
                print("|cff00ccffKeySorter|r: Must be in a raid to send announcements.")
            end
        end,
        gather = function()
            local msg = KeySorterDB.gatherMsg or "Please gather at Silvermoon by the Weekly Vendors for group sorting!"
            if KS.previewMode then
                print("|cff00ccff[Preview]|r " .. msg)
            elseif IsInRaid() and KS.IsPermitted() then
                SendChatMessage(msg, "RAID")
                print("|cff00ccffKeySorter|r: Gather announcement sent.")
            elseif IsInRaid() then
                print("|cff00ccffKeySorter|r: Only raid leader/assistants can send announcements.")
            else
                print("|cff00ccffKeySorter|r: Must be in a raid to send announcements.")
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
    settingsContent:SetPoint("TOPLEFT", 8, -4)
    settingsContent:SetPoint("BOTTOMRIGHT", -8, 8)
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
        if not KS.previewMode and #KS.roster == 0 then
            KS.ScanRoster()
        end
        if #KS.roster == 0 then
            print("|cff00ccffKeySorter|r: No roster data. Make sure you're in a group.")
            return
        end
        KS.SortGroups()
        if not KS.previewMode and KS.IsPermitted() then
            KS.ApplyGroups()
        end
        if KS.UpdateGroupView then KS.UpdateGroupView() end
        if KS.UpdateSortGlow then KS.UpdateSortGlow() end
    end)
    KS.sortButtonGroups = sortBtnGroups
    KS.SetTooltip(sortBtnGroups, "ANCHOR_BOTTOM", {"Sort Groups", "Sort players using the selected mode and move them into raid subgroups.", "1 tank, 1 healer, 3 DPS per group. BR/BL balanced where possible."})

    -- Pulsing glow on sort button when unassigned players exist
    local sortGlow = sortBtnGroups:CreateTexture(nil, "BACKGROUND")
    sortGlow:SetPoint("TOPLEFT", -3, 3)
    sortGlow:SetPoint("BOTTOMRIGHT", 3, -3)
    sortGlow:SetColorTexture(0, 0.8, 1, 0)
    sortGlow:Hide()
    local glowElapsed = 0
    local glowActive = false

    -- Use a separate child frame for glow animation to avoid OnUpdate conflict
    -- with the button's AnimateButtonHighlight
    local glowFrame = CreateFrame("Frame", nil, sortBtnGroups)

    function KS.UpdateSortGlow()
        -- Glow when there are unassigned players OR when roster has players but no groups yet
        if #KS.unassigned > 0 or (#KS.roster > 0 and #KS.groups == 0) then
            if not glowActive then
                glowActive = true
                sortGlow:Show()
                glowElapsed = 0
                glowFrame:SetScript("OnUpdate", function(self, dt)
                    if not glowActive then return end
                    glowElapsed = glowElapsed + dt
                    -- Pulse alpha between 0.1 and 0.4
                    local alpha = 0.25 + 0.15 * math.sin(glowElapsed * 3)
                    sortGlow:SetVertexColor(0, 0.8, 1, alpha)
                end)
            end
        else
            if glowActive then
                glowActive = false
                sortGlow:Hide()
                glowFrame:SetScript("OnUpdate", nil)
            end
        end
    end

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
            -- Auto-sort if no groups or incomplete groups exist yet
            local hasAnyGroups = #KS.groups > 0 or (#KS.incompleteGroups and #KS.incompleteGroups > 0)
            if not hasAnyGroups then
                if not KS.previewMode and #KS.roster == 0 then
                    KS.ScanRoster()
                end
                if #KS.roster > 0 then
                    KS.SortGroups()
                    if not KS.previewMode and KS.IsPermitted() then
                        KS.ApplyGroups()
                    end
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
