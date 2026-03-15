local addonName, KS = ...

local CARD_WIDTH = 210
local CARD_HEIGHT = 140
local CARD_PADDING = 8
local MEMBER_HEIGHT = 18

local scrollFrame, scrollChild
local groupCards = {}
local noDataText

---------------------------------------------------------------------------
-- Drag and drop state
---------------------------------------------------------------------------
local dragCursor       -- floating frame showing dragged member name
local dragSource       -- { groupIdx, slot, slotIdx, member } of the dragged member
local allMemberLines = {} -- all active member line frames (for hit detection)

local function GetClassColoredName(member)
    if not member then return "|cff888888(empty)|r" end
    local color = KS.CLASS_COLORS[member.classFile]
    if color then
        return format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, member.name)
    end
    return member.name
end

local function GetScoreString(member)
    if not member then return "" end
    return format("|cffaaaaaa(%d)|r", member.score)
end

local function GetUtilityProviders(group, utilKey)
    local providers = {}
    local allMembers = {}
    if group.tank then table.insert(allMembers, group.tank) end
    if group.healer then table.insert(allMembers, group.healer) end
    for _, d in ipairs(group.dps) do table.insert(allMembers, d) end
    for _, m in ipairs(allMembers) do
        if m[utilKey] then
            local shortName = m.name:match("^([^-]+)") or m.name
            table.insert(providers, shortName)
        end
    end
    return providers
end

local function GetGroupUtilityString(group)
    local parts = {}
    local brezProviders = GetUtilityProviders(group, "hasBrez")
    local lustProviders = GetUtilityProviders(group, "hasLust")
    if #brezProviders > 0 then
        table.insert(parts, "|cff00cc00BR:|r " .. table.concat(brezProviders, ", "))
    else
        table.insert(parts, "|cffcc0000No BR|r")
    end
    if #lustProviders > 0 then
        table.insert(parts, "|cff00cc00BL:|r " .. table.concat(lustProviders, ", "))
    else
        table.insert(parts, "|cffcc0000No BL|r")
    end
    return table.concat(parts, "  ")
end

---------------------------------------------------------------------------
-- Drag cursor: floating frame that follows the mouse
---------------------------------------------------------------------------
local function GetOrCreateDragCursor()
    if dragCursor then return dragCursor end

    dragCursor = KS.CreateBorderedFrame(UIParent, 180, 22,
        {0.1, 0.1, 0.1, 0.9}, {0, 0.8, 1, 1})
    dragCursor:SetFrameStrata("TOOLTIP")

    -- Role icon (left)
    dragCursor.icon = dragCursor:CreateTexture(nil, "OVERLAY")
    dragCursor.icon:SetSize(14, 14)
    dragCursor.icon:SetPoint("LEFT", 4, 0)

    -- Name text (right of icon)
    dragCursor.text = dragCursor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dragCursor.text:SetPoint("LEFT", dragCursor.icon, "RIGHT", 4, 0)

    dragCursor:Hide()
    return dragCursor
end

local function StartDrag(line)
    if not line._member then return end

    dragSource = {
        groupIdx = line._groupIdx,
        slot = line._slot,        -- "tank", "healer", or "dps"
        slotIdx = line._slotIdx,  -- index within dps array (nil for tank/healer)
        member = line._member,
        sourceLine = line,
    }

    local cursor = GetOrCreateDragCursor()
    cursor.text:SetText(GetClassColoredName(dragSource.member))

    -- Set role icon on cursor
    local roleAtlas = KS.ROLE_ICONS[dragSource.member.role]
    if roleAtlas then
        cursor.icon:SetAtlas(roleAtlas)
        cursor.icon:Show()
    else
        cursor.icon:Hide()
    end

    cursor:Show()

    -- Source overlay (dimmed)
    if not line._dragOverlay then
        line._dragOverlay = line:CreateTexture(nil, "OVERLAY")
        line._dragOverlay:SetAllPoints()
        line._dragOverlay:SetColorTexture(0, 0, 0, 0.5)
    end
    line._dragOverlay:Show()

    -- Source highlight border
    if not line._highlightTex then
        line._highlightTex = line:CreateTexture(nil, "BACKGROUND")
        line._highlightTex:SetAllPoints()
        line._highlightTex:SetColorTexture(0, 0.8, 1, 0.15)
    end
    line._highlightTex:Show()
end

local function UpdateDragPosition()
    if not dragCursor or not dragCursor:IsShown() then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    dragCursor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    dragCursor:ClearAllPoints()
    dragCursor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale + 4)
end

local function FindDropTarget()
    for _, line in ipairs(allMemberLines) do
        if line:IsVisible() and line:IsMouseOver() then
            return line
        end
    end
    return nil
end

