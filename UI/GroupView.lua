local addonName, KS = ...

local CARD_WIDTH = 210
local CARD_HEIGHT = 140
local CARD_PADDING = 8
local MEMBER_HEIGHT = 18

local scrollFrame, scrollChild
local groupCards = {}
local unassignedCard
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

local function GetGroupUtilityString(group)
    local parts = {}
    if KS.GroupHasUtility(group, "hasBrez") then
        table.insert(parts, "|cff00cc00BR|r")
    else
        table.insert(parts, "|cffcc0000BR|r")
    end
    if KS.GroupHasUtility(group, "hasLust") then
        table.insert(parts, "|cff00cc00BL|r")
    else
        table.insert(parts, "|cffcc0000BL|r")
    end
    return table.concat(parts, " ")
end

---------------------------------------------------------------------------
-- Drag cursor: floating frame that follows the mouse
---------------------------------------------------------------------------
local function GetOrCreateDragCursor()
    if dragCursor then return dragCursor end

    dragCursor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dragCursor:SetSize(160, 20)
    dragCursor:SetFrameStrata("TOOLTIP")
    dragCursor:SetBackdrop(KS.BACKDROP_PANEL)
    dragCursor:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    dragCursor:SetBackdropBorderColor(0, 0.8, 1, 1)

    dragCursor.text = dragCursor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dragCursor.text:SetPoint("CENTER")

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
    }

    local cursor = GetOrCreateDragCursor()
    cursor.text:SetText(GetClassColoredName(dragSource.member))
    cursor:Show()

    -- Highlight source line
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

