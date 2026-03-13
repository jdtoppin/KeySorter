local addonName, KS = ...

local CARD_WIDTH = 210
local CARD_HEIGHT = 140
local CARD_PADDING = 8
local MEMBER_HEIGHT = 18

local scrollFrame, scrollChild
local groupCards = {}
local unassignedCard

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
        table.insert(parts, "|cff660000BR|r")
    end
    if KS.GroupHasUtility(group, "hasLust") then
        table.insert(parts, "|cffcc0000BL|r")
    else
        table.insert(parts, "|cff660000BL|r")
    end
    return table.concat(parts, " ")
end

local function CreateMemberLine(parent, yOffset, label, member)
    local line = CreateFrame("Frame", nil, parent)
    line:SetPoint("TOPLEFT", 8, yOffset)
    line:SetPoint("TOPRIGHT", -8, yOffset)
    line:SetHeight(MEMBER_HEIGHT)

    -- Role label
    local roleText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roleText:SetPoint("LEFT", 0, 0)
    roleText:SetWidth(14)

    local roleAtlas = KS.ROLE_ICONS[label]
    if roleAtlas then
        local icon = line:CreateTexture(nil, "OVERLAY")
        icon:SetSize(12, 12)
        icon:SetPoint("LEFT", 0, 0)
        icon:SetAtlas(roleAtlas)
        line.roleIcon = icon
        roleText:SetPoint("LEFT", 16, 0)
    end

    -- Name + score
    local nameText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", 18, 0)
    nameText:SetText(GetClassColoredName(member) .. " " .. GetScoreString(member))

    line.nameText = nameText
    return line
end

local function CreateGroupCard(parent, groupIdx, group, xOffset, yOffset)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(CARD_WIDTH, CARD_HEIGHT)
    card:SetPoint("TOPLEFT", xOffset, yOffset)

    card:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    card:SetBackdropColor(0.15, 0.15, 0.15, 0.95)
    card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Header
    local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 8, -6)
    header:SetText(format("Group %d", groupIdx))
    header:SetTextColor(0, 0.8, 1)

    -- Avg score
    local avgScore = KS.GroupScore(group)
    local avgText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    avgText:SetPoint("TOPRIGHT", -8, -6)
    avgText:SetText(format("Avg: %d", avgScore))
    avgText:SetTextColor(0.7, 0.7, 0.7)

    -- Utility icons
    local utilText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    utilText:SetPoint("TOPRIGHT", -8, -20)
    utilText:SetText(GetGroupUtilityString(group))

    -- Members
    local y = -24
    CreateMemberLine(card, y, "TANK", group.tank)
    y = y - MEMBER_HEIGHT
    CreateMemberLine(card, y, "HEALER", group.healer)
    y = y - MEMBER_HEIGHT
    for _, dps in ipairs(group.dps) do
        CreateMemberLine(card, y, "DAMAGER", dps)
        y = y - MEMBER_HEIGHT
    end
    -- Fill empty DPS slots
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

    card:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    card:SetBackdropColor(0.2, 0.15, 0.1, 0.95)
    card:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)

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
    scrollFrame = CreateFrame("ScrollFrame", "KeySorterGroupScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(self, w, h)
        scrollChild:SetWidth(w)
    end)
end

function KS.UpdateGroupView()
    if not scrollChild then return end

    -- Clear existing cards
    for _, card in ipairs(groupCards) do
        card:Hide()
        card:SetParent(nil)
    end
    wipe(groupCards)
    if unassignedCard then
        unassignedCard:Hide()
        unassignedCard:SetParent(nil)
        unassignedCard = nil
    end

    if #KS.groups == 0 then
        local noData = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noData:SetPoint("CENTER", 0, 0)
        noData:SetText("No groups yet. Click Sort to generate groups.")
        noData:SetTextColor(0.5, 0.5, 0.5)
        scrollChild:SetHeight(100)
        return
    end

    -- Layout cards in a grid (3 per row)
    local cardsPerRow = 3
    local totalWidth = scrollChild:GetWidth()
    if totalWidth < 1 then totalWidth = 650 end

    local xStart = 0
    local yStart = -CARD_PADDING
    local row, col = 0, 0

    for i, group in ipairs(KS.groups) do
        local x = xStart + col * (CARD_WIDTH + CARD_PADDING)
        local y = yStart - row * (CARD_HEIGHT + CARD_PADDING)

        local card = CreateGroupCard(scrollChild, i, group, x, y)
        table.insert(groupCards, card)

        col = col + 1
        if col >= cardsPerRow then
            col = 0
            row = row + 1
        end
    end

    -- Unassigned section below cards
    local lastRow = math.ceil(#KS.groups / cardsPerRow)
    local unassignedY = yStart - lastRow * (CARD_HEIGHT + CARD_PADDING) - CARD_PADDING

    local unHeight = 0
    if #KS.unassigned > 0 then
        unassignedCard, unHeight = CreateUnassignedSection(scrollChild, unassignedY)
    end

    local totalHeight = math.abs(unassignedY) + unHeight + CARD_PADDING
    scrollChild:SetHeight(totalHeight)
end
