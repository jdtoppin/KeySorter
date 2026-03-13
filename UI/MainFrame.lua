local addonName, KS = ...

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500

function KS.CreateMainFrame()
    local f = CreateFrame("Frame", "KeySorterMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    -- Restore position
    local p = KeySorterDB.point
    f:SetPoint(p[1], UIParent, p[3], p[4], p[5])

    -- Squared flat border
    f:SetBackdrop(KS.BACKDROP_PANEL)
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Title bar (drag region + visual header strip)
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
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

    -- About "?" button (child of titleBar so it receives clicks)
    local aboutBtn = KS.CreateButton(titleBar, "?", "gray_hover", 20, 20)
    aboutBtn:SetPoint("LEFT", title, "RIGHT", 6, 0)
    aboutBtn:SetOnClick(function() KS.ToggleAbout() end)
    KS.AddTooltip(aboutBtn, "About KeySorter", "View credits, license, and command reference.")

    -- Close button (child of titleBar)
    local close = KS.CreateButton(titleBar, "X", "red", 20, 20)
    close:SetPoint("RIGHT", -4, 0)
    close:SetOnClick(function() f:Hide() end)

    -- Action buttons in title bar (right side, children of titleBar)
    local syncBtn = KS.CreateButton(titleBar, "Sync", "blue", 56, 20)
    syncBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)
    syncBtn:SetOnClick(function() KS.SendSync() end)
    KS.AddTooltip(syncBtn, "Sync Groups", "Broadcast group assignments to raid assistants.")

    local scanBtn = KS.CreateButton(titleBar, "Scan", "green", 56, 20)
    scanBtn:SetPoint("RIGHT", syncBtn, "LEFT", -4, 0)
    scanBtn:SetOnClick(function()
        KS.ScanRoster()
        SetTab("roster")
    end)
    KS.scanButton = scanBtn
    KS.AddTooltip(scanBtn, "Scan Roster", "Collect M+ rating and dungeon data for all group members.")

    local sortBtn = KS.CreateButton(titleBar, "Sort", "accent", 56, 20)
    sortBtn:SetPoint("RIGHT", scanBtn, "LEFT", -4, 0)
    sortBtn:SetOnClick(function()
        if #KS.roster == 0 then
            KS.ScanRoster()
        end
        KS.SortGroups()
        SetTab("groups")
    end)
    KS.sortButton = sortBtn
    KS.AddTooltip(sortBtn, "Sort Groups", "Form balanced 5-man groups using a snake-draft algorithm.", "Each group gets 1 tank, 1 healer, and 3 DPS.")

    -- Apply button (actually move players into raid subgroups)
    local applyBtn = KS.CreateButton(titleBar, "Apply", "green", 56, 20)
    applyBtn:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)
    applyBtn:SetOnClick(function() KS.ApplyGroups() end)
    KS.AddTooltip(applyBtn, "Apply Groups", "Move players into raid subgroups and announce in raid chat.", "Works without addon on members — uses native raid groups.")

    -- Tab buttons (below title bar)
    local activeTab = "roster"
    local rosterContent, groupContent

    local function SetTabInternal(tab)
        activeTab = tab
        if tab == "roster" then
            rosterContent:Show()
            groupContent:Hide()
        else
            rosterContent:Hide()
            groupContent:Show()
        end
    end
    -- Expose for button callbacks above (upvalue used before local defined)
    SetTab = SetTabInternal
    KS.SetTab = SetTabInternal

    local rosterTab = KS.CreateButton(f, "Roster", "widget", 80, 22)
    rosterTab:SetPoint("TOPLEFT", 8, -32)
    rosterTab:SetOnClick(function() SetTabInternal("roster") end)

    local groupTab = KS.CreateButton(f, "Groups", "widget", 80, 22)
    groupTab:SetPoint("LEFT", rosterTab, "RIGHT", 4, 0)
    groupTab:SetOnClick(function() SetTabInternal("groups") end)

    -- Content containers
    rosterContent = CreateFrame("Frame", nil, f)
    rosterContent:SetPoint("TOPLEFT", 8, -58)
    rosterContent:SetPoint("BOTTOMRIGHT", -8, 8)

    groupContent = CreateFrame("Frame", nil, f)
    groupContent:SetPoint("TOPLEFT", 8, -58)
    groupContent:SetPoint("BOTTOMRIGHT", -8, 8)
    groupContent:Hide()

    KS.mainFrame = f
    KS.rosterContent = rosterContent
    KS.groupContent = groupContent

    KS.CreateRosterView(rosterContent)
    KS.CreateGroupView(groupContent)

    -- Auto-scan when frame is first shown
    f:SetScript("OnShow", function()
        if #KS.roster == 0 then
            KS.ScanRoster()
        end
        KS.UpdatePermissionState()
    end)

    -- Start on roster tab
    SetTabInternal("roster")

    -- ESC to close
    table.insert(UISpecialFrames, "KeySorterMainFrame")

    f:Hide()
end

---------------------------------------------------------------------------
-- Apply groups: move players into raid subgroups + announce to chat
---------------------------------------------------------------------------
function KS.ApplyGroups()
    if #KS.groups == 0 then
        print("|cff00ccffKeySorter|r: No groups to apply. Sort first.")
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

    -- Move players into subgroups using SetRaidSubgroup
    for groupIdx, group in ipairs(KS.groups) do
        local members = {}
        if group.tank then table.insert(members, group.tank) end
        if group.healer then table.insert(members, group.healer) end
        for _, d in ipairs(group.dps) do table.insert(members, d) end

        for _, member in ipairs(members) do
            -- Find the player's raid index
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
        for _, d in ipairs(group.dps) do
            table.insert(names, d.name)
        end
        SendChatMessage(format("Group %d: %s", groupIdx, table.concat(names, ", ")), "RAID")
    end
    if #KS.unassigned > 0 then
        local unNames = {}
        for _, u in ipairs(KS.unassigned) do
            table.insert(unNames, u.name)
        end
        SendChatMessage("Unassigned: " .. table.concat(unNames, ", "), "RAID")
    end

    print("|cff00ccffKeySorter|r: Groups applied and announced in raid chat.")
end
