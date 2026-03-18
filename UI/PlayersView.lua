local addonName, KS = ...

---------------------------------------------------------------------------
-- Players View: historical character database from KeySorterDB.knownChars
-- Mirrors the Roster view layout (filters, sortable columns, tooltips).
-- Created on tab enter, destroyed on tab leave.
---------------------------------------------------------------------------

local ROW_HEIGHT = 20
local HEADER_HEIGHT = 24
local TOOLBAR_HEIGHT = 30

local scrollFrame, scrollChild
local rows = {}
local headerTexts = {}
local headerButtons = {}
local sortArrows = {}
local parentFrame

local sortField = "score"
local sortAsc = false
local filterIdx = 1
local roleFilter = "ALL"
local utilityFilter = "ALL"
local searchQuery = ""

local BASE_COLUMNS = {
    { key = "name",         label = "Name",      baseWidth = 120, minWidth = 60, flex = true, align = "LEFT",   sortable = true },
    { key = "role",         label = "Role",      baseWidth = 40,  minWidth = 30, align = "CENTER", sortable = true },
    { key = "score",        label = "Score",     baseWidth = 68,  minWidth = 50, align = "RIGHT",  sortable = true },
    { key = "ilvl",         label = "iLvl",      baseWidth = 52,  minWidth = 40, align = "RIGHT",  sortable = true },
    { key = "lastSeen",     label = "Last Seen", baseWidth = 68,  minWidth = 50, align = "RIGHT",  sortable = true },
    { key = "utilityCount", label = "Utility",   baseWidth = 70,  minWidth = 50, align = "CENTER", sortable = true },
}

local COLUMNS = {}
for i, col in ipairs(BASE_COLUMNS) do
    COLUMNS[i] = { key = col.key, label = col.label, width = col.baseWidth, align = col.align, sortable = col.sortable }
end

local ROLE_LABELS = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function RecalcColumnWidths(availableWidth)
    local fixedTotal = 4
    local flexIdx = nil
    for i, col in ipairs(BASE_COLUMNS) do
        if col.flex then flexIdx = i
        else fixedTotal = fixedTotal + col.baseWidth end
    end
    if flexIdx then
        COLUMNS[flexIdx].width = math.max(BASE_COLUMNS[flexIdx].minWidth, availableWidth - fixedTotal - 4)
    end
    -- Scale down if very narrow
    local totalBase = 4
    for _, col in ipairs(BASE_COLUMNS) do totalBase = totalBase + col.baseWidth end
    if availableWidth < totalBase then
        local scale = math.max(0.5, availableWidth / totalBase)
        for i, col in ipairs(BASE_COLUMNS) do
            COLUMNS[i].width = math.max(col.minWidth, math.floor(col.baseWidth * scale))
        end
    end
end

local function GetColumnX(idx)
    local x = 4
    for i = 1, idx - 1 do x = x + COLUMNS[i].width end
    return x
end

local function FormatLastSeen(timestamp)
    if not timestamp or timestamp == 0 then return "Unknown" end
    local diff = time() - timestamp
    if diff < 86400 then return "Today"
    elseif diff < 604800 then return math.floor(diff / 86400) .. "d ago"
    else
        local weeks = math.floor(diff / 604800)
        return weeks .. "w ago"
    end
end

local function GetUtilityString(player)
    local parts = {}
    if player.hasBrez then table.insert(parts, "|cff00cc00BR|r") end
    if player.hasLust then table.insert(parts, "|cff00cc00BL|r") end
    if player.hasShroud then table.insert(parts, "|cff8800ccSH|r") end
    return table.concat(parts, " ")
end

local function CompareMembers(a, b)
    local va, vb = a[sortField], b[sortField]
    if type(va) == "string" or type(vb) == "string" then
        va = va or ""
        vb = vb or ""
        if va == vb then return (a.name or "") < (b.name or "") end
        if sortAsc then return va < vb else return va > vb end
    else
        va = va or 0
        vb = vb or 0
        if va == vb then return (a.name or "") < (b.name or "") end
        if sortAsc then return va < vb else return va > vb end
    end
