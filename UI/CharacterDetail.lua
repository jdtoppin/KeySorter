local addonName, KS = ...

---------------------------------------------------------------------------
-- Character Detail View
-- Lazy-loaded overlay that shows full character info when a member is clicked.
-- Back button returns to the previous tab.
---------------------------------------------------------------------------

local detailFrame       -- overlay frame (created once, reused)
local scrollFrame, scrollChild
local previousTab       -- which tab to return to
local contentWidgets = {} -- widgets created inside scrollChild (cleared on refresh)

local SECTION_GAP = 12
local LINE_HEIGHT = 18
local LABEL_WIDTH = 120
local COL_MIN_WIDTH = 280  -- minimum width before falling back to single column

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function GetClassColor(classFile)
    local c = KS.CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
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

local function GetIlvlColor(ilvl)
    local anchors = KS.ILVL_COLORS
    if not anchors or #anchors == 0 then return 1, 1, 1 end
    if ilvl <= anchors[1].ilvl then return anchors[1].r, anchors[1].g, anchors[1].b end
    if ilvl >= anchors[#anchors].ilvl then return anchors[#anchors].r, anchors[#anchors].g, anchors[#anchors].b end
    for i = 2, #anchors do
        if ilvl <= anchors[i].ilvl then
            local lo, hi = anchors[i - 1], anchors[i]
            local t = (ilvl - lo.ilvl) / (hi.ilvl - lo.ilvl)
            return lo.r + t * (hi.r - lo.r), lo.g + t * (hi.g - lo.g), lo.b + t * (hi.b - lo.b)
        end
    end
    return 1, 1, 1
end

local function GetDungeonName(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name then return name end
    end
    return KS.DUNGEON_NAMES[mapID] or ("Dungeon " .. mapID)
end

local ROLE_LABELS = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

---------------------------------------------------------------------------
-- Build detail content (called each time a member is selected)
---------------------------------------------------------------------------
local function ClearContent()
    for _, w in ipairs(contentWidgets) do
        w:Hide()
        w:SetParent(nil)
    end
    wipe(contentWidgets)
end

-- xBase: horizontal offset for the column (0 for left, half-width for right)
local function AddSectionHeader(yOffset, text, xBase, colWidth)
    xBase = xBase or 0
    local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", xBase, yOffset)
    fs:SetText(text)
    fs:SetTextColor(0, 0.8, 1)
    table.insert(contentWidgets, fs)

    local line = scrollChild:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", xBase, yOffset - 14)
    line:SetWidth(colWidth or 300)
    line:SetHeight(1)
    line:SetColorTexture(0.25, 0.25, 0.25, 1)
    table.insert(contentWidgets, line)

    return yOffset - 20
end

local function AddLabelValue(yOffset, label, value, valueR, valueG, valueB, xBase)
    xBase = xBase or 0
    local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", xBase + 8, yOffset)
    lbl:SetWidth(LABEL_WIDTH)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)
    lbl:SetTextColor(0.6, 0.6, 0.6)
    table.insert(contentWidgets, lbl)

    local val = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOPLEFT", xBase + LABEL_WIDTH + 8, yOffset)
    val:SetJustifyH("LEFT")
    val:SetText(value)
    val:SetTextColor(valueR or 1, valueG or 1, valueB or 1)
    table.insert(contentWidgets, val)

    return yOffset - LINE_HEIGHT
end

local function BuildContent(member)
    ClearContent()

    -- Determine if we have room for two columns
    local totalWidth = scrollChild:GetWidth()
    if totalWidth < 1 then totalWidth = 500 end
    local twoCol = totalWidth >= (COL_MIN_WIDTH * 2)
    local colWidth = twoCol and math.floor(totalWidth / 2) or totalWidth
    local leftX = 0
    local rightX = twoCol and colWidth or 0

    -- =====================================================================
    -- LEFT COLUMN: Overview, Utilities, Key Thresholds
    -- =====================================================================
    local yL = 0

    yL = AddSectionHeader(yL, "Overview", leftX, colWidth - 16)
    local cr, cg, cb = GetClassColor(member.classFile)
    yL = AddLabelValue(yL, "Name", member.name, cr, cg, cb, leftX)

    local classDisplay = member.classFile and member.classFile:sub(1, 1) .. member.classFile:sub(2):lower() or "Unknown"
    if member.classFile == "DEATHKNIGHT" then classDisplay = "Death Knight"
    elseif member.classFile == "DEMONHUNTER" then classDisplay = "Demon Hunter" end
    yL = AddLabelValue(yL, "Class", classDisplay, cr, cg, cb, leftX)
    yL = AddLabelValue(yL, "Role", ROLE_LABELS[member.role] or member.role or "Unknown", nil, nil, nil, leftX)

    local sr, sg, sb = GetScoreColor(member.score)
    yL = AddLabelValue(yL, "M+ Score", tostring(member.score), sr, sg, sb, leftX)

    if member.previousScore and member.previousScore > 0 then
        local pr, pg, pb = GetScoreColor(member.previousScore)
        yL = AddLabelValue(yL, "Prev Season", tostring(member.previousScore), pr, pg, pb, leftX)
    end

    if member.ilvl and member.ilvl > 0 then
        local ir, ig, ib = GetIlvlColor(member.ilvl)
        yL = AddLabelValue(yL, "Item Level", tostring(member.ilvl), ir, ig, ib, leftX)
    else
        yL = AddLabelValue(yL, "Item Level", "Unknown", 0.5, 0.5, 0.5, leftX)
    end

    yL = AddLabelValue(yL, "Avg Key Level", format("%.1f", member.avgKeyLevel or 0), nil, nil, nil, leftX)
    yL = AddLabelValue(yL, "Data Source", member.dataSource == "raiderio" and "Raider.IO" or member.dataSource == "blizzard" and "Blizzard API" or "None", 0.5, 0.5, 0.5, leftX)

    -- Utilities
    yL = yL - SECTION_GAP
    yL = AddSectionHeader(yL, "Utilities", leftX, colWidth - 16)
    local function utilColor(has) return has and 0 or 0.5, has and 0.8 or 0.5, has and 0 or 0.5 end
    yL = AddLabelValue(yL, "Battle Rez", member.hasBrez and "Yes" or "No", utilColor(member.hasBrez), leftX)
    yL = AddLabelValue(yL, "Bloodlust", member.hasLust and "Yes" or "No", utilColor(member.hasLust), leftX)
    yL = AddLabelValue(yL, "Shroud", member.hasShroud and "Yes" or "No", utilColor(member.hasShroud), leftX)

    -- Key Thresholds
    if member.dataSource == "raiderio" or (member.keystoneFivePlus and member.keystoneFivePlus > 0) then
        yL = yL - SECTION_GAP
        yL = AddSectionHeader(yL, "Timed Key Thresholds", leftX, colWidth - 16)
        yL = AddLabelValue(yL, "+5 Timed", tostring(member.keystoneFivePlus or 0), nil, nil, nil, leftX)
        yL = AddLabelValue(yL, "+10 Timed", tostring(member.keystoneTenPlus or 0), nil, nil, nil, leftX)
        yL = AddLabelValue(yL, "+15 Timed", tostring(member.keystoneFifteenPlus or 0), nil, nil, nil, leftX)
        yL = AddLabelValue(yL, "+20 Timed", tostring(member.keystoneTwentyPlus or 0), nil, nil, nil, leftX)
    end

    -- =====================================================================
    -- RIGHT COLUMN (or below left if single column): Run Summary, Dungeons
    -- =====================================================================
    local yR = twoCol and 0 or (yL - SECTION_GAP)
    local cX = rightX  -- column x offset

    yR = AddSectionHeader(yR, "Run Summary", cX, colWidth - 16)
    yR = AddLabelValue(yR, "Total Runs", tostring(member.numRuns or 0), nil, nil, nil, cX)
    yR = AddLabelValue(yR, "Timed Runs", tostring(member.numTimed or 0), 0, 0.8, 0, cX)
    yR = AddLabelValue(yR, "Untimed Runs", tostring(member.numUntimed or 0), 0.8, 0, 0, cX)

    ---------------------------------------------------------------------------
    -- Dungeon Breakdown (right column continued)
    ---------------------------------------------------------------------------
    if member.runs and next(member.runs) then
        yR = yR - SECTION_GAP
        yR = AddSectionHeader(yR, "Dungeon Breakdown", cX, colWidth - 16)

        -- Dungeon table column offsets (relative to cX)
        local dNameX = cX + 8
        local dLevelX = cX + 150
        local dStatusX = cX + 200
        local dScoreX = cX + 260

        -- Column headers
        local function AddDungeonHeader(label, xPos, w)
            local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", xPos, yR)
            fs:SetWidth(w)
            fs:SetJustifyH("CENTER")
            fs:SetText(label)
            fs:SetTextColor(0.5, 0.5, 0.5)
            table.insert(contentWidgets, fs)
        end

        local nameHdr = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameHdr:SetPoint("TOPLEFT", dNameX, yR)
        nameHdr:SetWidth(140)
        nameHdr:SetJustifyH("LEFT")
        nameHdr:SetText("Dungeon")
        nameHdr:SetTextColor(0.5, 0.5, 0.5)
        table.insert(contentWidgets, nameHdr)
        AddDungeonHeader("Level", dLevelX, 46)
        AddDungeonHeader("Status", dStatusX, 56)
        AddDungeonHeader("Score", dScoreX, 46)
        yR = yR - LINE_HEIGHT

        local shown = {}
        local rowIdx = 0
        local function AddDungeonRow(mapID, run)
            local name = GetDungeonName(mapID)
            rowIdx = rowIdx + 1

            local rowBg = scrollChild:CreateTexture(nil, "BACKGROUND")
            rowBg:SetPoint("TOPLEFT", cX + 4, yR + 1)
            rowBg:SetWidth(colWidth - 12)
            rowBg:SetHeight(LINE_HEIGHT)
            rowBg:SetColorTexture(1, 1, 1, rowIdx % 2 == 0 and 0.03 or 0.05)
            table.insert(contentWidgets, rowBg)

            local nameFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameFs:SetPoint("TOPLEFT", dNameX, yR)
            nameFs:SetWidth(140)
            nameFs:SetJustifyH("LEFT")
            nameFs:SetText(name)
            nameFs:SetTextColor(0.85, 0.85, 0.85)
            table.insert(contentWidgets, nameFs)

            local levelFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            levelFs:SetPoint("TOPLEFT", dLevelX, yR)
            levelFs:SetWidth(46)
            levelFs:SetJustifyH("CENTER")
            levelFs:SetText("+" .. run.level)
            table.insert(contentWidgets, levelFs)

            local statusFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusFs:SetPoint("TOPLEFT", dStatusX, yR)
            statusFs:SetWidth(56)
            statusFs:SetJustifyH("CENTER")
            if run.timed then
                statusFs:SetText("Timed")
                statusFs:SetTextColor(0, 0.8, 0)
            else
                statusFs:SetText("Untimed")
                statusFs:SetTextColor(0.8, 0, 0)
            end
            table.insert(contentWidgets, statusFs)

            local scoreFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            scoreFs:SetPoint("TOPLEFT", dScoreX, yR)
            scoreFs:SetWidth(46)
            scoreFs:SetJustifyH("CENTER")
            if run.score then
                scoreFs:SetText(tostring(run.score))
                scoreFs:SetTextColor(0.7, 0.7, 0.7)
            else
                scoreFs:SetText("—")
                scoreFs:SetTextColor(0.4, 0.4, 0.4)
            end
            table.insert(contentWidgets, scoreFs)

            yR = yR - LINE_HEIGHT
        end

        for _, mapID in ipairs(KS.DUNGEON_IDS) do
            local run = member.runs[mapID]
            if run then
                shown[mapID] = true
                AddDungeonRow(mapID, run)
            end
        end
        for mapID, run in pairs(member.runs) do
            if not shown[mapID] then
                AddDungeonRow(mapID, run)
            end
        end

        -- Dungeons with no data
        for _, mapID in ipairs(KS.DUNGEON_IDS) do
            if not member.runs[mapID] then
                rowIdx = rowIdx + 1
                local name = GetDungeonName(mapID)
                local nameFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                nameFs:SetPoint("TOPLEFT", dNameX, yR)
                nameFs:SetWidth(140)
                nameFs:SetJustifyH("LEFT")
                nameFs:SetText(name)
                nameFs:SetTextColor(0.35, 0.35, 0.35)
                table.insert(contentWidgets, nameFs)

                local noData = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                noData:SetPoint("TOPLEFT", dLevelX, yR)
                noData:SetText("No data")
                noData:SetTextColor(0.35, 0.35, 0.35)
                table.insert(contentWidgets, noData)

                yR = yR - LINE_HEIGHT
            end
        end
    else
        yR = yR - SECTION_GAP
        yR = AddSectionHeader(yR, "Dungeon Breakdown", cX, colWidth - 16)
        local noRuns = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noRuns:SetPoint("TOPLEFT", cX + 8, yR)
        noRuns:SetText("No dungeon runs recorded this season.")
        noRuns:SetTextColor(0.5, 0.5, 0.5)
        table.insert(contentWidgets, noRuns)
        yR = yR - LINE_HEIGHT
    end

    -- Total height is the deeper of the two columns
    local totalY = math.min(yL, yR)
    scrollChild:SetHeight(math.abs(totalY) + SECTION_GAP)
end

---------------------------------------------------------------------------
-- Create the detail overlay frame (once)
---------------------------------------------------------------------------
local function EnsureDetailFrame()
    if detailFrame then return end

    detailFrame = CreateFrame("Frame", nil, KS.mainFrame, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", KS.contentArea, "TOPLEFT", 0, 0)
    detailFrame:SetPoint("BOTTOMRIGHT", KS.mainFrame, "BOTTOMRIGHT", -1, 1)
    detailFrame:SetFrameLevel(KS.mainFrame:GetFrameLevel() + 10)
    detailFrame:SetBackdrop(KS.BACKDROP)
    detailFrame:SetBackdropColor(0.08, 0.08, 0.08, 1)
    detailFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    detailFrame:EnableMouse(true)  -- Block clicks from reaching frames behind
    detailFrame:Hide()

    -- Back button
    local backBtn = KS.CreateButton(detailFrame, "< Back", "widget", 60, 22)
    backBtn:SetAnimatedHighlight(true)
    backBtn:SetPoint("TOPLEFT", 8, -6)
    backBtn:SetOnClick(function()
        KS.HideCharacterDetail()
    end)

    -- Character name header (set per-member)
    local nameHeader = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameHeader:SetPoint("LEFT", backBtn, "RIGHT", 12, 0)
    detailFrame._nameHeader = nameHeader

    -- Role icon next to name
    local roleIcon = detailFrame:CreateTexture(nil, "OVERLAY")
    roleIcon:SetSize(16, 16)
    roleIcon:SetPoint("LEFT", nameHeader, "RIGHT", 6, 0)
    detailFrame._roleIcon = roleIcon

    -- Scroll area below the header bar
    local scrollParent = CreateFrame("Frame", nil, detailFrame)
    scrollParent:SetPoint("TOPLEFT", 8, -32)
    scrollParent:SetPoint("BOTTOMRIGHT", -8, 8)

    scrollFrame, scrollChild = KS.CreateScrollFrame(scrollParent, "KeySorterCharDetailScroll")
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
function KS.ShowCharacterDetail(member, fromTab)
    if not member then return end
    if not KS.mainFrame then return end

    GameTooltip:Hide()
    KS.HideTooltip()
    EnsureDetailFrame()

    previousTab = fromTab or "roster"

    -- Set header
    local cr, cg, cb = GetClassColor(member.classFile)
    detailFrame._nameHeader:SetText(member.name)
    detailFrame._nameHeader:SetTextColor(cr, cg, cb)

    local roleAtlas = KS.ROLE_ICONS[member.role]
    if roleAtlas then
        detailFrame._roleIcon:SetAtlas(roleAtlas)
        detailFrame._roleIcon:Show()
    else
        detailFrame._roleIcon:Hide()
    end

    -- Build the detail content (lazy — only now)
    BuildContent(member)

    detailFrame:Show()
end

function KS.HideCharacterDetail()
    if detailFrame then
        detailFrame:Hide()
        ClearContent()
    end
    -- Switch back to previous tab
    if previousTab and KS.SetTab then
        KS.SetTab(previousTab)
    end
end
