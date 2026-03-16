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

-- Use shared helpers from Data.lua
local GetScoreColor = function(score) return KS.GetScoreColor(score) end
local GetIlvlColor = function(ilvl) return KS.GetIlvlColor(ilvl) end
local GetDungeonName = function(mapID) return KS.GetDungeonName(mapID) end

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
    yL = AddLabelValue(yL, "S1 Score", tostring(member.score), sr, sg, sb, leftX)

    if member.previousScore and member.previousScore > 0 then
        local pr, pg, pb = GetScoreColor(member.previousScore)
        yL = AddLabelValue(yL, "S3 Score", tostring(member.previousScore), pr, pg, pb, leftX)
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
    local br_r, br_g, br_b = utilColor(member.hasBrez)
    yL = AddLabelValue(yL, "Battle Rez", member.hasBrez and "Yes" or "No", br_r, br_g, br_b, leftX)
    local bl_r, bl_g, bl_b = utilColor(member.hasLust)
    yL = AddLabelValue(yL, "Bloodlust", member.hasLust and "Yes" or "No", bl_r, bl_g, bl_b, leftX)
    local sh_r, sh_g, sh_b = utilColor(member.hasShroud)
    yL = AddLabelValue(yL, "Shroud", member.hasShroud and "Yes" or "No", sh_r, sh_g, sh_b, leftX)

    -- Key Thresholds
    if member.dataSource == "raiderio" or (member.keystoneFivePlus and member.keystoneFivePlus > 0) then
        yL = yL - SECTION_GAP
        yL = AddSectionHeader(yL, "Timed Key Thresholds", leftX, colWidth - 16)
        yL = AddLabelValue(yL, "+5 Timed", tostring(member.keystoneFivePlus or 0), nil, nil, nil, leftX)
        yL = AddLabelValue(yL, "+10 Timed", tostring(member.keystoneTenPlus or 0), nil, nil, nil, leftX)
        yL = AddLabelValue(yL, "+15 Timed", tostring(member.keystoneFifteenPlus or 0), nil, nil, nil, leftX)
        yL = AddLabelValue(yL, "+20 Timed", tostring(member.keystoneTwentyPlus or 0), nil, nil, nil, leftX)
    end

    -- Notes
    yL = yL - SECTION_GAP
    yL = AddSectionHeader(yL, "Notes", leftX, colWidth - 16)

    local noteContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    noteContainer:SetPoint("TOPLEFT", leftX + 8, yL)
    noteContainer:SetSize(colWidth - 24, 44)
    noteContainer:SetBackdrop(KS.BACKDROP)
    noteContainer:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    noteContainer:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    table.insert(contentWidgets, noteContainer)

    local noteSF = CreateFrame("ScrollFrame", nil, noteContainer)
    noteSF:SetPoint("TOPLEFT", 4, -3)
    noteSF:SetPoint("BOTTOMRIGHT", -4, 3)
    table.insert(contentWidgets, noteSF)

    local noteBox = CreateFrame("EditBox", nil, noteSF)
    noteBox:SetWidth(colWidth - 36)
    noteBox:SetFontObject("GameFontHighlightSmall")
    noteBox:SetAutoFocus(false)
    noteBox:SetMultiLine(true)
    noteBox:SetText(KeySorterDB.notes[member.name] or "")
    noteSF:SetScrollChild(noteBox)
    table.insert(contentWidgets, noteBox)

    local noteSaveBtn = KS.CreateButton(scrollChild, "Save", "accent", 44, 18)
    noteSaveBtn:SetAnimatedHighlight(true)
    noteSaveBtn:SetPoint("TOPLEFT", leftX + 8, yL - 48)
    noteSaveBtn:SetOnClick(function()
        KeySorterDB.notes[member.name] = noteBox:GetText()
        print(format("|cff00ccffKeySorter|r: Note saved for %s.", member.name))
    end)
    table.insert(contentWidgets, noteSaveBtn)

    local noteClearBtn = KS.CreateButton(scrollChild, "Clear", "widget", 44, 18)
    noteClearBtn:SetAnimatedHighlight(true)
    noteClearBtn:SetPoint("LEFT", noteSaveBtn, "RIGHT", 4, 0)
    noteClearBtn:SetOnClick(function()
        noteBox:SetText("")
        KeySorterDB.notes[member.name] = nil
        print(format("|cff00ccffKeySorter|r: Note cleared for %s.", member.name))
    end)
    table.insert(contentWidgets, noteClearBtn)

    yL = yL - 72

    -- Linked Alts
    yL = yL - SECTION_GAP
    yL = AddSectionHeader(yL, "Linked Alts", leftX, colWidth - 16)

    -- Show currently linked alts
    local myTag = KeySorterDB.alts[member.name]
    local linkedNames = {}
    if myTag then
        for charName, tag in pairs(KeySorterDB.alts) do
            if tag == myTag and charName ~= member.name then
                table.insert(linkedNames, charName)
            end
        end
    end

    if #linkedNames > 0 then
        for _, altName in ipairs(linkedNames) do
            local info = KeySorterDB.knownChars[altName]
            local altText
            if info then
                local classColor = KS.CLASS_COLORS[info.classFile]
                local colorStr = classColor and format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255) or "|cffffffff"
                local sr, sg, sb = KS.GetScoreColor(info.score or 0)
                altText = format("%s%s|r — |cff%02x%02x%02x%d|r score, %d ilvl",
                    colorStr, altName, sr * 255, sg * 255, sb * 255, info.score or 0, info.ilvl or 0)
            else
                altText = altName .. " |cff666666(not seen recently)|r"
            end
            local altFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            altFs:SetPoint("TOPLEFT", leftX + 12, yL)
            altFs:SetText(altText)
            table.insert(contentWidgets, altFs)
            yL = yL - LINE_HEIGHT
        end
    else
        local noAlts = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noAlts:SetPoint("TOPLEFT", leftX + 12, yL)
        noAlts:SetText("|cff666666No linked alts|r")
        noAlts:SetTextColor(0.5, 0.5, 0.5)
        table.insert(contentWidgets, noAlts)
        yL = yL - LINE_HEIGHT
    end

    yL = yL - 4

    -- Search box to link an alt
    local linkLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    linkLabel:SetPoint("TOPLEFT", leftX + 8, yL)
    linkLabel:SetText("Link alt:")
    linkLabel:SetTextColor(0.7, 0.7, 0.7)
    table.insert(contentWidgets, linkLabel)

    local searchBox = CreateFrame("EditBox", nil, scrollChild, "BackdropTemplate")
    searchBox:SetPoint("LEFT", linkLabel, "RIGHT", 6, 0)
    searchBox:SetSize(140, 20)
    searchBox:SetBackdrop(KS.BACKDROP)
    searchBox:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    searchBox:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(4, 4, 2, 2)
    table.insert(contentWidgets, searchBox)

    -- Search results dropdown
    local searchResults = CreateFrame("Frame", nil, searchBox, "BackdropTemplate")
    searchResults:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -1)
    searchResults:SetSize(140, 1)
    searchResults:SetBackdrop(KS.BACKDROP)
    searchResults:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    searchResults:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    searchResults:SetFrameStrata("DIALOG")
    searchResults:Hide()
    table.insert(contentWidgets, searchResults)
    local resultButtons = {}

    local function UpdateSearchResults(query)
        for _, btn in ipairs(resultButtons) do btn:Hide() end
        if not query or #query < 2 then searchResults:Hide(); return end

        local matches = {}
        query = query:lower()
        for charName, info in pairs(KeySorterDB.knownChars) do
            if charName ~= member.name and charName:lower():find(query, 1, true) then
                table.insert(matches, { name = charName, info = info })
            end
        end
        -- Also check roster for chars not yet in knownChars
        for _, m in ipairs(KS.roster) do
            if m.name ~= member.name and m.name:lower():find(query, 1, true) then
                local found = false
                for _, match in ipairs(matches) do
                    if match.name == m.name then found = true; break end
                end
                if not found then
                    table.insert(matches, { name = m.name, info = { classFile = m.classFile, score = m.score, ilvl = m.ilvl } })
                end
            end
        end

        if #matches == 0 then searchResults:Hide(); return end

        local maxShow = math.min(#matches, 6)
        searchResults:SetHeight(maxShow * 18 + 4)
        searchResults:Show()

        for i = 1, maxShow do
            if not resultButtons[i] then
                local rb = CreateFrame("Button", nil, searchResults)
                rb:SetHeight(18)
                rb:SetPoint("TOPLEFT", 2, -(i - 1) * 18 - 2)
                rb:SetPoint("TOPRIGHT", -2, -(i - 1) * 18 - 2)
                local rbText = rb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rbText:SetPoint("LEFT", 4, 0)
                rb._text = rbText
                rb:SetScript("OnEnter", function(self) self._text:SetTextColor(1, 1, 1) end)
                rb:SetScript("OnLeave", function(self) self._text:SetTextColor(0.8, 0.8, 0.8) end)
                resultButtons[i] = rb
            end
            local rb = resultButtons[i]
            local match = matches[i]
            local classColor = KS.CLASS_COLORS[match.info.classFile]
            local colorStr = classColor and format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255) or "|cffffffff"
            rb._text:SetText(format("%s%s|r (%d)", colorStr, match.name, match.info.score or 0))
            rb._text:SetTextColor(0.8, 0.8, 0.8)
            rb:SetScript("OnClick", function()
                -- Link this alt to the current member
                local tag = KeySorterDB.alts[member.name] or member.name
                KeySorterDB.alts[member.name] = tag
                KeySorterDB.alts[match.name] = tag
                searchBox:SetText("")
                searchResults:Hide()
                print(format("|cff00ccffKeySorter|r: Linked %s as an alt of %s.", match.name, member.name))
                -- Refresh the detail view
                KS.ShowCharacterDetail(member, previousTab)
            end)
            rb:Show()
        end
        for i = maxShow + 1, #resultButtons do
            resultButtons[i]:Hide()
        end
    end

    searchBox:SetScript("OnTextChanged", function(self)
        UpdateSearchResults(self:GetText())
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        searchResults:Hide()
    end)

    -- Unlink button (if linked)
    if myTag then
        local unlinkBtn = KS.CreateButton(scrollChild, "Unlink All", "red", 70, 18)
        unlinkBtn:SetAnimatedHighlight(true)
        unlinkBtn:SetPoint("TOPLEFT", leftX + 8, yL - LINE_HEIGHT - 4)
        unlinkBtn:SetOnClick(function()
            -- Remove all links for this player tag
            local tag = KeySorterDB.alts[member.name]
            if tag then
                for charName, t in pairs(KeySorterDB.alts) do
                    if t == tag then KeySorterDB.alts[charName] = nil end
                end
            end
            print(format("|cff00ccffKeySorter|r: Unlinked all alts for %s.", member.name))
            KS.ShowCharacterDetail(member, previousTab)
        end)
        table.insert(contentWidgets, unlinkBtn)
        yL = yL - LINE_HEIGHT - 26
    end

    yL = yL - LINE_HEIGHT - 8

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
            -- Green = timed, Red = not timed at this level
            if run.timed then
                levelFs:SetTextColor(0, 0.8, 0)
            else
                levelFs:SetTextColor(0.8, 0, 0)
            end
            table.insert(contentWidgets, levelFs)

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
        -- Only show S1 Midnight dungeons (skip any TWW S3 dungeon runs)

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