local function GetMemberFromSlot(groupIdx, slot, slotIdx)
    local group = KS.groups[groupIdx]
    if not group then return nil end
    if slot == "tank" then return group.tank
    elseif slot == "healer" then return group.healer
    elseif slot == "dps" then return group.dps[slotIdx]
    end
end

local function SetMemberInSlot(groupIdx, slot, slotIdx, member)
    local group = KS.groups[groupIdx]
    if not group then return end
    if slot == "tank" then group.tank = member
    elseif slot == "healer" then group.healer = member
    elseif slot == "dps" then group.dps[slotIdx] = member
    end
end

local function FlashLine(line)
    if not line then return end
    if not line._flashTex then
        line._flashTex = line:CreateTexture(nil, "OVERLAY")
        line._flashTex:SetAllPoints()
        line._flashTex:SetColorTexture(0, 0.8, 1, 0)

        line._flashAG = line._flashTex:CreateAnimationGroup()
        local fade = line._flashAG:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.5)
        fade:SetToAlpha(0)
        fade:SetDuration(0.3)
        fade:SetSmoothing("OUT")
        line._flashAG:SetScript("OnFinished", function()
            line._flashTex:SetAlpha(0)
        end)
    end
    line._flashTex:SetAlpha(0.5)
    line._flashAG:Play()
end

local function StopDrag(line)
    if dragCursor then dragCursor:Hide() end

    -- Clear source overlay and highlight
    if line then
        if line._dragOverlay then line._dragOverlay:Hide() end
        if line._highlightTex then line._highlightTex:Hide() end
    end

    if not dragSource then return end

    local target = FindDropTarget()
    if target and target._member and target ~= line then
        local src = dragSource
        local dst = {
            groupIdx = target._groupIdx,
            slot = target._slot,
            slotIdx = target._slotIdx,
            member = target._member,
        }

        SetMemberInSlot(src.groupIdx, src.slot, src.slotIdx, dst.member)
        SetMemberInSlot(dst.groupIdx, dst.slot, dst.slotIdx, src.member)

        -- Flash both swapped positions, then rebuild view after animation
        FlashLine(src.sourceLine)
        FlashLine(target)

        -- Defer view rebuild until flash animation completes (0.35s)
        C_Timer.After(0.35, function()
            KS.UpdateGroupView()
        end)
        KS.AutoSync()
    end

    dragSource = nil
end

---------------------------------------------------------------------------
-- Member line creation (with drag support)
---------------------------------------------------------------------------
local function CreateMemberLine(parent, yOffset, label, member, groupIdx, slot, slotIdx)
    local line = CreateFrame("Button", nil, parent)
    line:SetPoint("TOPLEFT", 8, yOffset)
    line:SetPoint("TOPRIGHT", -8, yOffset)
    line:SetHeight(MEMBER_HEIGHT)
    line:EnableMouse(member ~= nil)

    -- Role icon
    local roleAtlas = KS.ROLE_ICONS[label]
    if roleAtlas then
        local icon = line:CreateTexture(nil, "OVERLAY")
        icon:SetSize(12, 12)
        icon:SetPoint("LEFT", 0, 0)
        icon:SetAtlas(roleAtlas)
    end

    -- Name + score + utility tags
    local nameText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", 18, 0)
    local text = GetClassColoredName(member) .. " " .. GetScoreString(member)
    if member then
        local tags = {}
        if member.hasBrez then table.insert(tags, "|cff00cc00BR|r") end
        if member.hasLust then table.insert(tags, "|cff00cc00BL|r") end
        if #tags > 0 then
            text = text .. " " .. table.concat(tags, " ")
        end
    end
    nameText:SetText(text)

    if member then
        -- Store metadata for drag and drop
        line._member = member
        line._groupIdx = groupIdx
        line._slot = slot       -- "tank", "healer", or "dps"
        line._slotIdx = slotIdx -- index in dps array (nil for tank/healer)

        -- Click to open character detail (non-drag click)
        line:RegisterForClicks("RightButtonUp")
        line:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self._member then
                KS.ShowCharacterDetail(self._member, "groups")
            end
        end)

        -- Register for drag
        line:RegisterForDrag("LeftButton")
        line:SetScript("OnDragStart", function(self) StartDrag(self) end)
        line:SetScript("OnDragStop", function(self) StopDrag(self) end)

        -- Update cursor position while dragging
        line:SetScript("OnUpdate", function(self)
            -- Drag cursor follow
            UpdateDragPosition()

            -- Shift-hover tooltip (only when not dragging)
            if not dragSource and self:IsMouseOver() then
                if IsShiftKeyDown() and not self._shiftShown then
                    KS.ShowMemberTooltip(self, self._member)
                    self._shiftShown = true
                elseif not IsShiftKeyDown() and self._shiftShown then
                    self._shiftShown = false
                    KS.ShowTooltip(self, "ANCHOR_RIGHT", {
                        "Member Actions",
                        {"|cffccccccLeft-click drag|r to move", 0.8, 0.8, 0.8},
                        {"|cffccccccRight-click|r to inspect", 0.8, 0.8, 0.8},
                        {"|cffccccccShift-hover|r for details", 0.5, 0.5, 0.5},
                    })
                end
            end

            -- Drop target highlighting with border
            if dragSource and self ~= dragSource.sourceLine then
                if self:IsMouseOver() and self._member then
                    if not self._highlightTex then
                        self._highlightTex = self:CreateTexture(nil, "BACKGROUND")
                        self._highlightTex:SetAllPoints()
                        self._highlightTex:SetColorTexture(0, 0.8, 1, 0.15)
                    end
                    self._highlightTex:Show()
                    -- Cyan border on drop target
                    if not self._dropBorder then
                        self._dropBorder = self:CreateTexture(nil, "OVERLAY", nil, -1)
                        self._dropBorder:SetPoint("TOPLEFT", -1, 1)
                        self._dropBorder:SetPoint("BOTTOMRIGHT", 1, -1)
                        self._dropBorder:SetColorTexture(0, 0.8, 1, 0.4)
                    end
                    self._dropBorder:Show()
                else
                    if self._highlightTex then self._highlightTex:Hide() end
                    if self._dropBorder then self._dropBorder:Hide() end
                end
            end
        end)

        line:SetScript("OnEnter", function(self)
            if not dragSource then
                if IsShiftKeyDown() and self._member then
                    KS.ShowMemberTooltip(self, self._member)
                else
                    KS.ShowTooltip(self, "ANCHOR_RIGHT", {
                        "Member Actions",
                        {"|cffccccccLeft-click drag|r to move", 0.8, 0.8, 0.8},
                        {"|cffccccccRight-click|r to inspect", 0.8, 0.8, 0.8},
                        {"|cffccccccShift-hover|r for details", 0.5, 0.5, 0.5},
                    })
                end
            end
        end)
        line:SetScript("OnLeave", function(self)
            KS.HideTooltip()
            self._shiftShown = false
            if self._highlightTex then self._highlightTex:Hide() end
            if self._dropBorder then self._dropBorder:Hide() end
        end)

        -- Track this line for hit detection
        table.insert(allMemberLines, line)
    end

    return line