local function StopDrag(line)
    -- Hide cursor
    if dragCursor then dragCursor:Hide() end

    -- Remove highlight from source
    if line and line._highlightTex then
        line._highlightTex:Hide()
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

        -- Swap the two members in the data model
        SetMemberInSlot(src.groupIdx, src.slot, src.slotIdx, dst.member)
        SetMemberInSlot(dst.groupIdx, dst.slot, dst.slotIdx, src.member)

        -- Rebuild the view and auto-sync
        KS.UpdateGroupView()
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

    -- Name + score
    local nameText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", 18, 0)
    nameText:SetText(GetClassColoredName(member) .. " " .. GetScoreString(member))

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
                    -- Shift released: switch back to hint tooltip
                    self._shiftShown = false
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("|cffccccccLeft-click drag|r to move", 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("|cffccccccRight-click|r to inspect", 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("|cffccccccShift-hover|r for details", 0.5, 0.5, 0.5)
                    GameTooltip:Show()
                end
            end

            -- Highlight drop target
            if dragSource and self ~= dragSource then
                if self:IsMouseOver() and self._member then
                    if not self._highlightTex then
                        self._highlightTex = self:CreateTexture(nil, "BACKGROUND")
                        self._highlightTex:SetAllPoints()
                        self._highlightTex:SetColorTexture(0, 0.8, 1, 0.15)
                    end
                    self._highlightTex:Show()
                elseif self._highlightTex then
                    self._highlightTex:Hide()
                end
            end
        end)

        line:SetScript("OnEnter", function(self)
            if not dragSource then
                if IsShiftKeyDown() then
                    KS.ShowMemberTooltip(self, self._member)
                else
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("|cffccccccLeft-click drag|r to move", 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("|cffccccccRight-click|r to inspect", 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("|cffccccccShift-hover|r for details", 0.5, 0.5, 0.5)
                    GameTooltip:Show()
                end
            end
        end)
        line:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            self._shiftShown = false
            if self._highlightTex then self._highlightTex:Hide() end
        end)

        -- Track this line for hit detection
        table.insert(allMemberLines, line)
    end

    return line
end

local function CreateGroupCard(parent, groupIdx, group, xOffset, yOffset)
    -- Dynamic height: header(24) + tank + healer + max(#dps, 3) slots + padding(8)
    local numDpsSlots = math.max(#group.dps, 3)
    local cardHeight = 24 + (2 + numDpsSlots) * MEMBER_HEIGHT + 8

    -- Squared card with flat border
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(CARD_WIDTH, cardHeight)
    card:SetPoint("TOPLEFT", xOffset, yOffset)

    card:SetBackdrop(KS.BACKDROP_PANEL)
    card:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    card:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Lock toggle button
    local lockBtn = CreateFrame("Button", nil, card)
    lockBtn:SetSize(16, 16)
    lockBtn:SetPoint("TOPLEFT", 6, -5)

    local lockIcon = lockBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockIcon:SetPoint("CENTER", 0, 0)
    lockIcon:SetText(group.locked and "|cff00cc00L|r" or "|cff666666U|r")

    local function UpdateLockVisual()
        if group.locked then
            lockIcon:SetText("|cff00cc00L|r")
            card:SetBackdropBorderColor(0.1, 0.5, 0.1, 1)
        else
            lockIcon:SetText("|cff666666U|r")
            card:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
    end
    UpdateLockVisual()

    lockBtn:SetScript("OnClick", function()
        group.locked = not group.locked
        UpdateLockVisual()
    end)
    KS.AddTooltip(lockBtn, "Lock Group", "Locked groups are preserved when re-sorting.")

    -- Group header
    local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("LEFT", lockBtn, "RIGHT", 2, 0)
    header:SetText(format("Group %d", groupIdx))
    header:SetTextColor(0, 0.8, 1)

    -- Announce button (per-group)
    local announceBtn = KS.CreateButton(card, "Announce", "widget", 52, 16)
    announceBtn:SetPoint("TOPRIGHT", -6, -5)
    announceBtn:SetOnClick(function() KS.AnnounceGroup(groupIdx) end)
    KS.AddTooltip(announceBtn, "Announce Group", "Post this group's assignments to raid chat.")

    -- Average M+ score for the group
    local avgScore = KS.GroupScore(group)
    local avgText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    avgText:SetPoint("RIGHT", announceBtn, "LEFT", -6, 0)
    avgText:SetText(format("Avg: %d", avgScore))
    avgText:SetTextColor(0.7, 0.7, 0.7)

    -- Utility coverage (BR = battle rez, BL = bloodlust; dimmed if missing)
    local utilText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    utilText:SetPoint("TOPRIGHT", -8, -24)
    utilText:SetText(GetGroupUtilityString(group))

    -- Members: 1 tank, 1 healer, N DPS
    local y = -24
    CreateMemberLine(card, y, "TANK", group.tank, groupIdx, "tank", nil)
    y = y - MEMBER_HEIGHT
    CreateMemberLine(card, y, "HEALER", group.healer, groupIdx, "healer", nil)
    y = y - MEMBER_HEIGHT
    for dIdx, dps in ipairs(group.dps) do
        CreateMemberLine(card, y, "DAMAGER", dps, groupIdx, "dps", dIdx)
        y = y - MEMBER_HEIGHT
    end
    -- Fill empty DPS slots if group is incomplete
    for _ = #group.dps + 1, 3 do
        CreateMemberLine(card, y, "DAMAGER", nil)
        y = y - MEMBER_HEIGHT
    end

    return card
end

local function CreateUnassignedSection(parent, yOffset)
    if #KS.unassigned == 0 then return nil end

    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local height = 24 + #KS.unassigned * MEMBER_HEIGHT + 8
    card:SetPoint("TOPLEFT", 0, yOffset)
    card:SetPoint("RIGHT", -CARD_PADDING, 0)
    card:SetHeight(height)

    card:SetBackdrop(KS.BACKDROP_PANEL)
    card:SetBackdropColor(0.15, 0.1, 0.05, 0.95)
    card:SetBackdropBorderColor(0.5, 0.35, 0.15, 1)

    local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 8, -6)
    header:SetText(format("Unassigned (%d)", #KS.unassigned))
    header:SetTextColor(1, 0.6, 0)

    local y = -24
    for _, member in ipairs(KS.unassigned) do
        CreateMemberLine(card, y, member.role, member)
        y = y - MEMBER_HEIGHT
    end

    return card, height
end

function KS.CreateGroupView(parent)
    -- Custom scroll frame (clean thin scrollbar)
    scrollFrame, scrollChild = KS.CreateScrollFrame(parent, "KeySorterGroupScroll")
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
    if unassignedCard then
        CleanupFrame(unassignedCard)
        unassignedCard = nil
    end
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

    -- Layout cards in a grid (3 per row)
    local cardsPerRow = 3
    local totalWidth = scrollChild:GetWidth()
    if totalWidth < 1 then totalWidth = 650 end

    local xStart = 0
    local yStart = -CARD_PADDING
    local col = 0
    local yOffset = yStart
    local rowMaxHeight = 0

    for i, group in ipairs(KS.groups) do
        local x = xStart + col * (CARD_WIDTH + CARD_PADDING)

        local card = CreateGroupCard(scrollChild, i, group, x, yOffset)
        table.insert(groupCards, card)

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

    -- If the last row wasn't full, still account for its height
    if col > 0 then
        yOffset = yOffset - rowMaxHeight - CARD_PADDING
    end

    -- Unassigned section below cards
    local unHeight = 0
    if #KS.unassigned > 0 then
        unassignedCard, unHeight = CreateUnassignedSection(scrollChild, yOffset - CARD_PADDING)
        yOffset = yOffset - CARD_PADDING - unHeight
    end

    local totalHeight = math.abs(yOffset) + CARD_PADDING
    scrollChild:SetHeight(totalHeight)
end
