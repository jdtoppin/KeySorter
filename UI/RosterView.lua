local addonName, KS = ...

local ROW_HEIGHT = 20
local HEADER_HEIGHT = 24
local TOOLBAR_HEIGHT = 30

local sortField = "score"
local sortAsc = false
local filterIdx = 1
local roleFilter = "ALL"
local utilityFilter = "ALL"
local timedFilter = 0

local scrollFrame, scrollChild
local rows = {}
local headerArrows = {} -- arrow textures per column index
local headerTexts = {}  -- label FontStrings per column index

local COLUMNS = {
    { key = "name",        label = "Name",    width = 130, align = "LEFT",   sortable = true },
    { key = "role",        label = "Role",    width = 44,  align = "CENTER", sortable = false },
    { key = "score",       label = "Score",   width = 60,  align = "RIGHT",  sortable = true },
    { key = "ilvl",        label = "iLvl",    width = 44,  align = "RIGHT",  sortable = true },
    { key = "avgKeyLevel", label = "Avg Key Lvl", width = 70,  align = "RIGHT",  sortable = true },
    { key = "numTimed",    label = "Timed",   width = 46,  align = "RIGHT",  sortable = true },
    { key = "numUntimed",  label = "Untimed", width = 56,  align = "RIGHT",  sortable = true },
    { key = "numRuns",     label = "Total",   width = 44,  align = "RIGHT",  sortable = true },
    { key = "utilities",   label = "Utility", width = 70,  align = "CENTER", sortable = false },
}

local function GetColumnX(idx)
    local x = 4
    for i = 1, idx - 1 do
        x = x + COLUMNS[i].width
    end
    return x
end

local function CompareMembers(a, b)
    local va, vb = a[sortField], b[sortField]
    if type(va) == "string" then
        if sortAsc then return va < vb else return va > vb end
    else
        va = va or 0
        vb = vb or 0
        if sortAsc then return va < vb else return va > vb end
    end
end

local function PassesFilter(member)
    -- Score filter
    if filterIdx > 1 then
        local thresh = KS.SCORE_THRESHOLDS[filterIdx]
        if member.score < thresh.min or member.score > thresh.max then return false end
    end

    -- Role filter
    if roleFilter ~= "ALL" and member.role ~= roleFilter then return false end

    -- Utility filter
    if utilityFilter == "BREZ" and not member.hasBrez then return false end
    if utilityFilter == "LUST" and not member.hasLust then return false end
    if utilityFilter == "SHROUD" and not member.hasShroud then return false end

    -- Timed runs filter
    if timedFilter > 0 and (member.numTimed or 0) < timedFilter then return false end

    return true
end

