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

local SECTION_GAP = 16
local LINE_HEIGHT = 18
local LABEL_WIDTH = 140

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

local function AddSectionHeader(yOffset, text)
    local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 0, yOffset)
    fs:SetText(text)
    fs:SetTextColor(0, 0.8, 1)
    table.insert(contentWidgets, fs)

    local line = scrollChild:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 0, yOffset - 14)
    line:SetPoint("RIGHT", -8, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.25, 0.25, 0.25, 1)
    table.insert(contentWidgets, line)

    return yOffset - 20
end

local function AddLabelValue(yOffset, label, value, valueR, valueG, valueB)
    local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 8, yOffset)
    lbl:SetWidth(LABEL_WIDTH)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)
    lbl:SetTextColor(0.6, 0.6, 0.6)
    table.insert(contentWidgets, lbl)

    local val = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOPLEFT", LABEL_WIDTH + 8, yOffset)
    val:SetJustifyH("LEFT")
    val:SetText(value)
    val:SetTextColor(valueR or 1, valueG or 1, valueB or 1)
    table.insert(contentWidgets, val)

    return yOffset - LINE_HEIGHT
end

local function BuildContent(member)
    ClearContent()
    local y = 0

    ---------------------------------------------------------------------------
    -- Header: Name, Class, Role
    ---------------------------------------------------------------------------
    y = AddSectionHeader(y, "Overview")
    local cr, cg, cb = GetClassColor(member.classFile)
    y = AddLabelValue(y, "Name", member.name, cr, cg, cb)

    local classDisplay = member.classFile and member.classFile:sub(1, 1) .. member.classFile:sub(2):lower() or "Unknown"
    -- Clean up multi-word class names
    classDisplay = classDisplay:gsub("deathknight", "Death Knight"):gsub("demonhunter", "Demon Hunter")
    if member.classFile == "DEATHKNIGHT" then classDisplay = "Death Knight"
    elseif member.classFile == "DEMONHUNTER" then classDisplay = "Demon Hunter" end
    y = AddLabelValue(y, "Class", classDisplay, cr, cg, cb)

    local roleAtlas = KS.ROLE_ICONS[member.role]
    y = AddLabelValue(y, "Role", ROLE_LABELS[member.role] or member.role or "Unknown")

    -- Score
    local sr, sg, sb = GetScoreColor(member.score)
    y = AddLabelValue(y, "M+ Score", tostring(member.score), sr, sg, sb)

    -- Previous season score
    if member.previousScore and member.previousScore > 0 then
        local pr, pg, pb = GetScoreColor(member.previousScore)
        y = AddLabelValue(y, "Previous Season", tostring(member.previousScore), pr, pg, pb)
    end

    -- Item level
    if member.ilvl and member.ilvl > 0 then
        local ir, ig, ib = GetIlvlColor(member.ilvl)
        y = AddLabelValue(y, "Item Level", tostring(member.ilvl), ir, ig, ib)
    else
        y = AddLabelValue(y, "Item Level", "Unknown", 0.5, 0.5, 0.5)
    end

    y = AddLabelValue(y, "Avg Key Level", format("%.1f", member.avgKeyLevel or 0))
    y = AddLabelValue(y, "Data Source", member.dataSource == "raiderio" and "Raider.IO" or member.dataSource == "blizzard" and "Blizzard API" or "None", 0.5, 0.5, 0.5)

    ---------------------------------------------------------------------------
    -- Utilities
    ---------------------------------------------------------------------------
    y = y - SECTION_GAP
    y = AddSectionHeader(y, "Utilities")
    local function utilColor(has) return has and 0 or 0.5, has and 0.8 or 0.5, has and 0 or 0.5 end
    y = AddLabelValue(y, "Battle Rez", member.hasBrez and "Yes" or "No", utilColor(member.hasBrez))
    y = AddLabelValue(y, "Bloodlust", member.hasLust and "Yes" or "No", utilColor(member.hasLust))
    y = AddLabelValue(y, "Shroud", member.hasShroud and "Yes" or "No", utilColor(member.hasShroud))

    ---------------------------------------------------------------------------
    -- Key Threshold Runs (Raider.IO data)
    ---------------------------------------------------------------------------
    if member.dataSource == "raiderio" or (member.keystoneFivePlus and member.keystoneFivePlus > 0) then
        y = y - SECTION_GAP
        y = AddSectionHeader(y, "Timed Key Thresholds")
        y = AddLabelValue(y, "+5 Timed", tostring(member.keystoneFivePlus or 0))
        y = AddLabelValue(y, "+10 Timed", tostring(member.keystoneTenPlus or 0))
        y = AddLabelValue(y, "+15 Timed", tostring(member.keystoneFifteenPlus or 0))
        y = AddLabelValue(y, "+20 Timed", tostring(member.keystoneTwentyPlus or 0))
    end

    ---------------------------------------------------------------------------
    -- Run Summary
    ---------------------------------------------------------------------------
    y = y - SECTION_GAP
    y = AddSectionHeader(y, "Run Summary")
    y = AddLabelValue(y, "Total Runs", tostring(member.numRuns or 0))
    y = AddLabelValue(y, "Timed Runs", tostring(member.numTimed or 0), 0, 0.8, 0)
    y = AddLabelValue(y, "Untimed Runs", tostring(member.numUntimed or 0), 0.8, 0, 0)

    ---------------------------------------------------------------------------
    -- Dungeon Breakdown
    ---------------------------------------------------------------------------
    if member.runs and next(member.runs) then
        y = y - SECTION_GAP
        y = AddSectionHeader(y, "Dungeon Breakdown")

        -- Column headers
        local hdrName = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrName:SetPoint("TOPLEFT", 8, y)
        hdrName:SetWidth(180)
        hdrName:SetJustifyH("LEFT")
        hdrName:SetText("Dungeon")
        hdrName:SetTextColor(0.5, 0.5, 0.5)
        table.insert(contentWidgets, hdrName)

        local hdrLevel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrLevel:SetPoint("TOPLEFT", 196, y)
        hdrLevel:SetWidth(50)
        hdrLevel:SetJustifyH("CENTER")
        hdrLevel:SetText("Level")
        hdrLevel:SetTextColor(0.5, 0.5, 0.5)
        table.insert(contentWidgets, hdrLevel)

        local hdrStatus = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrStatus:SetPoint("TOPLEFT", 252, y)
        hdrStatus:SetWidth(60)
        hdrStatus:SetJustifyH("CENTER")
        hdrStatus:SetText("Status")
        hdrStatus:SetTextColor(0.5, 0.5, 0.5)
        table.insert(contentWidgets, hdrStatus)

        local hdrScore = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrScore:SetPoint("TOPLEFT", 318, y)
        hdrScore:SetWidth(50)
        hdrScore:SetJustifyH("CENTER")
        hdrScore:SetText("Score")
        hdrScore:SetTextColor(0.5, 0.5, 0.5)
        table.insert(contentWidgets, hdrScore)

        y = y - LINE_HEIGHT

        -- Show season dungeons first in order
        local shown = {}
        local function AddDungeonRow(mapID, run)
            local name = GetDungeonName(mapID)

            -- Alternating row bg
            local rowBg = scrollChild:CreateTexture(nil, "BACKGROUND")
            rowBg:SetPoint("TOPLEFT", 4, y + 1)
            rowBg:SetPoint("RIGHT", -8, 0)
            rowBg:SetHeight(LINE_HEIGHT)
            local idx = #contentWidgets
            if idx % 2 == 0 then
                rowBg:SetColorTexture(1, 1, 1, 0.03)
            else
                rowBg:SetColorTexture(1, 1, 1, 0.05)
            end
            table.insert(contentWidgets, rowBg)

            local nameFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameFs:SetPoint("TOPLEFT", 8, y)
            nameFs:SetWidth(180)
            nameFs:SetJustifyH("LEFT")
            nameFs:SetText(name)
            nameFs:SetTextColor(0.85, 0.85, 0.85)
            table.insert(contentWidgets, nameFs)

            local levelFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            levelFs:SetPoint("TOPLEFT", 196, y)
            levelFs:SetWidth(50)
            levelFs:SetJustifyH("CENTER")
            levelFs:SetText("+" .. run.level)
            table.insert(contentWidgets, levelFs)

            local statusFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusFs:SetPoint("TOPLEFT", 252, y)
            statusFs:SetWidth(60)
            statusFs:SetJustifyH("CENTER")
            if run.timed then
                if run.chests and run.chests > 1 then
                    statusFs:SetText(format("+%d", run.chests))
                    statusFs:SetTextColor(0, 1, 0.5)
                else
                    statusFs:SetText("Timed")
                    statusFs:SetTextColor(0, 0.8, 0)
                end
            else
                statusFs:SetText("Untimed")
                statusFs:SetTextColor(0.8, 0, 0)
            end
            table.insert(contentWidgets, statusFs)

            local scoreFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            scoreFs:SetPoint("TOPLEFT", 318, y)
            scoreFs:SetWidth(50)
            scoreFs:SetJustifyH("CENTER")
            if run.score then
                scoreFs:SetText(tostring(run.score))
                scoreFs:SetTextColor(0.7, 0.7, 0.7)
            else
                scoreFs:SetText("—")
                scoreFs:SetTextColor(0.4, 0.4, 0.4)
            end
            table.insert(contentWidgets, scoreFs)

            y = y - LINE_HEIGHT
        end

        for _, mapID in ipairs(KS.DUNGEON_IDS) do
            local run = member.runs[mapID]
            if run then
                shown[mapID] = true
                AddDungeonRow(mapID, run)
            end
        end
        -- Any runs not in the season list
        for mapID, run in pairs(member.runs) do
            if not shown[mapID] then
                AddDungeonRow(mapID, run)
            end
        end

        -- Dungeons with no data
        for _, mapID in ipairs(KS.DUNGEON_IDS) do
            if not member.runs[mapID] then
                local name = GetDungeonName(mapID)
                local nameFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                nameFs:SetPoint("TOPLEFT", 8, y)
                nameFs:SetWidth(180)
                nameFs:SetJustifyH("LEFT")
                nameFs:SetText(name)
                nameFs:SetTextColor(0.35, 0.35, 0.35)
                table.insert(contentWidgets, nameFs)

                local noData = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                noData:SetPoint("TOPLEFT", 196, y)
                noData:SetText("No data")
                noData:SetTextColor(0.35, 0.35, 0.35)
                table.insert(contentWidgets, noData)

                y = y - LINE_HEIGHT
            end
        end
    else
        y = y - SECTION_GAP
        y = AddSectionHeader(y, "Dungeon Breakdown")
        local noRuns = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noRuns:SetPoint("TOPLEFT", 8, y)
        noRuns:SetText("No dungeon runs recorded this season.")
        noRuns:SetTextColor(0.5, 0.5, 0.5)
        table.insert(contentWidgets, noRuns)
        y = y - LINE_HEIGHT
    end

    -- Total height
    scrollChild:SetHeight(math.abs(y) + SECTION_GAP)
end

---------------------------------------------------------------------------
-- Create the detail overlay frame (once)
---------------------------------------------------------------------------
local function EnsureDetailFrame()
    if detailFrame then return end

    detailFrame = CreateFrame("Frame", nil, KS.mainFrame, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", 1, -29)
    detailFrame:SetPoint("BOTTOMRIGHT", -1, 1)
    detailFrame:SetFrameLevel(KS.mainFrame:GetFrameLevel() + 10)
    detailFrame:SetBackdrop(KS.BACKDROP_PANEL)
    detailFrame:SetBackdropColor(0.08, 0.08, 0.08, 1)
    detailFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    detailFrame:Hide()

    -- Back button
    local backBtn = KS.CreateButton(detailFrame, "< Back", "widget", 60, 22)
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