end

local function PassesFilter(player)
    -- Score filter
    if filterIdx > 1 then
        local thresh = KS.SCORE_THRESHOLDS[filterIdx]
        if player.score < thresh.min or player.score > thresh.max then return false end
    end
    -- Role filter
    if roleFilter ~= "ALL" and player.role ~= roleFilter then return false end
    -- Utility filter
    if utilityFilter == "BREZ" and not player.hasBrez then return false end
    if utilityFilter == "LUST" and not player.hasLust then return false end
    if utilityFilter == "SHROUD" and not player.hasShroud then return false end
    -- Search filter
    if searchQuery ~= "" and not player.name:lower():find(searchQuery, 1, true) then return false end
    return true
end

local function BuildPlayerList()
    local players = {}
    if not KeySorterDB or not KeySorterDB.knownChars then return players end

    for name, info in pairs(KeySorterDB.knownChars) do
        local classFile = info.classFile or "WARRIOR"
        local player = {
            name = name,
            classFile = classFile,
            role = info.role or "DAMAGER",
            score = info.score or 0,
            ilvl = info.ilvl or 0,
            lastSeen = info.lastSeen or 0,
            hasBrez = KS.BREZ[classFile] or false,
            hasLust = KS.LUST[classFile] or false,
            hasShroud = KS.SHROUD[classFile] or false,
            utilityCount = (KS.BREZ[classFile] and 1 or 0) + (KS.LUST[classFile] and 1 or 0) + (KS.SHROUD[classFile] and 1 or 0),
            hasNote = KeySorterDB.notes and KeySorterDB.notes[name] and KeySorterDB.notes[name] ~= "",
            altTag = KeySorterDB.alts and KeySorterDB.alts[name] or nil,
        }
        if PassesFilter(player) then
            table.insert(players, player)
        end
    end

    table.sort(players, CompareMembers)
    return players
end

---------------------------------------------------------------------------
-- Sort indicators
---------------------------------------------------------------------------
local function UpdateSortIndicators()
    for ci, col in ipairs(COLUMNS) do
        if col.sortable and headerTexts[ci] then
            if sortField == col.key then
                headerTexts[ci]:SetText(col.label)
                headerTexts[ci]:SetTextColor(1, 1, 1)
                if not sortArrows[ci] then
                    local arrow = headerTexts[ci]:GetParent():CreateTexture(nil, "OVERLAY")
                    arrow:SetSize(8, 8)
                    arrow:SetPoint("LEFT", headerTexts[ci], "RIGHT", 2, 0)
                    sortArrows[ci] = arrow
                end
                sortArrows[ci]:SetTexture(sortAsc and KS.MEDIA.ArrowUp or KS.MEDIA.ArrowDown)
                sortArrows[ci]:SetVertexColor(0, 0.8, 1)
                sortArrows[ci]:Show()
            else
                headerTexts[ci]:SetText(col.label)
                headerTexts[ci]:SetTextColor(0.7, 0.7, 0.7)
                if sortArrows[ci] then sortArrows[ci]:Hide() end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Row creation (mirrors RosterView pattern)