local function GetIlvlColor(ilvl)
    local anchors = KS.ILVL_COLORS
    if not anchors or #anchors == 0 then return 1, 1, 1 end

    -- Clamp below first anchor
    if ilvl <= anchors[1].ilvl then
        return anchors[1].r, anchors[1].g, anchors[1].b
    end
    -- Clamp above last anchor
    if ilvl >= anchors[#anchors].ilvl then
        return anchors[#anchors].r, anchors[#anchors].g, anchors[#anchors].b
    end

    -- Interpolate between two surrounding anchors
    for i = 2, #anchors do
        if ilvl <= anchors[i].ilvl then
            local lo = anchors[i - 1]
            local hi = anchors[i]
            local t = (ilvl - lo.ilvl) / (hi.ilvl - lo.ilvl)
            return lo.r + t * (hi.r - lo.r),
                   lo.g + t * (hi.g - lo.g),
                   lo.b + t * (hi.b - lo.b)
        end
    end

    return 1, 1, 1
end

local function GetScoreColor(score)
    if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then return color.r, color.g, color.b end
    end
    if score >= 2500 then return 1, 0.5, 0
    elseif score >= 2000 then return 0.6, 0.2, 0.8
    elseif score >= 1500 then return 0, 0.4, 1
    elseif score >= 1000 then return 0, 0.8, 0
    elseif score >= 500 then return 1, 1, 1
    else return 0.6, 0.6, 0.6 end
end

-- Resolve dungeon name: try game API first, fall back to Data.lua table
local function GetDungeonName(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name then return name end
    end
    return KS.DUNGEON_NAMES[mapID] or ("Dungeon " .. mapID)
end

-- Build the shift-tooltip for a member's per-dungeon breakdown
function KS.ShowMemberTooltip(row, member)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local classColor = KS.CLASS_COLORS[member.classFile]
    if classColor then
        GameTooltip:AddLine(member.name, classColor.r, classColor.g, classColor.b)
    else
        GameTooltip:AddLine(member.name, 1, 1, 1)
    end
    local ilvlStr = (member.ilvl and member.ilvl > 0) and format("  |  iLvl: %d", member.ilvl) or ""
    GameTooltip:AddLine(format("Score: %d  |  Avg Key: %.1f%s", member.score, member.avgKeyLevel, ilvlStr), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")

    if not member.runs or next(member.runs) == nil then
        GameTooltip:AddLine("No dungeon runs recorded.", 0.5, 0.5, 0.5)
    else
        GameTooltip:AddLine("Dungeon Breakdown:", 0, 0.8, 1)
        -- Show runs in consistent order using the season dungeon list
        local shown = {}
        for _, mapID in ipairs(KS.DUNGEON_IDS) do
            local run = member.runs[mapID]
            if run then
                shown[mapID] = true
                local name = GetDungeonName(mapID)
                local timedStr
                if run.timed then
                    timedStr = "|cff00cc00Timed|r"
                else
                    timedStr = "|cffcc0000Untimed|r"
                end
                GameTooltip:AddDoubleLine(
                    format("  %s", name),
                    format("+%d  %s", run.level, timedStr),
                    0.8, 0.8, 0.8,
                    1, 1, 1
                )
            end
        end
        -- Show any runs with IDs not in the season list
        for mapID, run in pairs(member.runs) do
            if not shown[mapID] then
                local name = GetDungeonName(mapID)
                local timedStr
                if run.timed then
                    timedStr = "|cff00cc00Timed|r"
                else
                    timedStr = "|cffcc0000Untimed|r"
                end
                GameTooltip:AddDoubleLine(
                    format("  %s", name),
                    format("+%d  %s", run.level, timedStr),
                    0.8, 0.8, 0.8,
                    1, 1, 1
                )
            end
        end
    end

    -- Utilities
    local utils = {}
    if member.hasBrez then table.insert(utils, "Battle Rez") end
    if member.hasLust then table.insert(utils, "Bloodlust") end
    if member.hasShroud then table.insert(utils, "Shroud") end
    if #utils > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Utilities: " .. table.concat(utils, ", "), 0.5, 0.8, 0.5)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Hold Shift to keep open", 0.4, 0.4, 0.4)
    GameTooltip:Show()
end

local function GetUtilityString(member)
    local parts = {}
    if member.hasBrez then table.insert(parts, "|cff00cc00BR|r") end
    if member.hasLust then table.insert(parts, "|cff00cc00BL|r") end
    if member.hasShroud then table.insert(parts, "|cff8800ccSH|r") end
    return table.concat(parts, " ")
end

-- Update sort arrows: highlight the active sort column's arrow
local function UpdateSortIndicators()
    for ci, col in ipairs(COLUMNS) do
        if col.sortable and headerArrows[ci] then
            local arrow = headerArrows[ci]
            if sortField == col.key then
                -- Active sort: bright arrow, rotated for direction
                arrow:SetRotation(sortAsc and math.pi or 0)
                arrow:SetVertexColor(0, 0.8, 1, 1)
                headerTexts[ci]:SetTextColor(1, 1, 1)
            else
                -- Inactive: dim arrow pointing down
                arrow:SetRotation(0)
                arrow:SetVertexColor(0.35, 0.35, 0.35, 1)
                headerTexts[ci]:SetTextColor(0.7, 0.7, 0.7)
            end
        end
    end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    -- Alternating row background
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    if index % 2 == 0 then
        highlight:SetColorTexture(1, 1, 1, 0.03)
    else
        highlight:SetColorTexture(1, 1, 1, 0.05)
    end

    -- Mouseover highlight
    local hoverTex = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    hoverTex:SetAllPoints()
    hoverTex:SetColorTexture(1, 1, 1, 0.1)
    hoverTex:Hide()
    row:EnableMouse(true)
    row._shiftShown = false
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnEnter", function(self)
        hoverTex:Show()
        if IsShiftKeyDown() and self._member then
            KS.ShowMemberTooltip(self, self._member)
            self._shiftShown = true
        elseif self._member then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffccccccClick|r to inspect", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("|cffccccccShift-hover|r for details", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        hoverTex:Hide()
        GameTooltip:Hide()
        self._shiftShown = false
    end)
    row:SetScript("OnClick", function(self)
        if self._member then
            KS.ShowCharacterDetail(self._member, "roster")
        end
    end)
    row:SetScript("OnUpdate", function(self)
        if not self:IsMouseOver() then return end
        local shiftDown = IsShiftKeyDown()
        if shiftDown and not self._shiftShown and self._member then
            KS.ShowMemberTooltip(self, self._member)
            self._shiftShown = true
        elseif not shiftDown and self._shiftShown then
            GameTooltip:Hide()
            self._shiftShown = false
        end
    end)

    row.texts = {}
    for ci, col in ipairs(COLUMNS) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local x = GetColumnX(ci)
        if col.align == "LEFT" then
            fs:SetPoint("LEFT", x, 0)
        elseif col.align == "RIGHT" then
            fs:SetPoint("LEFT", x, 0)
            fs:SetWidth(col.width - 4)
            fs:SetJustifyH("RIGHT")
        else
            fs:SetPoint("LEFT", x, 0)
            fs:SetWidth(col.width)
            fs:SetJustifyH("CENTER")
        end
        row.texts[ci] = fs
    end

    -- Role icon
    row.roleIcon = row:CreateTexture(nil, "OVERLAY")
    row.roleIcon:SetSize(14, 14)
    row.roleIcon:SetPoint("CENTER", row.texts[2], "CENTER", 0, 0)

    return row
end

function KS.CreateRosterView(parent)
    ---------------------------------------------------------------------------
    -- Toolbar: filter dropdowns + member count
    ---------------------------------------------------------------------------
    local toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", 0, 0)
    toolbar:SetHeight(TOOLBAR_HEIGHT)

    -- Score filter
    local scoreLabel = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scoreLabel:SetPoint("LEFT", 4, 0)
    scoreLabel:SetText("Score:")

    local ddItems = {}
    for i, thresh in ipairs(KS.SCORE_THRESHOLDS) do
        table.insert(ddItems, { text = thresh.label, value = i })
    end

    local filterDD = KS.CreateDropdown(toolbar, 100, 22)
    filterDD:SetPoint("LEFT", scoreLabel, "RIGHT", 4, 0)
    filterDD:SetItems(ddItems)
    filterDD:SetSelected(KeySorterDB.filterIdx or 1)
    filterDD:SetOnSelect(function(value)
        filterIdx = value
        KeySorterDB.filterIdx = value
        KS.UpdateRosterView()
    end)

    -- Role filter
    local roleLabel = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    roleLabel:SetPoint("LEFT", filterDD, "RIGHT", 8, 0)
    roleLabel:SetText("Role:")

    local roleDD = KS.CreateDropdown(toolbar, 80, 22)
    roleDD:SetPoint("LEFT", roleLabel, "RIGHT", 4, 0)
    roleDD:SetItems({
        { text = "All", value = "ALL" },
        { text = "Tank", value = "TANK" },
        { text = "Healer", value = "HEALER" },
        { text = "DPS", value = "DAMAGER" },
    })
    roleDD:SetSelected("ALL")
    roleDD:SetOnSelect(function(value)
        roleFilter = value
        KS.UpdateRosterView()
    end)

    -- Utility filter
    local utilLabel = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    utilLabel:SetPoint("LEFT", roleDD, "RIGHT", 8, 0)
    utilLabel:SetText("Utility:")

    local utilDD = KS.CreateDropdown(toolbar, 80, 22)
    utilDD:SetPoint("LEFT", utilLabel, "RIGHT", 4, 0)
    utilDD:SetItems({
        { text = "All", value = "ALL" },
        { text = "BRez", value = "BREZ" },
        { text = "Lust", value = "LUST" },
        { text = "Shroud", value = "SHROUD" },
    })
    utilDD:SetSelected("ALL")
    utilDD:SetOnSelect(function(value)
        utilityFilter = value
        KS.UpdateRosterView()
    end)

    -- Timed runs filter
    local timedLabel = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timedLabel:SetPoint("LEFT", utilDD, "RIGHT", 8, 0)
    timedLabel:SetText("Timed:")

    local timedDD = KS.CreateDropdown(toolbar, 62, 22)
    timedDD:SetPoint("LEFT", timedLabel, "RIGHT", 4, 0)
    timedDD:SetItems({
        { text = "All", value = 0 },
        { text = "5+", value = 5 },
        { text = "10+", value = 10 },
        { text = "15+", value = 15 },
        { text = "20+", value = 20 },
        { text = "25+", value = 25 },
        { text = "30+", value = 30 },
        { text = "35+", value = 35 },
        { text = "40+", value = 40 },
    })
    timedDD:SetSelected(0)
    timedDD:SetOnSelect(function(value)
        timedFilter = value
        KS.UpdateRosterView()
    end)

    -- Member count (right side of toolbar)
    local countText = toolbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("RIGHT", -4, 0)
    countText:SetTextColor(0.6, 0.6, 0.6)
    KS._rosterCountText = countText

    ---------------------------------------------------------------------------
    -- Column headers with sort arrows
    ---------------------------------------------------------------------------
    local headerBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    headerBar:SetPoint("TOPLEFT", 0, -TOOLBAR_HEIGHT)
    headerBar:SetPoint("TOPRIGHT", 0, -TOOLBAR_HEIGHT)
    headerBar:SetHeight(HEADER_HEIGHT)
    headerBar:SetBackdrop(KS.BACKDROP_PANEL)
    headerBar:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    headerBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    for ci, col in ipairs(COLUMNS) do
        local x = GetColumnX(ci)

        if col.sortable then
            local btn = CreateFrame("Button", nil, headerBar)
            btn:SetPoint("LEFT", x, 0)
            btn:SetSize(col.width, HEADER_HEIGHT)

            -- Column label
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", 2, 0)
            text:SetText(col.label)
            text:SetTextColor(0.7, 0.7, 0.7)
            headerTexts[ci] = text

            -- Sort arrow texture (after label with padding)
            local arrow = btn:CreateTexture(nil, "OVERLAY")
            arrow:SetSize(10, 10)
            arrow:SetPoint("LEFT", text, "RIGHT", 4, 0)
            arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
            arrow:SetTexCoord(0, 0.5625, 0, 1)
            arrow:SetVertexColor(0.35, 0.35, 0.35, 1)
            headerArrows[ci] = arrow

            -- Hover: brighten
            btn:SetScript("OnEnter", function()
                text:SetTextColor(1, 1, 1)
                arrow:SetVertexColor(0.7, 0.7, 0.7, 1)
            end)
            btn:SetScript("OnLeave", function()
                UpdateSortIndicators()
            end)

            btn:SetScript("OnClick", function()
                if sortField == col.key then
                    sortAsc = not sortAsc
                else
                    sortField = col.key
                    sortAsc = false
                end
                UpdateSortIndicators()
                KS.UpdateRosterView()
            end)
        else
            -- Non-sortable: dimmed label, no arrow
            local text = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", x + 2, 0)
            text:SetText(col.label)
            text:SetTextColor(0.4, 0.4, 0.4)
            headerTexts[ci] = text
        end
    end

    UpdateSortIndicators()

    ---------------------------------------------------------------------------
    -- Scroll area
    ---------------------------------------------------------------------------
    scrollFrame, scrollChild = KS.CreateScrollFrame(parent, "KeySorterRosterScroll")
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", 0, -(TOOLBAR_HEIGHT + HEADER_HEIGHT))
    scrollFrame:SetPoint("BOTTOMRIGHT", -14, 0)

    filterIdx = KeySorterDB.filterIdx or 1
end

function KS.UpdateRosterView()
    if not scrollChild then return end

    -- Hide existing rows
    for _, row in ipairs(rows) do
        row:Hide()
        row._member = nil
    end

    -- Filter and sort roster
    local filtered = {}
    for _, member in ipairs(KS.roster) do
        if PassesFilter(member) then
            table.insert(filtered, member)
        end
    end
    table.sort(filtered, CompareMembers)

    -- Update count
    if KS._rosterCountText then
        KS._rosterCountText:SetText(format("%d / %d members", #filtered, #KS.roster))
    end

    -- Create/update rows
    for i, member in ipairs(filtered) do
        if not rows[i] then
            rows[i] = CreateRow(scrollChild, i)
        end
        local row = rows[i]
        row:Show()
        row._member = member

        -- Name (class colored)
        local classColor = KS.CLASS_COLORS[member.classFile]
        if classColor then
            row.texts[1]:SetText(format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, member.name))
        else
            row.texts[1]:SetText(member.name)
        end

        -- Role icon
        row.texts[2]:SetText("")
        local roleAtlas = KS.ROLE_ICONS[member.role]
        if roleAtlas then
            row.roleIcon:SetAtlas(roleAtlas)
            row.roleIcon:Show()
        else
            row.roleIcon:Hide()
        end

        -- Score (colored by M+ rating)
        local sr, sg, sb = GetScoreColor(member.score)
        row.texts[3]:SetText(format("|cff%02x%02x%02x%d|r", sr * 255, sg * 255, sb * 255, member.score))

        -- Item level (colored by quality gradient)
        local ilvl = member.ilvl or 0
        if ilvl > 0 then
            local ir, ig, ib = GetIlvlColor(ilvl)
            row.texts[4]:SetText(format("|cff%02x%02x%02x%d|r", ir * 255, ig * 255, ib * 255, ilvl))
        else
            row.texts[4]:SetText("|cff666666—|r")
        end

        -- Average key level across all dungeons
        row.texts[5]:SetText(format("%.1f", member.avgKeyLevel))

        -- Timed runs
        row.texts[6]:SetText("|cff00cc00" .. tostring(member.numTimed or 0) .. "|r")

        -- Untimed runs
        row.texts[7]:SetText("|cffcc0000" .. tostring(member.numUntimed or 0) .. "|r")

        -- Total runs
        row.texts[8]:SetText(tostring(member.numRuns))

        -- Class utilities (BR = battle rez, BL = bloodlust, SH = shroud)
        row.texts[9]:SetText(GetUtilityString(member))
    end

    scrollChild:SetHeight(math.max(#filtered * ROW_HEIGHT, 1))
end
