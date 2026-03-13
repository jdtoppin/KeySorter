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

    -- Title bar drag
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
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
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

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

    local rosterTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rosterTab:SetSize(80, 24)
    rosterTab:SetPoint("TOPLEFT", 12, -32)
    rosterTab:SetText("Roster")
    rosterTab:SetScript("OnClick", function() SetTab("roster") end)

    local groupTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    groupTab:SetSize(80, 24)
    groupTab:SetPoint("LEFT", rosterTab, "RIGHT", 4, 0)
    groupTab:SetText("Groups")
    groupTab:SetScript("OnClick", function() SetTab("groups") end)

    -- Scan button
    local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scanBtn:SetSize(70, 24)
    scanBtn:SetPoint("TOPRIGHT", close, "TOPLEFT", -40, -4)
    scanBtn:SetText("Scan")
    scanBtn:SetScript("OnClick", function()
        KS.ScanRoster()
        SetTab("roster")
    end)
    KS.scanButton = scanBtn

    -- Sort button
    local sortBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    sortBtn:SetSize(70, 24)
    sortBtn:SetPoint("RIGHT", scanBtn, "LEFT", -4, 0)
    sortBtn:SetText("Sort")
    sortBtn:SetScript("OnClick", function()
        if #KS.roster == 0 then
            KS.ScanRoster()
        end
        KS.SortGroups()
        SetTab("groups")
    end)
    KS.sortButton = sortBtn

    -- Sync button
    local syncBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    syncBtn:SetSize(70, 24)
    syncBtn:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)
    syncBtn:SetText("Sync")
    syncBtn:SetScript("OnClick", function() KS.SendSync() end)

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
