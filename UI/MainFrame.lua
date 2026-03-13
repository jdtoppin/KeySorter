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

    -- About button
    local aboutBtn = KS.CreateButton(titleBar, "About", "gray_hover", 44, 20)
    aboutBtn:SetPoint("RIGHT", close, "LEFT", -4, 0)
    aboutBtn:SetOnClick(function() KS.ToggleAbout() end)
    KS.AddTooltip(aboutBtn, "About KeySorter", "View credits, license, and command reference.")

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
    local rosterTabBtn, rosterContent, rosterToolbar = CreateTab("roster", "Roster", nil, true)
    local groupsTabBtn, groupContent, groupsToolbar = CreateTab("groups", "Groups", rosterTabBtn, true)
    local previewTabBtn, previewContent = CreateTab("preview", "Preview", groupsTabBtn, false)

    ---------------------------------------------------------------------------
    -- Roster toolbar: Scan, Sort
    ---------------------------------------------------------------------------
    local scanBtn = KS.CreateButton(rosterToolbar, "Scan", "accent", 52, 22)
    scanBtn:SetPoint("LEFT", 6, 0)
    scanBtn:SetOnClick(function()
        KS.ScanRoster()
    end)
    KS.scanButton = scanBtn
    KS.AddTooltip(scanBtn, "Scan Roster", "Collect M+ data for all group members.")

    local sortBtnRoster = KS.CreateButton(rosterToolbar, "Sort", "accent", 52, 22)
    sortBtnRoster:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
    sortBtnRoster:SetOnClick(function()
        if #KS.roster == 0 then KS.ScanRoster() end
        KS.SortGroups()
        SetTabInternal("groups")
    end)
    KS.sortButton = sortBtnRoster
    KS.AddTooltip(sortBtnRoster, "Sort Groups", "Put like scores together so players of adequate skill level are in similar groups and can learn together.", "1 tank, 1 healer, 3 DPS per group. BR/BL balanced where possible.")

    ---------------------------------------------------------------------------
    -- Groups toolbar: Sort, Apply, Announce, Sync
    ---------------------------------------------------------------------------
    local sortBtnGroups = KS.CreateButton(groupsToolbar, "Sort", "accent", 52, 22)
    sortBtnGroups:SetPoint("LEFT", 6, 0)
    sortBtnGroups:SetOnClick(function()
        if #KS.roster == 0 then KS.ScanRoster() end
        KS.SortGroups()
        if KS.UpdateGroupView then KS.UpdateGroupView() end
    end)
    KS.sortButtonGroups = sortBtnGroups
    KS.AddTooltip(sortBtnGroups, "Sort Groups", "Put like scores together so players of adequate skill level are in similar groups and can learn together.", "1 tank, 1 healer, 3 DPS per group. BR/BL balanced where possible.")

    local applyBtn = KS.CreateButton(groupsToolbar, "Apply", "accent", 52, 22)
    applyBtn:SetPoint("LEFT", sortBtnGroups, "RIGHT", 4, 0)
    applyBtn:SetOnClick(function() KS.ApplyGroups() end)
    KS.applyButton = applyBtn
    KS.AddTooltip(applyBtn, "Apply Groups", "Move players into raid subgroups.", "Works without addon on members — uses native raid groups.")

    local announceBtn = KS.CreateButton(groupsToolbar, "Announce", "accent", 68, 22)
    announceBtn:SetPoint("LEFT", applyBtn, "RIGHT", 4, 0)
    announceBtn:SetOnClick(function() KS.AnnounceGroups() end)
    KS.announceButton = announceBtn
    KS.AddTooltip(announceBtn, "Announce Groups", "Post group assignments to raid chat.")

    local syncBtn = KS.CreateButton(groupsToolbar, "Sync", "accent", 52, 22)
    syncBtn:SetPoint("LEFT", announceBtn, "RIGHT", 4, 0)
    syncBtn:SetOnClick(function() KS.SendSync() end)
    KS.syncButton = syncBtn
    KS.AddTooltip(syncBtn, "Sync Groups", "Broadcast group assignments to raid assistants.")

    ---------------------------------------------------------------------------
    -- Store references and build views
    ---------------------------------------------------------------------------
    KS.mainFrame = f
    KS.rosterContent = rosterContent
    KS.groupContent = groupContent
    KS.previewContent = previewContent

    KS.CreateRosterView(rosterContent)
    KS.CreateGroupView(groupContent)
    KS.CreatePreviewView(previewContent)

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
-- Preview tab content
---------------------------------------------------------------------------
function KS.CreatePreviewView(parent)
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", 8, -8)
    desc:SetText("Preview / Test Mode")
    desc:SetTextColor(0, 0.8, 1)

    local subdesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subdesc:SetPoint("TOPLEFT", 8, -28)
    subdesc:SetPoint("RIGHT", -8, 0)
    subdesc:SetJustifyH("LEFT")
    subdesc:SetText("Generate fake raid data to test the UI without needing a group. Preview data is shown in the Roster and Groups tabs. Your real roster is restored when you turn preview off.")
    subdesc:SetTextColor(0.7, 0.7, 0.7)

    local statusText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", 8, -64)
    statusText:SetText("|cffff0000OFF|r")

    local toggleBtn = KS.CreateButton(parent, "Enable Preview", "accent", 140, 28)
    toggleBtn:SetPoint("TOPLEFT", 8, -86)
    toggleBtn:SetOnClick(function()
        KS.TogglePreview()
        if KS.previewMode then
            statusText:SetText("|cff00ff00ON|r — showing " .. (KS.previewPlayerCount or 25) .. " fake players")
            toggleBtn:SetText("Disable Preview")
        else
            statusText:SetText("|cffff0000OFF|r")
            toggleBtn:SetText("Enable Preview")
        end
    end)

    -- Player count slider
    local countSlider = KS.CreateSlider(parent, "Players", 5, 40, 5, 200)
    countSlider:SetPoint("TOPLEFT", 8, -130)
    countSlider:SetValue(25)
    KS.previewPlayerCount = 25
    countSlider:SetOnChange(function(val)
        KS.previewPlayerCount = val
        if KS.previewMode then
            KS.GeneratePreviewData()
            statusText:SetText("|cff00ff00ON|r — showing " .. val .. " fake players")
            if KS.UpdateRosterView then KS.UpdateRosterView() end
            if KS.UpdateGroupView then KS.UpdateGroupView() end
        end
    end)
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
function KS.AnnounceGroups()
    if #KS.groups == 0 then
        print("|cff00ccffKeySorter|r: No groups to announce. Sort first.")
        return
    end
    if KS.previewMode then
        print("|cff00ccffKeySorter|r: Cannot announce in preview mode.")
        return
    end
    if not IsInRaid() then
        print("|cff00ccffKeySorter|r: Must be in a raid to announce groups.")
        return
    end
    if not KS.IsPermitted() then
        print("|cff00ccffKeySorter|r: Only raid leader/assistants can announce groups.")
        return
    end

    SendChatMessage("--- KeySorter Group Assignments ---", "RAID")
    for groupIdx, group in ipairs(KS.groups) do
        local names = {}
        if group.tank then table.insert(names, group.tank.name .. " (T)") end
        if group.healer then table.insert(names, group.healer.name .. " (H)") end
        for _, d in ipairs(group.dps) do table.insert(names, d.name) end
        SendChatMessage(format("Group %d: %s", groupIdx, table.concat(names, ", ")), "RAID")
    end
    if #KS.unassigned > 0 then
        local unNames = {}
        for _, u in ipairs(KS.unassigned) do table.insert(unNames, u.name) end
        SendChatMessage("Unassigned: " .. table.concat(unNames, ", "), "RAID")
    end

    print("|cff00ccffKeySorter|r: Groups announced in raid chat.")
end
