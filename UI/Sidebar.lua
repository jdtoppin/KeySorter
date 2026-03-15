local addonName, KS = ...

local SIDEBAR_WIDTH = 140
local HEADER_HEIGHT = 28
local BUTTON_HEIGHT = 22

function KS.CreateSidebar(parent)
    local sidebar = CreateFrame("Frame", nil, parent)
    sidebar:SetPoint("TOPLEFT", 1, -1)
    sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(SIDEBAR_WIDTH)

    -- Background
    local bg = sidebar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.06, 0.95)

    -- Right edge border (1px)
    local border = sidebar:CreateTexture(nil, "BORDER")
    border:SetWidth(1)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.25, 0.25, 0.25, 1)

    ---------------------------------------------------------------------------
    -- Header (drag handle + logo)
    ---------------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, sidebar)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        local point, _, relPoint, x, y = parent:GetPoint()
        KeySorterDB.point = { point, nil, relPoint, x, y }
    end)

    -- Header bottom border
    local headerBorder = header:CreateTexture(nil, "BORDER")
    headerBorder:SetHeight(1)
    headerBorder:SetPoint("BOTTOMLEFT", 0, 0)
    headerBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    headerBorder:SetColorTexture(0.25, 0.25, 0.25, 1)

    -- Logo
    local logo = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    logo:SetPoint("LEFT", 10, 0)
    logo:SetText("KeySorter")
    logo:SetTextColor(0, 0.8, 1)

    ---------------------------------------------------------------------------
    -- Navigation buttons
    ---------------------------------------------------------------------------
    local NAV_ITEMS = {
        { key = "roster",   icon = KS.MEDIA.IconRoster,   label = "Roster" },
        { key = "groups",   icon = KS.MEDIA.IconGroups,   label = "Groups" },
        "SEPARATOR",
        { key = "settings", icon = KS.MEDIA.IconSettings, label = "Settings" },
        { key = "about",    icon = KS.MEDIA.IconAbout,    label = "About" },
    }

    local buttons = {}
    local selectedKey = nil
    sidebar._buttons = buttons

    local navY = -HEADER_HEIGHT - 8

    -- Animate a texture's width via the parent button's OnUpdate
    local function AnimateWidth(texture, targetWidth, duration, onDone)
        local parentBtn = texture:GetParent()
        local startWidth = texture:GetWidth()
        if startWidth < 1 then startWidth = 1 end
        local elapsed = 0
        parentBtn._widthAnimOnDone = onDone
        parentBtn:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local t = math.min(elapsed / duration, 1)
            local w = startWidth + (targetWidth - startWidth) * t
            texture:SetWidth(math.max(w, 1))
            if t >= 1 then
                self:SetScript("OnUpdate", nil)
                if self._widthAnimOnDone then
                    self._widthAnimOnDone()
                    self._widthAnimOnDone = nil
                end
            end
        end)
    end

    local function CreateNavButton(item, yOffset)
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetHeight(BUTTON_HEIGHT)
        btn:SetPoint("TOPLEFT", 2, yOffset)
        btn:SetPoint("TOPRIGHT", -3, yOffset)

        -- Gradient highlight
        local highlight = btn:CreateTexture(nil, "BORDER")
        highlight:SetPoint("TOPLEFT", 0, 0)
        highlight:SetPoint("BOTTOMLEFT", 0, 0)
        highlight:SetWidth(1)
        highlight:SetTexture(KS.MEDIA.GradientH)
        highlight:SetVertexColor(0, 0.8, 1, 1)
        btn._highlight = highlight

        -- Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexture(item.icon)
        icon:SetVertexColor(0.5, 0.5, 0.5)
        btn._icon = icon

        -- Label
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        label:SetText(item.label)
        label:SetTextColor(0.6, 0.6, 0.6)
        btn._label = label

        btn._key = item.key

        -- Push effect
        btn:SetScript("OnMouseDown", function(self)
            icon:SetPoint("LEFT", 6, -1)
        end)
        btn:SetScript("OnMouseUp", function(self)
            icon:SetPoint("LEFT", 6, 0)
        end)

        -- Hover
        btn:SetScript("OnEnter", function(self)
            if self._key ~= selectedKey then
                AnimateWidth(highlight, 7, 0.1)
                highlight:Show()
                icon:SetVertexColor(1, 1, 1)
                label:SetTextColor(1, 1, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if self._key ~= selectedKey then
                AnimateWidth(highlight, 1, 0.1, function()
                    if self._key ~= selectedKey then
                        highlight:Hide()
                    end
                end)
                icon:SetVertexColor(0.5, 0.5, 0.5)
                label:SetTextColor(0.6, 0.6, 0.6)
            end
        end)

        -- Click
        btn:SetScript("OnClick", function(self)
            if KS.SetTab then
                KS.SetTab(self._key)
            end
        end)

        return btn
    end

    for _, item in ipairs(NAV_ITEMS) do
        if item == "SEPARATOR" then
            local sep = sidebar:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", 6, navY - 4)
            sep:SetPoint("TOPRIGHT", -6, navY - 4)
            sep:SetColorTexture(0.25, 0.25, 0.25, 1)
            navY = navY - 10
        else
            local btn = CreateNavButton(item, navY)
            buttons[item.key] = btn
            navY = navY - BUTTON_HEIGHT - 6
        end
    end

    ---------------------------------------------------------------------------
    -- Select / deselect buttons
    ---------------------------------------------------------------------------
    function sidebar:SelectButton(key)
        -- Deselect old
        if selectedKey and selectedKey ~= key and buttons[selectedKey] then
            local oldBtn = buttons[selectedKey]
            AnimateWidth(oldBtn._highlight, 1, 0.15, function()
                oldBtn._highlight:Hide()
            end)
            oldBtn._icon:SetVertexColor(0.5, 0.5, 0.5)
            oldBtn._label:SetTextColor(0.6, 0.6, 0.6)
        end

        -- Select new
        selectedKey = key
        if buttons[key] then
            local btn = buttons[key]
            btn._highlight:Show()
            AnimateWidth(btn._highlight, btn:GetWidth(), 0.15)
            btn._icon:SetVertexColor(0, 0.8, 1)
            btn._label:SetTextColor(1, 1, 1)
        end
    end

    -- Deferred highlight fix (button widths aren't final until first layout)
    C_Timer.After(0, function()
        if selectedKey and buttons[selectedKey] then
            buttons[selectedKey]._highlight:SetWidth(buttons[selectedKey]:GetWidth())
        end
    end)

    return sidebar
end
