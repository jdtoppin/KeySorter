local addonName, KS = ...

local ROW_HEIGHT = 20
local HEADER_HEIGHT = 24
local FILTER_HEIGHT = 28

local sortField = "score"
local sortAsc = false
local filterIdx = 1

local scrollFrame, scrollChild
local rows = {}
local filterButtons = {}

local COLUMNS = {
    { key = "name",       label = "Name",    width = 140, align = "LEFT" },
    { key = "role",       label = "Role",    width = 50,  align = "CENTER" },
    { key = "score",      label = "Score",   width = 70,  align = "RIGHT" },
    { key = "avgKeyLevel", label = "Avg Key", width = 60,  align = "RIGHT" },
    { key = "numRuns",    label = "Runs",    width = 50,  align = "RIGHT" },
    { key = "utilities",  label = "Utility", width = 80,  align = "CENTER" },
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
    if filterIdx == 1 then return true end
    local thresh = KS.SCORE_THRESHOLDS[filterIdx]
    return member.score >= thresh.min and member.score <= thresh.max
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

local function GetUtilityString(member)
    local parts = {}
    if member.hasBrez then table.insert(parts, "|cff00cc00BR|r") end
    if member.hasLust then table.insert(parts, "|cffcc0000BL|r") end
    if member.hasShroud then table.insert(parts, "|cff8800ccSH|r") end
    return table.concat(parts, " ")
end

local function UpdateFilterHighlights()
    for i, btn in ipairs(filterButtons) do
        if i == filterIdx then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
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
    row:SetScript("OnEnter", function() hoverTex:Show() end)
    row:SetScript("OnLeave", function() hoverTex:Hide() end)

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
    -- Filter buttons
    local filterBar = CreateFrame("Frame", nil, parent)
    filterBar:SetPoint("TOPLEFT", 0, 0)
    filterBar:SetPoint("TOPRIGHT", 0, 0)
    filterBar:SetHeight(FILTER_HEIGHT)

    local filterLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("LEFT", 4, 0)
    filterLabel:SetText("Filter:")

    local prevBtn
    for i, thresh in ipairs(KS.SCORE_THRESHOLDS) do
        local btn = KS.CreateButton(filterBar, thresh.label, "widget", 56, 20)
        if prevBtn then
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
        else
            btn:SetPoint("LEFT", filterLabel, "RIGHT", 6, 0)
        end
        btn:SetOnClick(function()
            filterIdx = i
            KeySorterDB.filterIdx = i
            UpdateFilterHighlights()
            KS.UpdateRosterView()
        end)
        filterButtons[i] = btn
        prevBtn = btn
    end

    -- Column headers
    local headerBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    headerBar:SetPoint("TOPLEFT", 0, -FILTER_HEIGHT)
    headerBar:SetPoint("TOPRIGHT", 0, -FILTER_HEIGHT)
    headerBar:SetHeight(HEADER_HEIGHT)
    headerBar:SetBackdrop(KS.BACKDROP_PANEL)
    headerBar:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    headerBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    for ci, col in ipairs(COLUMNS) do
        local sortable = col.key ~= "utilities" and col.key ~= "role"
        local x = GetColumnX(ci)

        if sortable then
            local btn = KS.CreateButton(headerBar, col.label, "gray_hover", col.width, HEADER_HEIGHT)
            btn:SetPoint("LEFT", x, 0)
            btn:SetOnClick(function()
                if sortField == col.key then
                    sortAsc = not sortAsc
                else
                    sortField = col.key
                    sortAsc = false
                end
                KS.UpdateRosterView()
            end)
        else
            local text = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", x + 2, 0)
            text:SetText(col.label)
        end
    end

    -- Custom scroll frame (clean thin scrollbar)
    scrollFrame, scrollChild = KS.CreateScrollFrame(parent, "KeySorterRosterScroll")
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", 0, -(FILTER_HEIGHT + HEADER_HEIGHT))
    scrollFrame:SetPoint("BOTTOMRIGHT", -10, 0)

    filterIdx = KeySorterDB.filterIdx or 1
    UpdateFilterHighlights()
end

function KS.UpdateRosterView()
    if not scrollChild then return end

    -- Hide existing rows
    for _, row in ipairs(rows) do
        row:Hide()
    end

    -- Filter and sort roster
    local filtered = {}
    for _, member in ipairs(KS.roster) do
        if PassesFilter(member) then
            table.insert(filtered, member)
        end
    end
    table.sort(filtered, CompareMembers)

    -- Create/update rows
    for i, member in ipairs(filtered) do
        if not rows[i] then
            rows[i] = CreateRow(scrollChild, i)
        end
        local row = rows[i]
        row:Show()

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

        -- Average key level across all dungeons
        row.texts[4]:SetText(format("%.1f", member.avgKeyLevel))

        -- Number of dungeon runs completed
        row.texts[5]:SetText(tostring(member.numRuns))

        -- Class utilities (BR = battle rez, BL = bloodlust, SH = shroud)
        row.texts[6]:SetText(GetUtilityString(member))
    end

    scrollChild:SetHeight(#filtered * ROW_HEIGHT)
end
