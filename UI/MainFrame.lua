local addonName, KS = ...

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500
local TITLEBAR_H = 28
local TABBAR_Y = -30
local TAB_H = 22
local CONTENT_Y = -56

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

    -- About "?"
    local aboutBtn = KS.CreateButton(titleBar, "?", "gray_hover", 20, 20)
    aboutBtn:SetPoint("LEFT", title, "RIGHT", 6, 0)
    aboutBtn:SetOnClick(function() KS.ToggleAbout() end)
    KS.AddTooltip(aboutBtn, "About KeySorter", "View credits, license, and command reference.")

    -- Close
    local close = KS.CreateButton(titleBar, "X", "red", 20, 20)
    close:SetPoint("RIGHT", -4, 0)
    close:SetOnClick(function() f:Hide() end)

    -- Action buttons — all same accent color
    local syncBtn = KS.CreateButton(titleBar, "Sync", "accent", 52, 20)
    syncBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
    syncBtn:SetOnClick(function() KS.SendSync() end)
    KS.AddTooltip(syncBtn, "Sync Groups", "Broadcast group assignments to raid assistants.")

    local applyBtn = KS.CreateButton(titleBar, "Apply", "accent", 52, 20)
    applyBtn:SetPoint("RIGHT", syncBtn, "LEFT", -4, 0)
    applyBtn:SetOnClick(function() KS.ApplyGroups() end)
    KS.AddTooltip(applyBtn, "Apply Groups", "Move players into raid subgroups and announce in raid chat.", "Works without addon on members — uses native raid groups.")

    local sortBtn = KS.CreateButton(titleBar, "Sort", "accent", 52, 20)
    sortBtn:SetPoint("RIGHT", applyBtn, "LEFT", -4, 0)
    sortBtn:SetOnClick(function()
        if #KS.roster == 0 then KS.ScanRoster() end
        KS.SortGroups()
        SetTab("groups")
    end)
    KS.sortButton = sortBtn
    KS.AddTooltip(sortBtn, "Sort Groups", "Group players by similar skill level.", "1 tank, 1 healer, 3 DPS per group. BR/BL balanced where possible.")

    local scanBtn = KS.CreateButton(titleBar, "Scan", "accent", 52, 20)
    scanBtn:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)
    scanBtn:SetOnClick(function()
        KS.ScanRoster()
        SetTab("roster")
    end)
    KS.scanButton = scanBtn
    KS.AddTooltip(scanBtn, "Scan Roster", "Collect M+ data for all group members.")

    ---------------------------------------------------------------------------
    -- Tab buttons
    ---------------------------------------------------------------------------
    local activeTab = "roster"
    local tabButtons = {}
    local tabContents = {}

    local function SetTabInternal(tab)
        activeTab = tab
        for name, content in pairs(tabContents) do
            if name == tab then content:Show() else content:Hide() end
        end
        for name, btn in pairs(tabButtons) do
            if name == tab then btn:LockHighlight() else btn:UnlockHighlight() end
        end
    end
    SetTab = SetTabInternal
    KS.SetTab = SetTabInternal

    local function CreateTab(name, label, prevTab)
        local btn = KS.CreateButton(f, label, "widget", 80, TAB_H)
        if prevTab then
            btn:SetPoint("LEFT", prevTab, "RIGHT", 2, 0)
        else
            btn:SetPoint("TOPLEFT", 8, TABBAR_Y)
        end
        btn:SetOnClick(function() SetTabInternal(name) end)
        tabButtons[name] = btn

        local content = CreateFrame("Frame", nil, f)
        content:SetPoint("TOPLEFT", 8, CONTENT_Y)
        content:SetPoint("BOTTOMRIGHT", -8, 8)
        content:Hide()
        tabContents[name] = content

        return btn, content
    end

    local rosterTabBtn, rosterContent = CreateTab("roster", "Roster", nil)
    local groupsTabBtn, groupContent = CreateTab("groups", "Groups", rosterTabBtn)
    local previewTabBtn, previewContent = CreateTab("preview", "Preview", groupsTabBtn)

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
    desc:SetText("Preview Mode")
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
            statusText:SetText("|cff00ff00ON|r — showing 25 fake players")
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
            if KS.UpdateRosterView then KS.UpdateRosterView() end
            if KS.UpdateGroupView then KS.UpdateGroupView() end
        end
    end)
end

---------------------------------------------------------------------------
-- Apply groups: move players into raid subgroups + announce to chat
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

    -- Move players into subgroups
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

    -- Announce to raid chat
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

    print("|cff00ccffKeySorter|r: Groups applied and announced in raid chat.")
end