---------------------------------------------------------------------------
local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.03 or 0.05)

    local hoverTex = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    hoverTex:SetAllPoints()
    hoverTex:SetColorTexture(1, 1, 1, 0.1)
    hoverTex:Hide()
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")

    row:SetScript("OnEnter", function(self)
        hoverTex:Show()
        if self._playerData then
            KS.ShowTooltip(self, "ANCHOR_RIGHT", {
                "Player Info",
                {"|cffccccccClick|r to inspect", 0.8, 0.8, 0.8},
            })
        end
    end)
    row:SetScript("OnLeave", function(self)
        hoverTex:Hide()
        KS.HideTooltip()
    end)
    row:SetScript("OnClick", function(self)
        if not self._playerData then return end
        local p = self._playerData
        local member = {
            name = p.name,
            classFile = p.classFile,
            role = p.role or "DAMAGER",
            score = p.score or 0,
            ilvl = p.ilvl or 0,
            avgKeyLevel = 0,
            runs = {},
            numRuns = 0,
            keystoneFivePlus = 0,
            keystoneTenPlus = 0,
            keystoneFifteenPlus = 0,
            keystoneTwentyPlus = 0,
            hasBrez = p.hasBrez,
            hasLust = p.hasLust,
            hasShroud = p.hasShroud,
            seasonScores = KeySorterDB.seasonScores and KeySorterDB.seasonScores[p.name] or {},
            dataSource = "history",
        }
        KS.ShowCharacterDetail(member, "players")
    end)

    row.texts = {}
    for ci, col in ipairs(COLUMNS) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local x = GetColumnX(ci)
        fs:SetPoint("LEFT", x, 0)
        fs:SetWordWrap(false)
        if col.align == "RIGHT" then
            fs:SetWidth(col.width - 4)
            fs:SetJustifyH("RIGHT")
        elseif col.align == "CENTER" then
            fs:SetWidth(col.width)
            fs:SetJustifyH("CENTER")
        else
            fs:SetWidth(col.width)
            fs:SetJustifyH("LEFT")
        end
        row.texts[ci] = fs
    end

    -- Role icon (overlays text cell)
    row.roleIcon = row:CreateTexture(nil, "OVERLAY")
    row.roleIcon:SetSize(14, 14)
    row.roleIcon:SetPoint("CENTER", row.texts[2], "CENTER", 0, 0)

    return row
end

---------------------------------------------------------------------------
-- Update view
---------------------------------------------------------------------------
local countText