end

local GROUP_HEADER_H = 24  -- header row only (utilities now inline with member names)

local function CreateGroupCard(parent, groupIdx, group, xOffset, yOffset)
    local numDpsSlots = math.max(#group.dps, 3)
    local cardHeight = GROUP_HEADER_H + (2 + numDpsSlots) * MEMBER_HEIGHT + 8

    -- Use BorderedFrame for group card
    local card = KS.CreateBorderedFrame(parent, CARD_WIDTH, cardHeight,
        {0.12, 0.12, 0.12, 0.95}, {0.3, 0.3, 0.3, 1})
    card:SetPoint("TOPLEFT", xOffset, yOffset)

    -- Lock toggle — CheckButton with lock icon
    local lockBtn = KS.CreateCheckButton(card, nil, 14, function(checked)
        group.locked = checked
        if checked then
            card:SetBorderColor(0.1, 0.5, 0.1, 1)
        else
            card:SetBorderColor(0.3, 0.3, 0.3, 1)
        end
    end)
    lockBtn._icon:SetTexture(KS.MEDIA.Lock)
    lockBtn:SetPoint("TOPLEFT", 6, -4)
    lockBtn:SetChecked(group.locked)
    if group.locked then
        card:SetBorderColor(0.1, 0.5, 0.1, 1)
    end
    KS.SetTooltip(lockBtn, "ANCHOR_RIGHT", {"Lock Group", "Locked groups are preserved when re-sorting."})

    -- Group header (row 1: group name, avg score, announce)
    local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("LEFT", lockBtn, "RIGHT", 2, 0)
    header:SetText(format("Group %d", groupIdx))
    header:SetTextColor(0, 0.8, 1)

    local avgScore = KS.GroupScore(group)
    local avgText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    avgText:SetPoint("LEFT", header, "RIGHT", 8, 0)
    avgText:SetText(format("Avg: %d", avgScore))
    avgText:SetTextColor(0.7, 0.7, 0.7)

    -- Announce button with border highlight
    local announceBtn = KS.CreateButton(card, "Announce", "widget", 52, 16)
    announceBtn:SetPoint("TOPRIGHT", -6, -4)
    announceBtn:SetAnimatedHighlight(true)
    announceBtn:SetBorderHighlightColor(0, 0.8, 1, 0.6)
    announceBtn:SetOnClick(function() KS.AnnounceGroup(groupIdx) end)
    KS.SetTooltip(announceBtn, "ANCHOR_RIGHT", {"Announce Group", "Post this group's assignments to raid chat."})

    -- Members (start below header)
    local y = -GROUP_HEADER_H
    CreateMemberLine(card, y, "TANK", group.tank, groupIdx, "tank", nil)
    y = y - MEMBER_HEIGHT
    CreateMemberLine(card, y, "HEALER", group.healer, groupIdx, "healer", nil)
    y = y - MEMBER_HEIGHT
    for dIdx, dps in ipairs(group.dps) do
        CreateMemberLine(card, y, "DAMAGER", dps, groupIdx, "dps", dIdx)
        y = y - MEMBER_HEIGHT
    end
    for _ = #group.dps + 1, 3 do
        CreateMemberLine(card, y, "DAMAGER", nil)
        y = y - MEMBER_HEIGHT
    end

    return card
end

local function CreateUnassignedCard(parent)
    if #KS.unassigned == 0 then return nil end

    local height = 24 + #KS.unassigned * MEMBER_HEIGHT + 8
    local card = KS.CreateBorderedFrame(parent, CARD_WIDTH, height,
        {0.15, 0.1, 0.05, 0.95}, {0.5, 0.35, 0.15, 1})

    local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 8, -6)
    header:SetText(format("Unassigned (%d)", #KS.unassigned))
    header:SetTextColor(1, 0.6, 0)

    local y = -24
    for _, member in ipairs(KS.unassigned) do
        CreateMemberLine(card, y, member.role, member)
        y = y - MEMBER_HEIGHT
    end

    return card
end

function KS.CreateGroupView(parent)
    -- Custom scroll frame (clean thin scrollbar)
    scrollFrame, scrollChild = KS.CreateScrollFrame(parent, "KeySorterGroupScroll")
end

-- Reposition existing cards based on current scroll child width
local function LayoutGroupCards()
    if not scrollChild or #groupCards == 0 then return end

    local totalWidth = scrollChild:GetWidth()
    if totalWidth < 1 then
        -- scrollChild may have 0 width if parent is hidden; use parent's width
        local parentWidth = scrollFrame and scrollFrame:GetWidth() or 0
        totalWidth = parentWidth > 1 and parentWidth or 650
    end

    -- Calculate how many cards fit per row
    local cardsPerRow = math.max(1, math.floor((totalWidth + CARD_PADDING) / (CARD_WIDTH + CARD_PADDING)))

    local col = 0
    local yOffset = -CARD_PADDING
    local rowMaxHeight = 0

    for i, card in ipairs(groupCards) do
        local x = col * (CARD_WIDTH + CARD_PADDING)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, yOffset)

        local cardHeight = card:GetHeight()
        if cardHeight > rowMaxHeight then
            rowMaxHeight = cardHeight
        end

        col = col + 1
        if col >= cardsPerRow then
            col = 0
            yOffset = yOffset - rowMaxHeight - CARD_PADDING
            rowMaxHeight = 0
        end
    end

    if col > 0 then
        yOffset = yOffset - rowMaxHeight - CARD_PADDING
    end

    local totalHeight = math.abs(yOffset) + CARD_PADDING
    scrollChild:SetHeight(totalHeight)
end

function KS.UpdateGroupView()
    if not scrollChild then return end

    -- Clear existing cards — hide all children explicitly to prevent visual artifacts
    local function CleanupFrame(frame)
        for _, child in ipairs({ frame:GetChildren() }) do
            child:Hide()
            child:ClearAllPoints()
        end
        for _, region in ipairs({ frame:GetRegions() }) do
            region:Hide()
        end
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetParent(nil)
    end

    for _, card in ipairs(groupCards) do
        CleanupFrame(card)
    end
    wipe(groupCards)
    wipe(allMemberLines)
    if noDataText then
        noDataText:Hide()
    end

    if #KS.groups == 0 then
        if not noDataText then
            noDataText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noDataText:SetPoint("CENTER", 0, 0)
            noDataText:SetTextColor(0.5, 0.5, 0.5)
        end
        noDataText:SetText("No groups yet. Click Sort to generate groups.")
        noDataText:Show()
        scrollChild:SetHeight(100)
        return
    end

    -- Create cards (no positioning yet)
    for i, group in ipairs(KS.groups) do
        local card = CreateGroupCard(scrollChild, i, group, 0, 0)
        table.insert(groupCards, card)
    end

    -- Add unassigned as another card in the grid
    if #KS.unassigned > 0 then
        local uCard = CreateUnassignedCard(scrollChild)
        if uCard then table.insert(groupCards, uCard) end
    end

    -- Layout cards responsively, then set up resize hook
    LayoutGroupCards()

    if not scrollFrame._resizeHooked then
        scrollFrame._resizeHooked = true
        scrollFrame:HookScript("OnSizeChanged", function()
            if #groupCards > 0 then
                LayoutGroupCards()
            end
        end)
    end
end
