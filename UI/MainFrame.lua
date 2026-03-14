local addonName, KS = ...

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500
local TITLEBAR_H = 28
local TOOLBAR_H = 30
local CONTENT_Y_NO_TOOLBAR = -(TITLEBAR_H + 2)
local CONTENT_Y_WITH_TOOLBAR = -(TITLEBAR_H + 2 + TOOLBAR_H)

function KS.CreateMainFrame()
    local f = CreateFrame("Frame", "KeySorterMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    local p = KeySorterDB.point
    f:SetPoint(p[1], UIParent, p[3], p[4], p[5])

    f:SetBackdrop(KS.BACKDROP_PANEL)
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    ---------------------------------------------------------------------------
    -- Title bar
    ---------------------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(TITLEBAR_H)
    titleBar:SetBackdrop(KS.BACKDROP_PANEL)
    titleBar:SetBackdropColor(0.12, 0.12, 0.12, 1)
    titleBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        KeySorterDB.point = { point, nil, relPoint, x, y }
    end)

    -- Title text
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("KeySorter")
    title:SetTextColor(0, 0.8, 1)

    -- Close button (right edge)
    local close = KS.CreateButton(titleBar, "X", "red", 20, 20)
    close:SetPoint("RIGHT", -4, 0)
    close:SetOnClick(function() f:Hide() end)

    -- Settings button
    local settingsBtn = KS.CreateButton(titleBar, "Settings", "gray_hover", 56, 20)
    settingsBtn:SetPoint("RIGHT", close, "LEFT", -4, 0)
    settingsBtn:SetOnClick(function() KS.ToggleSettings() end)
    KS.AddTooltip(settingsBtn, "Settings", "Configure KeySorter options.")

    -- About button (switches to about tab)
    local aboutBtn = KS.CreateButton(titleBar, "About", "gray_hover", 44, 20)
    aboutBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -4, 0)
    aboutBtn:SetOnClick(function() KS.SetTab("about") end)
    KS.AddTooltip(aboutBtn, "About KeySorter", "View overview, sort logic, and command reference.")

    ---------------------------------------------------------------------------
    -- Tab system (tabs in the title bar, right of title)
    ---------------------------------------------------------------------------
    local activeTab = "roster"
    local tabButtons = {}
    local tabContents = {}
    local tabToolbars = {}

    local function SetTabInternal(tab)
        activeTab = tab
        for name, content in pairs(tabContents) do
            if name == tab then content:Show() else content:Hide() end
        end
        for name, tb in pairs(tabToolbars) do
            if name == tab then tb:Show() else tb:Hide() end
        end
        for name, btn in pairs(tabButtons) do
            if name == tab then btn:LockHighlight() else btn:UnlockHighlight() end
        end
    end
    SetTab = SetTabInternal
    KS.SetTab = SetTabInternal

    local function CreateTab(name, label, prevTab, hasToolbar)
        local btn = KS.CreateButton(titleBar, label, "widget", 70, 20)
        if prevTab then
            btn:SetPoint("LEFT", prevTab, "RIGHT", 2, 0)
        else
            btn:SetPoint("LEFT", title, "RIGHT", 12, 0)
        end
        btn:SetOnClick(function() SetTabInternal(name) end)
        tabButtons[name] = btn

        -- Optional toolbar below the title bar
        local toolbar
        if hasToolbar then
            toolbar = CreateFrame("Frame", nil, f, "BackdropTemplate")
            toolbar:SetPoint("TOPLEFT", 1, -(TITLEBAR_H + 1))
            toolbar:SetPoint("TOPRIGHT", -1, -(TITLEBAR_H + 1))
            toolbar:SetHeight(TOOLBAR_H)
            toolbar:SetBackdrop(KS.BACKDROP_PANEL)
            toolbar:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
            toolbar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
            toolbar:Hide()
            tabToolbars[name] = toolbar
        end

        -- Content area (adjusts depending on whether this tab has a toolbar)
        local contentY = hasToolbar and CONTENT_Y_WITH_TOOLBAR or CONTENT_Y_NO_TOOLBAR
        local content = CreateFrame("Frame", nil, f)
        content:SetPoint("TOPLEFT", 8, contentY)
        content:SetPoint("BOTTOMRIGHT", -8, 8)
        content:Hide()
        tabContents[name] = content

        return btn, content, toolbar
    end

    ---------------------------------------------------------------------------
    -- Create tabs
    ---------------------------------------------------------------------------
    local rosterTabBtn, rosterContent = CreateTab("roster", "Roster", nil, false)
    local groupsTabBtn, groupContent, groupsToolbar = CreateTab("groups", "Groups", rosterTabBtn, true)
    -- About content (not a tab button — accessed via the title bar About button)
    local aboutContent = CreateFrame("Frame", nil, f)
    aboutContent:SetPoint("TOPLEFT", 8, -(TITLEBAR_H + 2))
    aboutContent:SetPoint("BOTTOMRIGHT", -8, 8)
    aboutContent:Hide()
    tabContents["about"] = aboutContent

    ---------------------------------------------------------------------------
    -- Groups toolbar: Sort, Announce, Sync
    ---------------------------------------------------------------------------
    local sortBtnGroups = KS.CreateButton(groupsToolbar, "Sort", "accent", 52, 22)
    sortBtnGroups:SetPoint("LEFT", 6, 0)
    sortBtnGroups:SetOnClick(function()
        if #KS.roster == 0 then KS.ScanRoster() end
        KS.SortGroups()
        KS.ApplyGroups()
        if KS.UpdateGroupView then KS.UpdateGroupView() end
    end)
    KS.sortButtonGroups = sortBtnGroups
    KS.AddTooltip(sortBtnGroups, "Sort Groups", "Sort players using the selected mode and move them into raid subgroups.", "1 tank, 1 healer, 3 DPS per group. BR/BL balanced where possible.")

    -- Sort mode toggle button
    local function GetSortModeLabel()
        for _, mode in ipairs(KS.SORT_MODES) do
            if mode.key == KS.sortMode then return mode.label end
        end
        return "Skill Matched"
    end
    local sortModeBtn = KS.CreateButton(groupsToolbar, GetSortModeLabel(), "widget", 100, 22)
    sortModeBtn:SetPoint("LEFT", sortBtnGroups, "RIGHT", 8, 0)
    sortModeBtn:SetOnClick(function()
        -- Cycle to next sort mode
        local keys = {}
        for _, mode in ipairs(KS.SORT_MODES) do table.insert(keys, mode.key) end
        local current = 1
        for i, k in ipairs(keys) do
            if k == KS.sortMode then current = i; break end
        end
        KS.sortMode = keys[(current % #keys) + 1]
        sortModeBtn:SetText(GetSortModeLabel())
    end)
    local function GetSortModeTooltipDesc()
        for _, mode in ipairs(KS.SORT_MODES) do
            if mode.key == KS.sortMode then return mode.desc end
        end
        return ""
    end
    KS.AddTooltip(sortModeBtn, "Sort Mode", "Click to toggle sort algorithm.", "Current: " .. GetSortModeLabel())

    ---------------------------------------------------------------------------
    -- Store references and build views
    ---------------------------------------------------------------------------
    KS.mainFrame = f
    KS.rosterContent = rosterContent
    KS.groupContent = groupContent
    KS.aboutContent = aboutContent

    KS.CreateRosterView(rosterContent)
    KS.CreateGroupView(groupContent)
    KS.CreateAboutView(aboutContent)

    -- Resize handle (bottom-right corner)
    f:SetResizable(true)
    f:SetResizeBounds(500, 350, 1000, 800)

    local resizer = CreateFrame("Button", nil, f)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
    end)

    -- Auto-scan on first show (not in preview mode)
    f:SetScript("OnShow", function()
        if not KS.previewMode and #KS.roster == 0 then
            KS.ScanRoster()
        end
        KS.UpdatePermissionState()
    end)

    SetTabInternal("roster")

    table.insert(UISpecialFrames, "KeySorterMainFrame")
    f:Hide()
end


---------------------------------------------------------------------------
-- Apply groups: move players into raid subgroups
---------------------------------------------------------------------------
function KS.ApplyGroups()
    if #KS.groups == 0 then
        print("|cff00ccffKeySorter|r: No groups to apply. Sort first.")
        return
    end
    if KS.previewMode then
        print("|cff00ccffKeySorter|r: Cannot apply in preview mode.")
        return
    end
    if not IsInRaid() then
        print("|cff00ccffKeySorter|r: Must be in a raid to apply groups.")
        return
    end
    if not KS.IsPermitted() then
        print("|cff00ccffKeySorter|r: Only raid leader/assistants can apply groups.")
        return
    end

    for groupIdx, group in ipairs(KS.groups) do
        local members = {}
        if group.tank then table.insert(members, group.tank) end
        if group.healer then table.insert(members, group.healer) end
        for _, d in ipairs(group.dps) do table.insert(members, d) end

        for _, member in ipairs(members) do
            for ri = 1, GetNumGroupMembers() do
                local raidName = GetRaidRosterInfo(ri)
                if raidName and raidName == member.name then
                    local _, _, currentGroup = GetRaidRosterInfo(ri)
                    if currentGroup ~= groupIdx then
                        SetRaidSubgroup(ri, groupIdx)
                    end
                    break
                end
            end
        end
    end

    print("|cff00ccffKeySorter|r: Groups applied to raid subgroups.")
end

---------------------------------------------------------------------------
-- Announce groups: post assignments to raid chat
---------------------------------------------------------------------------
function KS.AnnounceGroup(groupIdx)
    local group = KS.groups[groupIdx]
    if not group then return end

    if not KS.previewMode then
        if not IsInRaid() then
            print("|cff00ccffKeySorter|r: Must be in a raid to announce.")
            return
        end
        if not KS.IsPermitted() then
            print("|cff00ccffKeySorter|r: Only raid leader/assistants can announce.")
            return
        end
    end

    local function Output(msg)
        if KS.previewMode then
            print("|cff00ccff[Preview]|r " .. msg)
        else
            SendChatMessage(msg, "RAID")
        end
    end

    local names = {}
    if group.tank then table.insert(names, group.tank.name .. " (T)") end
    if group.healer then table.insert(names, group.healer.name .. " (H)") end
    for _, d in ipairs(group.dps) do table.insert(names, d.name) end
    Output(format("Group %d: %s", groupIdx, table.concat(names, ", ")))
end