local function UpdatePlayersView()
    if not scrollChild then return end
    local players = BuildPlayerList()

    if countText then
        countText:SetText(#players .. " players")
    end

    local containerWidth = scrollChild:GetWidth()
    if containerWidth < 1 then containerWidth = 500 end
    RecalcColumnWidths(containerWidth)

    -- Reposition header buttons/texts to match recalculated column widths
    for ci, col in ipairs(COLUMNS) do
        local x = GetColumnX(ci)
        if headerButtons[ci] then
            headerButtons[ci]:ClearAllPoints()
            headerButtons[ci]:SetPoint("LEFT", x, 0)
            headerButtons[ci]:SetSize(col.width, HEADER_HEIGHT)
        end
        if headerTexts[ci] then
            headerTexts[ci]:ClearAllPoints()
            if col.align == "RIGHT" then
                headerTexts[ci]:SetPoint("LEFT", 0, 0)
                headerTexts[ci]:SetWidth(col.width - 4)
            elseif col.align == "CENTER" then
                headerTexts[ci]:SetPoint("LEFT", 0, 0)
                headerTexts[ci]:SetWidth(col.width)
            else
                headerTexts[ci]:SetPoint("LEFT", 2, 0)
            end
        end
    end

    for i, player in ipairs(players) do
        local row = rows[i]
        if not row then
            row = CreateRow(scrollChild, i)
            rows[i] = row
        end
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
        row:Show()

        -- Reposition column texts
        for ci, col in ipairs(COLUMNS) do
            local x = GetColumnX(ci)
            row.texts[ci]:SetPoint("LEFT", x, 0)
            if col.align == "RIGHT" then
                row.texts[ci]:SetWidth(col.width - 4)
            else
                row.texts[ci]:SetWidth(col.width)
            end
        end

        -- Name (class colored, with note/alt indicators)
        local c = KS.CLASS_COLORS[player.classFile]
        local cr, cg, cb = c and c.r or 1, c and c.g or 1, c and c.b or 1
        local nameText = player.name
        if player.hasNote then nameText = nameText .. " |cffffff00*|r" end
        if player.altTag then nameText = nameText .. " |cff888888~|r" end
        row.texts[1]:SetText(nameText)
        row.texts[1]:SetTextColor(cr, cg, cb)

        -- Role icon
        local roleAtlas = KS.ROLE_ICONS[player.role]
        if roleAtlas then
            row.roleIcon:SetAtlas(roleAtlas)
            row.roleIcon:Show()
            row.texts[2]:SetText("")
        else
            row.roleIcon:Hide()
            row.texts[2]:SetText(ROLE_LABELS[player.role] or "?")
        end

        -- Score
        if player.score > 0 then
            local sr, sg, sb = KS.GetScoreColor(player.score)
            row.texts[3]:SetText(format("|cff%02x%02x%02x%d|r", sr * 255, sg * 255, sb * 255, player.score))
        else
            row.texts[3]:SetText("|cff666666—|r")
        end

        -- iLvl
        if player.ilvl > 0 then
            local ir, ig, ib = KS.GetIlvlColor(player.ilvl)
            row.texts[4]:SetText(format("|cff%02x%02x%02x%d|r", ir * 255, ig * 255, ib * 255, player.ilvl))
        else
            row.texts[4]:SetText("|cff666666—|r")
        end

        -- Last Seen
        row.texts[5]:SetText(FormatLastSeen(player.lastSeen))
        row.texts[5]:SetTextColor(0.6, 0.6, 0.6)

        -- Utility
        row.texts[6]:SetText(GetUtilityString(player))

        row._playerData = player
    end

    for i = #players + 1, #rows do
        rows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(#players * ROW_HEIGHT, 1))
end

---------------------------------------------------------------------------
-- Create view (called when Players tab is entered)
---------------------------------------------------------------------------
function KS.CreatePlayersView(parent)
    parentFrame = parent

    ---------------------------------------------------------------------------
    -- Toolbar: filter dropdowns + search + count
    ---------------------------------------------------------------------------
    local toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", 0, 0)
    toolbar:SetHeight(TOOLBAR_HEIGHT)

    -- Score filter
    local ddItems = {}
    for i, thresh in ipairs(KS.SCORE_THRESHOLDS) do
        table.insert(ddItems, { text = thresh.label, value = i })
    end
    local filterDD = KS.CreateDropdown(toolbar, 100)
    filterDD:SetPoint("LEFT", 4, 0)
    filterDD:SetItems(ddItems)
    filterDD:SetSelected(filterIdx)
    filterDD:SetOnSelect(function(value)
        filterIdx = value
        UpdatePlayersView()
    end)

    -- Role filter
    local roleDD = KS.CreateDropdown(toolbar, 82)
    roleDD:SetPoint("LEFT", filterDD, "RIGHT", 4, 0)
    roleDD:SetItems({
        { text = "All Roles", value = "ALL" },
        { text = "Tank", value = "TANK" },
        { text = "Healer", value = "HEALER" },
        { text = "DPS", value = "DAMAGER" },
    })
    roleDD:SetSelected(roleFilter)
    roleDD:SetOnSelect(function(value)
        roleFilter = value
        UpdatePlayersView()
    end)

    -- Utility filter
    local utilDD = KS.CreateDropdown(toolbar, 78)
    utilDD:SetPoint("LEFT", roleDD, "RIGHT", 4, 0)
    utilDD:SetItems({
        { text = "All Util", value = "ALL" },
        { text = "BRez", value = "BREZ" },
        { text = "Lust", value = "LUST" },
        { text = "Shroud", value = "SHROUD" },
    })
    utilDD:SetSelected(utilityFilter)
    utilDD:SetOnSelect(function(value)
        utilityFilter = value
        UpdatePlayersView()
    end)

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, toolbar, "BackdropTemplate")
    searchBox:SetPoint("LEFT", utilDD, "RIGHT", 8, 0)
    searchBox:SetSize(120, 20)
    searchBox:SetBackdrop(KS.BACKDROP)
    searchBox:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    searchBox:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(4, 4, 2, 2)
    -- Placeholder text
    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeholder:SetPoint("LEFT", 5, 0)
    placeholder:SetText("Search...")
    placeholder:SetTextColor(0.4, 0.4, 0.4)

    searchBox:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText()
        searchQuery = text:lower()
        if text == "" then placeholder:Show() else placeholder:Hide() end
        if userInput then
            UpdatePlayersView()
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        searchQuery = ""
        UpdatePlayersView()
    end)
    searchBox:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then placeholder:Show() end
    end)

    -- Player count
    countText = toolbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("RIGHT", -30, 0)
    countText:SetTextColor(0.6, 0.6, 0.6)

    ---------------------------------------------------------------------------
    -- Column headers (matches Roster style)
    ---------------------------------------------------------------------------
    local headerBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    headerBar:SetPoint("TOPLEFT", 0, -TOOLBAR_HEIGHT)
    headerBar:SetPoint("TOPRIGHT", 0, -TOOLBAR_HEIGHT)
    headerBar:SetHeight(HEADER_HEIGHT)
    headerBar:SetBackdrop(KS.BACKDROP)
    headerBar:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    headerBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    for ci, col in ipairs(COLUMNS) do
        local x = GetColumnX(ci)

        if col.sortable then
            local btn = CreateFrame("Button", nil, headerBar)
            btn:SetPoint("LEFT", x, 0)
            btn:SetSize(col.width, HEADER_HEIGHT)
            headerButtons[ci] = btn

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            if col.align == "RIGHT" then
                text:SetPoint("LEFT", 0, 0)
                text:SetWidth(col.width - 4)
                text:SetJustifyH("RIGHT")
            elseif col.align == "CENTER" then
                text:SetPoint("LEFT", 0, 0)
                text:SetWidth(col.width)
                text:SetJustifyH("CENTER")
            else
                text:SetPoint("LEFT", 2, 0)
            end
            text:SetText(col.label)
            text:SetTextColor(0.7, 0.7, 0.7)
            headerTexts[ci] = text

            btn:SetScript("OnEnter", function() text:SetTextColor(1, 1, 1) end)
            btn:SetScript("OnLeave", function() UpdateSortIndicators() end)
            btn:SetScript("OnClick", function()
                if sortField == col.key then
                    sortAsc = not sortAsc
                else
                    sortField = col.key
                    sortAsc = (col.key == "name")
                end
                UpdateSortIndicators()
                UpdatePlayersView()
            end)
        else
            local text = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            if col.align == "RIGHT" then
                text:SetPoint("LEFT", x, 0)
                text:SetWidth(col.width - 4)
                text:SetJustifyH("RIGHT")
            elseif col.align == "CENTER" then
                text:SetPoint("LEFT", x, 0)
                text:SetWidth(col.width)
                text:SetJustifyH("CENTER")
            else
                text:SetPoint("LEFT", x + 2, 0)
            end
            text:SetText(col.label)
            text:SetTextColor(0.4, 0.4, 0.4)
            headerTexts[ci] = text
        end
    end

    UpdateSortIndicators()

    ---------------------------------------------------------------------------
    -- Scroll area
    ---------------------------------------------------------------------------
    local scrollParent = CreateFrame("Frame", nil, parent)
    scrollParent:SetPoint("TOPLEFT", 0, -(TOOLBAR_HEIGHT + HEADER_HEIGHT))
    scrollParent:SetPoint("BOTTOMRIGHT", 0, 0)

    scrollFrame, scrollChild = KS.CreateScrollFrame(scrollParent, "KeySorterPlayersScroll")

    C_Timer.After(0, UpdatePlayersView)
end

---------------------------------------------------------------------------
-- Refresh view (called on tab enter if already created)
---------------------------------------------------------------------------
function KS.RefreshPlayersView()
    if scrollChild then
        UpdatePlayersView()
    end
end

---------------------------------------------------------------------------
-- Check if view exists
---------------------------------------------------------------------------
function KS.IsPlayersViewCreated()
    return scrollFrame ~= nil
end
