local addonName, KS = ...

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500
local MAX_FRAME_WIDTH = 1000
local MAX_FRAME_HEIGHT = 800
local TOOLBAR_H = 30

function KS.CreateMainFrame()
    local f = CreateFrame("Frame", "KeySorterMainFrame", UIParent, "BackdropTemplate")
    local w = math.min(KeySorterDB.frameWidth or FRAME_WIDTH, MAX_FRAME_WIDTH)
    local h = math.min(KeySorterDB.frameHeight or FRAME_HEIGHT, MAX_FRAME_HEIGHT)
    f:SetSize(w, h)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    local p = KeySorterDB.point
    f:SetPoint(p[1], p[2] or UIParent, p[3], p[4], p[5])

    f:SetBackdrop(KS.BACKDROP)
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Make the entire frame draggable
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        KeySorterDB.point = { point, "UIParent", relPoint, x, y }
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

    -- Players content (historical character database)
    local playersContent = CreateFrame("Frame", nil, contentArea)
    playersContent:SetPoint("TOPLEFT", 8, -4)
    playersContent:SetPoint("BOTTOMRIGHT", -8, 8)
    playersContent:Hide()
    tabContents["players"] = playersContent

    ---------------------------------------------------------------------------
    -- Groups toolbar controls: Sort, Switch
    ---------------------------------------------------------------------------
    -- Sort All: re-sorts everyone not in a locked group
    local sortAllBtn = KS.CreateButton(groupsToolbar, "Sort All", "accent", 58, 22)
    sortAllBtn:SetPoint("LEFT", 6, 0)
    sortAllBtn:SetAnimatedHighlight(true)
    sortAllBtn:SetBorderHighlightColor(0, 0.8, 1, 1)
    sortAllBtn:SetTextHighlightColor(1, 1, 1)
    sortAllBtn:SetOnClick(function()
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
        KS._sortAcknowledged = true
        KS._lastSortedRosterCount = #KS.roster
        if KS.UpdateGroupView then KS.UpdateGroupView() end
        if KS.UpdateSortGlow then KS.UpdateSortGlow() end
        if KS.UpdateSidebarNotification then KS.UpdateSidebarNotification() end
    end)
    KS.sortButtonGroups = sortAllBtn
    KS.SetTooltip(sortAllBtn, "ANCHOR_BOTTOM", {"Sort All", "Re-sorts all unlocked groups from scratch.", "Locked groups are preserved."})

    -- Sort New: only places unassigned players into empty groups
    local sortNewBtn = KS.CreateButton(groupsToolbar, "Sort New", "widget", 62, 22)
    sortNewBtn:SetPoint("LEFT", sortAllBtn, "RIGHT", 4, 0)
    sortNewBtn:SetAnimatedHighlight(true)
    sortNewBtn:SetOnClick(function()
        if #KS.unassigned == 0 then
            print("|cff00ccffKeySorter|r: No unassigned players to sort.")
            return
        end
        KS.SortUnassigned()
        if not KS.previewMode and KS.IsPermitted() then
            KS.ApplyGroups()
        end
        KS._sortAcknowledged = true
        KS._lastSortedRosterCount = #KS.roster
        if KS.UpdateGroupView then KS.UpdateGroupView() end
        if KS.UpdateSortGlow then KS.UpdateSortGlow() end
        if KS.UpdateSidebarNotification then KS.UpdateSidebarNotification() end
    end)
    KS.SetTooltip(sortNewBtn, "ANCHOR_BOTTOM", {"Sort New", "Places unassigned players into empty group slots.", "Existing groups (locked or unlocked) are not changed."})

    -- Pulsing glow border on sort button when unassigned players exist
    -- Four edge textures that pulse cyan around the button
    local glowEdges = {}
    local function CreateGlowEdge(point1, rel, point2, w, h)
        local t = sortAllBtn:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(0, 0.8, 1, 0)
        t:SetPoint(point1, sortAllBtn, rel, 0, 0)
        t:SetSize(w, h)
        t:Hide()
        return t
    end
    -- Top, Bottom, Left, Right edges (2px thick, extending slightly beyond the button)
    -- Top and bottom span full width, left and right fit between them (no corner overlap)
    glowEdges.top = sortAllBtn:CreateTexture(nil, "OVERLAY", nil, 7)
    glowEdges.top:SetPoint("TOPLEFT", -2, 2)
    glowEdges.top:SetPoint("TOPRIGHT", 2, 2)
    glowEdges.top:SetHeight(2)
    glowEdges.top:SetColorTexture(0, 0.8, 1, 0)

    glowEdges.bottom = sortAllBtn:CreateTexture(nil, "OVERLAY", nil, 7)
    glowEdges.bottom:SetPoint("BOTTOMLEFT", -2, -2)
    glowEdges.bottom:SetPoint("BOTTOMRIGHT", 2, -2)
    glowEdges.bottom:SetHeight(2)
    glowEdges.bottom:SetColorTexture(0, 0.8, 1, 0)

    glowEdges.left = sortAllBtn:CreateTexture(nil, "OVERLAY", nil, 7)
    glowEdges.left:SetPoint("TOPLEFT", -2, 0)
    glowEdges.left:SetPoint("BOTTOMLEFT", -2, 0)
    glowEdges.left:SetWidth(2)
    glowEdges.left:SetColorTexture(0, 0.8, 1, 0)

    glowEdges.right = sortAllBtn:CreateTexture(nil, "OVERLAY", nil, 7)
    glowEdges.right:SetPoint("TOPRIGHT", 2, 0)
    glowEdges.right:SetPoint("BOTTOMRIGHT", 2, 0)
    glowEdges.right:SetWidth(2)
    glowEdges.right:SetColorTexture(0, 0.8, 1, 0)

    local glowElapsed = 0
    local glowActive = false

    -- Separate child frame for glow animation OnUpdate
    local glowFrame = CreateFrame("Frame", nil, sortAllBtn)

    local function ShowGlowEdges(show)
        for _, t in pairs(glowEdges) do
            if show then t:Show() else t:Hide() end
        end
    end

    function KS.UpdateSortGlow()
        -- Reset acknowledged state if new players have joined since last sort
        if KS._sortAcknowledged and KS._lastSortedRosterCount and #KS.roster > KS._lastSortedRosterCount then
            KS._sortAcknowledged = false
        end

        -- Glow when unassigned/unsorted AND not yet acknowledged by clicking Sort
        local needsAttention = (#KS.unassigned > 0 or (#KS.roster > 0 and #KS.groups == 0)) and not KS._sortAcknowledged
        if needsAttention then
            if not glowActive then
                glowActive = true
                ShowGlowEdges(true)
                glowElapsed = 0
                glowFrame:SetScript("OnUpdate", function(self, dt)
                    if not glowActive then return end
                    glowElapsed = glowElapsed + dt
                    local alpha = 0.4 + 0.4 * math.sin(glowElapsed * 3)
                    for _, t in pairs(glowEdges) do
                        t:SetColorTexture(0, 0.8, 1, alpha)
                    end
                end)
            end
        else
            if glowActive then
                glowActive = false
                ShowGlowEdges(false)
                glowFrame:SetScript("OnUpdate", nil)
            end
        end
    end

    local switchOptions = {}
    for _, mode in ipairs(KS.SORT_MODES) do
        table.insert(switchOptions, { text = mode.label, value = mode.key })
    end
    local sortSwitch = KS.CreateSwitch(groupsToolbar, 240, 22, switchOptions)
    sortSwitch:SetPoint("LEFT", sortNewBtn, "RIGHT", 8, 0)
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
    local currentTab = nil

    local function SetTabInternal(tab)
        currentTab = tab
        for name, content in pairs(tabContents) do
            if name == tab then content:Show() else content:Hide() end
        end
        sidebar:SelectButton(tab)

        -- Lazy-create views on first visit, refresh on subsequent visits
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
        elseif tab == "players" then
            if KS.IsPlayersViewCreated() then
                KS.RefreshPlayersView()
            else
                KS.CreatePlayersView(playersContent)
            end
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
    KS.playersContent = playersContent

    KS.CreateRosterView(rosterContent)
    KS.CreateGroupView(groupContent)
    -- About and Settings are lazy-loaded on first tab visit
    -- (text wrapping needs actual frame width, which is 0 at init)

    -- Resize handle
    f:SetResizable(true)
    f:SetResizeBounds(540, 350, MAX_FRAME_WIDTH, MAX_FRAME_HEIGHT)

    local resizer = KS.CreateResizeButton(f)
    resizer:SetScript("OnMouseDown", function()
        -- Re-anchor to TOPLEFT so BOTTOMRIGHT sizing works predictably
        local left, top = f:GetLeft(), f:GetTop()
        local parentTop = UIParent:GetTop()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        -- Clamp to max bounds before saving
        local fw = math.min(f:GetWidth(), MAX_FRAME_WIDTH)
        local fh = math.min(f:GetHeight(), MAX_FRAME_HEIGHT)
        f:SetSize(fw, fh)
        -- Save position and size
        local point, _, relPoint, x, y = f:GetPoint()
        KeySorterDB.point = { point, "UIParent", relPoint, x, y }
        KeySorterDB.frameWidth = fw
        KeySorterDB.frameHeight = fh
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
                if not InCombatLockdown() then
                    self:SetPropagateKeyboardInput(true)
                end
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

    -- Combat overlay: blocks interaction and shows a message during combat
    local combatOverlay = CreateFrame("Frame", nil, f)
    combatOverlay:SetAllPoints()
    combatOverlay:SetFrameLevel(f:GetFrameLevel() + 50)
    combatOverlay:EnableMouse(true) -- blocks all clicks
    combatOverlay:Hide()

    local combatBg = combatOverlay:CreateTexture(nil, "BACKGROUND")
    combatBg:SetAllPoints()
    combatBg:SetColorTexture(0, 0, 0, 0.7)

    local combatText = combatOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    combatText:SetPoint("CENTER", 0, 0)
    combatText:SetText("No changes can be made during combat;\nplease wait until combat ends.")
    combatText:SetTextColor(0.8, 0.2, 0.2)

    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- leaving combat
    combatFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if f:IsShown() then combatOverlay:Show() end
        else
            combatOverlay:Hide()
        end
    end)
    f:HookScript("OnShow", function()
        if InCombatLockdown() then combatOverlay:Show() end
    end)

    -- Handle ESC to close (don't use UISpecialFrames — it conflicts with fade animations)
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(true)
    f:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        if key == "ESCAPE" and self:IsShown() then
            self:SetPropagateKeyboardInput(false)
            self:FadeOut()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    f:Hide()
end
