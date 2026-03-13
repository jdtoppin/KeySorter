local addonName, KS = ...

local ROW_HEIGHT = 20
local HEADER_HEIGHT = 24
local FILTER_HEIGHT = 28

local sortField = "score"
local sortAsc = false
local filterIdx = 1

local scrollFrame, scrollChild
local rows = {}
local headerButtons = {}

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
    -- Fallback gradient
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

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    -- Highlight
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.05)
    if index % 2 == 0 then
        highlight:SetColorTexture(1, 1, 1, 0.03)
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
            fs:SetPoint("RIGHT", -(GetColumnX(#COLUMNS + 1) - x - col.width + 4), 0)
            fs:SetPoint("LEFT", x, 0)
            fs:SetJustifyH("RIGHT")
        else
            fs:SetPoint("LEFT", x, 0)
            fs:SetWidth(col.width)
            fs:SetJustifyH("CENTER")
        end
        row.texts[ci] = fs
    end

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
        local btn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
        btn:SetSize(60, 20)
        if prevBtn then
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
        else
            btn:SetPoint("LEFT", filterLabel, "RIGHT", 6, 0)
        end
        btn:SetText(thresh.label)
        btn:SetScript("OnClick", function()
            filterIdx = i
            KeySorterDB.filterIdx = i
            KS.UpdateRosterView()
        end)
        prevBtn = btn
    end

    -- Column headers
    local headerBar = CreateFrame("Frame", nil, parent)
    headerBar:SetPoint("TOPLEFT", 0, -FILTER_HEIGHT)
    headerBar:SetPoint("TOPRIGHT", 0, -FILTER_HEIGHT)
    headerBar:SetHeight(HEADER_HEIGHT)

    local headerBg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    for ci, col in ipairs(COLUMNS) do
        local btn = CreateFrame("Button", nil, headerBar)
        local x = GetColumnX(ci)
        btn:SetPoint("LEFT", x, 0)
        btn:SetSize(col.width, HEADER_HEIGHT)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", 2, 0)
        text:SetText(col.label)
        text:SetJustifyH(col.align)

        if col.key ~= "utilities" and col.key ~= "role" then
            btn:SetScript("OnClick", function()
                if sortField == col.key then
                    sortAsc = not sortAsc
                else
                    sortField = col.key
                    sortAsc = false
                end
                KS.UpdateRosterView()
            end)
            btn:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
        end

        headerButtons[ci] = btn
    end

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", "KeySorterRosterScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -(FILTER_HEIGHT + HEADER_HEIGHT))
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1) -- will be updated
    scrollFrame:SetScrollChild(scrollChild)

    -- Defer width update
    scrollFrame:SetScript("OnSizeChanged", function(self, w, h)
        scrollChild:SetWidth(w)
    end)

    filterIdx = KeySorterDB.filterIdx or 1
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

        -- Score (colored)
        local sr, sg, sb = GetScoreColor(member.score)
        row.texts[3]:SetText(format("|cff%02x%02x%02x%d|r", sr * 255, sg * 255, sb * 255, member.score))

        -- Avg key level
        row.texts[4]:SetText(format("%.1f", member.avgKeyLevel))

        -- Runs
        row.texts[5]:SetText(tostring(member.numRuns))

        -- Utilities
        row.texts[6]:SetText(GetUtilityString(member))
    end

    scrollChild:SetHeight(#filtered * ROW_HEIGHT)
end
