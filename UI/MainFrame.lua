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

    -- Backdrop
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Title bar drag region (left portion only, so buttons on right remain clickable)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", -250, 0)
    titleBar:SetHeight(30)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        KeySorterDB.point = { point, nil, relPoint, x, y }
    end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetText("KeySorter")
    title:SetTextColor(0, 0.8, 1)

    -- Close button
    local close = KS.CreateButton(f, "X", "red", 24, 24)
    close:SetPoint("TOPRIGHT", -6, -4)
    close:SetOnClick(function() f:Hide() end)

    -- Tab buttons
    local activeTab = "roster"
    local rosterContent, groupContent

    local function SetTab(tab)
        activeTab = tab
        if tab == "roster" then
            rosterContent:Show()
            groupContent:Hide()
        else
            rosterContent:Hide()
            groupContent:Show()
        end
    end
    KS.SetTab = SetTab

    local rosterTab = KS.CreateButton(f, "Roster", "accent", 80, 24)
    rosterTab:SetPoint("TOPLEFT", 12, -32)
    rosterTab:SetOnClick(function() SetTab("roster") end)

    local groupTab = KS.CreateButton(f, "Groups", "accent", 80, 24)
    groupTab:SetPoint("LEFT", rosterTab, "RIGHT", 4, 0)
    groupTab:SetOnClick(function() SetTab("groups") end)

    -- Action buttons (right side of title bar)
    local syncBtn = KS.CreateButton(f, "Sync", "blue", 64, 24)
    syncBtn:SetPoint("TOPRIGHT", -36, -4)
    syncBtn:SetOnClick(function() KS.SendSync() end)
    KS.AddTooltip(syncBtn, "Sync Groups", "Broadcast group assignments to raid assistants.")

    local scanBtn = KS.CreateButton(f, "Scan", "green", 64, 24)
    scanBtn:SetPoint("RIGHT", syncBtn, "LEFT", -4, 0)
    scanBtn:SetOnClick(function()
        KS.ScanRoster()
        SetTab("roster")
    end)
    KS.scanButton = scanBtn
    KS.AddTooltip(scanBtn, "Scan Roster", "Collect M+ rating and dungeon data for all raid members.")

    local sortBtn = KS.CreateButton(f, "Sort", "accent", 64, 24)
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

    -- About button
    local aboutBtn = KS.CreateButton(f, "?", "gray_hover", 24, 24)
    aboutBtn:SetPoint("LEFT", title, "RIGHT", 8, 0)
    aboutBtn:SetOnClick(function() KS.ToggleAbout() end)
    KS.AddTooltip(aboutBtn, "About KeySorter", "View credits, license, and command reference.")

    -- Content containers
    rosterContent = CreateFrame("Frame", nil, f)
    rosterContent:SetPoint("TOPLEFT", 8, -60)
    rosterContent:SetPoint("BOTTOMRIGHT", -8, 8)

    groupContent = CreateFrame("Frame", nil, f)
    groupContent:SetPoint("TOPLEFT", 8, -60)
    groupContent:SetPoint("BOTTOMRIGHT", -8, 8)
    groupContent:Hide()

    KS.mainFrame = f
    KS.rosterContent = rosterContent
    KS.groupContent = groupContent

    KS.CreateRosterView(rosterContent)
    KS.CreateGroupView(groupContent)

    -- Start on roster tab
    SetTab("roster")

    -- ESC to close
    table.insert(UISpecialFrames, "KeySorterMainFrame")

    f:Hide()
end
