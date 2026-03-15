local addonName, KS = ...

---------------------------------------------------------------------------
-- Accent color constant (used throughout widgets)
---------------------------------------------------------------------------
local ACCENT_R, ACCENT_G, ACCENT_B = 0, 0.8, 1

---------------------------------------------------------------------------
-- Color presets
---------------------------------------------------------------------------
local COLORS = {
    accent      = { n = {0, 0.5, 0.8, 0.7},  h = {0, 0.6, 1, 1} },
    green       = { n = {0.1, 0.6, 0.1, 0.6}, h = {0.1, 0.7, 0.1, 1} },
    blue        = { n = {0, 0.4, 0.8, 0.6},   h = {0, 0.5, 1, 1} },
    red         = { n = {0.6, 0.1, 0.1, 0.6}, h = {0.7, 0.15, 0.15, 1} },
    widget      = { n = {0.2, 0.2, 0.2, 0.7}, h = {0.3, 0.3, 0.3, 0.9} },
    gray_hover  = { n = {0, 0, 0, 0},         h = {1, 1, 1, 0.1} },
    dark        = { n = {0.12, 0.12, 0.12, 0.9}, h = {0.18, 0.18, 0.18, 0.95} },
}

---------------------------------------------------------------------------
-- Shared backdrop (replaces BACKDROP_BUTTON and BACKDROP_PANEL)
---------------------------------------------------------------------------
local BACKDROP = {
    bgFile = "Interface/BUTTONS/WHITE8X8",
    edgeFile = "Interface/BUTTONS/WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Expose backdrop for consumers that need global names (can't use CreateBorderedFrame)
KS.BACKDROP = BACKDROP

-- Media paths
local MEDIA_PATH = "Interface/AddOns/" .. addonName .. "/Media/"
KS.MEDIA = {
    ArrowUp      = MEDIA_PATH .. "ArrowUp",
    ArrowDown    = MEDIA_PATH .. "ArrowDown",
    Lock         = MEDIA_PATH .. "Lock",
    IconRoster   = MEDIA_PATH .. "IconRoster",
    IconGroups   = MEDIA_PATH .. "IconGroups",
    IconSettings = MEDIA_PATH .. "IconSettings",
    IconAbout    = MEDIA_PATH .. "IconAbout",
    GradientH    = MEDIA_PATH .. "GradientH",
    LogoFull     = MEDIA_PATH .. "LogoFull",
    LogoKS       = MEDIA_PATH .. "LogoKS",
    IconGather   = MEDIA_PATH .. "IconGather",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function ResolveColor(color)
    if type(color) == "string" then
        return COLORS[color] or COLORS.widget
    elseif type(color) == "table" and color.n then
        return color
    end
    return COLORS.widget
end

---------------------------------------------------------------------------
-- Bordered Frame
---------------------------------------------------------------------------
function KS.CreateBorderedFrame(parent, width, height, bgColor, borderColor)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if width and height then f:SetSize(width, height) end
    f:SetBackdrop(BACKDROP)

    local bg = bgColor or { 0.1, 0.1, 0.1, 0.9 }
    local bd = borderColor or { 0, 0, 0, 1 }
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(bd))

    f._bgColor = bg
    f._borderColor = bd

    function f:SetBorderColor(r, g, b, a)
        self._borderColor = { r, g, b, a or 1 }
        self:SetBackdropBorderColor(r, g, b, a or 1)
    end

    function f:SetBackgroundColor(r, g, b, a)
        self._bgColor = { r, g, b, a or 1 }
        self:SetBackdropColor(r, g, b, a or 1)
    end

    return f
end

---------------------------------------------------------------------------
-- Backdrop Highlight (hover brightening for any frame)
---------------------------------------------------------------------------
function KS.SetBackdropHighlight(frame, borderHighlight, bgHighlight)
    frame._bdHighlight = borderHighlight
    frame._bgHighlight = bgHighlight

    frame:HookScript("OnEnter", function(self)
        if borderHighlight then
            self:SetBackdropBorderColor(unpack(borderHighlight))
        end
        if bgHighlight then
            self:SetBackdropColor(unpack(bgHighlight))
        end
    end)
    frame:HookScript("OnLeave", function(self)
        if self._borderColor then
            self:SetBackdropBorderColor(unpack(self._borderColor))
        end
        if self._bgColor then
            self:SetBackdropColor(unpack(self._bgColor))
        end
    end)
end

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------
function KS.CreateButton(parent, text, colorName, width, height)
    local c = ResolveColor(colorName)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(BACKDROP)
    btn:SetBackdropColor(unpack(c.n))
    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    if text then label:SetText(text) end
    btn._label = label
    btn._color = c
    btn._borderColor = { 0.3, 0.3, 0.3, 1 }
    btn._locked = false

    -- Hover highlight closures (optional, set via methods)
    btn._highlightText = nil
    btn._unhighlightText = nil
    btn._highlightBorder = nil
    btn._unhighlightBorder = nil

    -- Animated highlight (opt-in via SetAnimatedHighlight)
    btn._animHighlight = false

    local function AnimateButtonHighlight(self, targetHeight, duration)
        if not self._animTex then return end
        local startHeight = self._animTex:GetHeight()
        if startHeight < 1 then startHeight = 1 end
        local elapsed = 0
        self:SetScript("OnUpdate", function(s, dt)
            elapsed = elapsed + dt
            local t = math.min(elapsed / duration, 1)
            local h = startHeight + (targetHeight - startHeight) * t
            s._animTex:SetHeight(math.max(h, 1))
            if t >= 1 then
                s:SetScript("OnUpdate", nil)
            end
        end)
    end

    btn:SetScript("OnEnter", function(self)
        if self._disabled then return end
        if self._animHighlight then
            AnimateButtonHighlight(self, self:GetHeight() - 2, 0.15)
            self._animTex:Show()
        else
            self:SetBackdropColor(unpack(self._color.h))
        end
        if self._highlightBorder then
            self._highlightBorder()
        else
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
        if self._highlightText then self._highlightText() end
    end)

    btn:SetScript("OnLeave", function(self)
        if self._disabled then return end
        if self._locked then return end
        if self._animHighlight then
            AnimateButtonHighlight(self, 1, 0.1)
        else
            self:SetBackdropColor(unpack(self._color.n))
        end
        if self._unhighlightBorder then
            self._unhighlightBorder()
        else
            self:SetBackdropBorderColor(unpack(self._borderColor))
        end
        if self._unhighlightText then self._unhighlightText() end
    end)

    -- Push effect
    btn:SetScript("OnMouseDown", function(self)
        if self._disabled then return end
        self._label:SetPoint("CENTER", 0, -1)
        if self._tex then self._tex:SetPoint("CENTER", 0, -1) end
    end)
    btn:SetScript("OnMouseUp", function(self)
        self._label:SetPoint("CENTER", 0, 0)
        if self._tex then self._tex:SetPoint("CENTER", 0, 0) end
    end)

    function btn:SetOnClick(fn)
        self:SetScript("OnClick", function(self, ...)
            if self._disabled then return end
            fn(self, ...)
        end)
    end

    function btn:SetText(t) self._label:SetText(t) end
    function btn:GetText() return self._label:GetText() end

    function btn:SetColor(colorOrName)
        self._color = ResolveColor(colorOrName)
        if not self._locked then
            self:SetBackdropColor(unpack(self._color.n))
        end
    end

    function btn:SetTextHighlightColor(r, g, b)
        if r then
            self._highlightText = function()
                self._label:SetTextColor(r, g, b)
            end
            self._unhighlightText = function()
                self._label:SetTextColor(1, 1, 1)
            end
        else
            self._highlightText = nil
            self._unhighlightText = nil
        end
    end

    function btn:SetBorderHighlightColor(r, g, b, a)
        if r then
            local hc = { r, g, b, a or 1 }
            self._highlightBorder = function()
                self:SetBackdropBorderColor(unpack(hc))
            end
            self._unhighlightBorder = function()
                self:SetBackdropBorderColor(unpack(self._borderColor))
            end
        else
            self._highlightBorder = nil
            self._unhighlightBorder = nil
        end
    end

    function btn:SetAnimatedHighlight(enabled)
        self._animHighlight = enabled
        if enabled and not self._animTex then
            local tex = self:CreateTexture(nil, "BORDER")
            tex:SetPoint("BOTTOMLEFT", 1, 1)
            tex:SetPoint("BOTTOMRIGHT", -1, 1)
            tex:SetHeight(1)
            tex:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.5)
            self._animTex = tex
        end
    end

    function btn:LockHighlight()
        self._locked = true
        self:SetBackdropColor(unpack(self._color.h))
        if self._highlightBorder then
            self._highlightBorder()
        else
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
        if self._highlightText then self._highlightText() end
    end

    function btn:UnlockHighlight()
        self._locked = false
        self:SetBackdropColor(unpack(self._color.n))
        if self._unhighlightBorder then
            self._unhighlightBorder()
        else
            self:SetBackdropBorderColor(unpack(self._borderColor))
        end
        if self._unhighlightText then self._unhighlightText() end
    end

    function btn:SetEnabled(enabled)
        self._disabled = not enabled
        if enabled then
            self._label:SetTextColor(1, 1, 1)
            self:EnableMouse(true)
            self:SetAlpha(1)
        else
            self._label:SetTextColor(0.4, 0.4, 0.4)
            self:EnableMouse(false)
            self:SetAlpha(0.5)
        end
    end

    return btn
end

---------------------------------------------------------------------------
-- Close Button ("x" icon, hover turns red)
---------------------------------------------------------------------------
function KS.CreateCloseButton(parent)
    local btn = KS.CreateButton(parent, "X", "widget", 20, 20)
    btn:SetAnimatedHighlight(true)
    btn:SetBorderHighlightColor(0.7, 0.15, 0.15, 1)
    btn:SetTextHighlightColor(1, 0.3, 0.3)
    btn._label:SetFont(btn._label:GetFont(), 10)
    return btn
end

---------------------------------------------------------------------------
-- Resize Button (corner grip)
---------------------------------------------------------------------------
function KS.CreateResizeButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)
    btn:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Grip dots (3x3 pattern in bottom-right corner)
    local grip = btn:CreateTexture(nil, "OVERLAY")
    grip:SetSize(12, 12)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    btn._grip = grip

    btn:SetScript("OnEnter", function(self)
        self._grip:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
    end)
    btn:SetScript("OnLeave", function(self)
        self._grip:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    end)

    -- Push effect
    btn:SetScript("OnMouseDown", function(self)
        self._grip:SetPoint("BOTTOMRIGHT", -1, 0)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self._grip:SetPoint("BOTTOMRIGHT", -1, 1)
    end)

    return btn
end

---------------------------------------------------------------------------
-- Custom Tooltip (Hybrid: styled frame for KS UI, GameTooltip for items)
---------------------------------------------------------------------------
local function CreateKSTooltip()
    local tip = CreateFrame("GameTooltip", "KeySorterTooltip", UIParent, "GameTooltipTemplate")
    tip:SetFrameStrata("TOOLTIP")
    tip:SetBackdrop(BACKDROP)
    tip:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    tip:SetBackdropBorderColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    return tip
end

function KS.ShowTooltip(owner, anchor, lines)
    if not KS.Tooltip then
        KS.Tooltip = CreateKSTooltip()
    end
    local tip = KS.Tooltip

    -- Match UI scale
    local scale = KeySorterDB and KeySorterDB.uiScale or 1.0
    tip:SetScale(scale)

    -- Translate anchor: "ANCHOR_RIGHT", "ANCHOR_TOP", etc.
    tip:SetOwner(owner, anchor or "ANCHOR_RIGHT")

    if not lines or #lines == 0 then return end

    for i, line in ipairs(lines) do
        if type(line) == "table" then
            if #line == 4 and type(line[2]) == "number" then
                -- { text, r, g, b } — colored single line
                if i == 1 then
                    tip:AddLine(line[1], line[2], line[3], line[4])
                else
                    tip:AddLine(line[1], line[2], line[3], line[4], true)
                end
            elseif #line >= 2 then
                -- { left, right } — double column
                tip:AddDoubleLine(line[1], line[2], 0.9, 0.8, 0.5, 1, 1, 1)
            end
        else
            -- String entry
            if i == 1 then
                tip:AddLine(line, ACCENT_R, ACCENT_G, ACCENT_B)
            else
                tip:AddLine(line, 0.8, 0.8, 0.8, true)
            end
        end
    end

    -- Re-apply backdrop after SetOwner (GameTooltipTemplate resets styling)
    tip:SetBackdrop(BACKDROP)
    tip:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    tip:SetBackdropBorderColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    tip:Show()
end

function KS.HideTooltip()
    if KS.Tooltip then KS.Tooltip:Hide() end
end

function KS.SetTooltip(widget, anchor, lines)
    widget._tooltipLines = lines
    widget._tooltipAnchor = anchor or "ANCHOR_RIGHT"

    if not widget._tooltipHooked then
        widget._tooltipHooked = true
        widget:HookScript("OnEnter", function(self)
            if self._tooltipLines then
                KS.ShowTooltip(self, self._tooltipAnchor, self._tooltipLines)
            end
        end)
        widget:HookScript("OnLeave", function()
            KS.HideTooltip()
        end)
    end
end

---------------------------------------------------------------------------
-- Scroll Frame (AF-style: 5px thin scrollbar, accent thumb, proportional)
---------------------------------------------------------------------------
function KS.CreateScrollFrame(parent, name)
    local TRACK_WIDTH = 5
    local TRACK_GAP = 2

    local scrollFrame = CreateFrame("ScrollFrame", name, parent)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -(TRACK_WIDTH + TRACK_GAP * 2), 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(math.max(scrollFrame:GetWidth(), 600))
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Thin scroll track
    local track = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    track:SetWidth(TRACK_WIDTH)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", TRACK_WIDTH + TRACK_GAP, 0)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", TRACK_WIDTH + TRACK_GAP, 0)
    track:SetBackdrop(BACKDROP)
    track:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
    track:SetBackdropBorderColor(0, 0, 0, 1)

    -- Scroll thumb (accent colored, proportional)
    local thumb = CreateFrame("Frame", nil, track, "BackdropTemplate")
    thumb:SetWidth(TRACK_WIDTH)
    thumb:SetHeight(30)
    thumb:SetBackdrop(BACKDROP)
    thumb:SetBackdropColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.7)
    thumb:SetBackdropBorderColor(0, 0, 0, 1)
    thumb:EnableMouse(true)
    thumb:SetHitRectInsets(-5, -5, 0, 0)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:Hide()

    -- Hover: alpha brightening
    thumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
    end)
    thumb:SetScript("OnLeave", function(self)
        if not self._dragging then
            self:SetBackdropColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.7)
        end
    end)

    -- Thumb dragging
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        self._dragging = true
        self._startY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self._startScroll = scrollFrame:GetVerticalScroll()
        self:SetBackdropColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
    end)
    thumb:SetScript("OnDragStop", function(self)
        self._dragging = false
        if not self:IsMouseOver() then
            self:SetBackdropColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.7)
        end
    end)
    thumb:SetScript("OnUpdate", function(self)
        if not self._dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self._startY - curY
        local trackHeight = track:GetHeight()
        local thumbHeight = self:GetHeight()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        if trackHeight - thumbHeight > 0 then
            local scroll = self._startScroll + (delta / (trackHeight - thumbHeight)) * scrollRange
            scrollFrame:SetVerticalScroll(math.max(0, math.min(scroll, scrollRange)))
        end
    end)

    -- Mouse wheel
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scroll = self:GetVerticalScroll() - (delta * 20)
        self:SetVerticalScroll(math.max(0, math.min(scroll, self:GetVerticalScrollRange())))
    end)

    -- Proportional thumb sizing & position
    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        if scrollRange <= 0 then
            thumb:Hide()
            -- Expand content area when scrollbar hidden
            scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
            return
        end
        -- Shrink content area for scrollbar
        scrollFrame:SetPoint("BOTTOMRIGHT", -(TRACK_WIDTH + TRACK_GAP * 2), 0)
        thumb:Show()
        local trackHeight = track:GetHeight()
        local childHeight = scrollChild:GetHeight()
        local visibleRatio = scrollFrame:GetHeight() / math.max(childHeight, 1)
        local thumbHeight = math.max(20, trackHeight * math.min(visibleRatio, 1))
        thumb:SetHeight(thumbHeight)

        local scrollPos = scrollFrame:GetVerticalScroll()
        local thumbOffset = (scrollPos / scrollRange) * (trackHeight - thumbHeight)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -thumbOffset)
    end

    scrollFrame:SetScript("OnScrollRangeChanged", function() UpdateThumb() end)
    scrollFrame:SetScript("OnVerticalScroll", function() UpdateThumb() end)
    scrollFrame:SetScript("OnSizeChanged", function(self, w, h)
        -- Respect any minimum width already set on scroll child
        local minW = scrollChild._minWidth or 1
        scrollChild:SetWidth(math.max(w, minW))
        UpdateThumb()
    end)

    return scrollFrame, scrollChild
end

---------------------------------------------------------------------------
-- Dropdown (AF-style: arrow icon, shared singleton list, ESC to close)
---------------------------------------------------------------------------
local dropdownList  -- shared singleton list frame

local function GetOrCreateDropdownList()
    if dropdownList then return dropdownList end

    dropdownList = CreateFrame("Frame", "KeySorterDropdownList", UIParent, "BackdropTemplate")
    dropdownList:SetFrameStrata("DIALOG")
    dropdownList:SetBackdrop(BACKDROP)
    dropdownList:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    dropdownList:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    dropdownList:Hide()
    dropdownList._buttons = {}

    -- ESC to close
    table.insert(UISpecialFrames, "KeySorterDropdownList")

    -- Closer (click outside to close)
    local closer = CreateFrame("Button", nil, dropdownList)
    closer:SetAllPoints(UIParent)
    closer:SetFrameLevel(dropdownList:GetFrameLevel() - 1)
    closer:SetScript("OnClick", function() dropdownList:Hide() end)
    closer:Hide()
    dropdownList:HookScript("OnShow", function() closer:Show() end)
    dropdownList:HookScript("OnHide", function() closer:Hide() end)
    dropdownList._closer = closer

    return dropdownList
end

function KS.CloseDropdown()
    if dropdownList then dropdownList:Hide() end
end

function KS.CreateDropdown(parent, width)
    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dd:SetSize(width, 22)
    dd:SetBackdrop(BACKDROP)
    dd:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    dd:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    dd._borderColor = { 0.3, 0.3, 0.3, 1 }

    -- Label text (no word wrap — truncate instead)
    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 6, 0)
    label:SetPoint("RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText("Select...")
    dd._label = label

    -- Arrow icon (down arrow)
    local arrow = dd:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(10, 10)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture(KS.MEDIA.ArrowDown)
    arrow:SetVertexColor(0.7, 0.7, 0.7)
    dd._arrow = arrow

    dd._items = {}
    dd._selectedValue = nil
    dd._onSelect = nil

    -- Animated highlight fill (matching button style)
    local ddHighlight = dd:CreateTexture(nil, "BORDER")
    ddHighlight:SetPoint("BOTTOMLEFT", 1, 1)
    ddHighlight:SetPoint("BOTTOMRIGHT", -1, 1)
    ddHighlight:SetHeight(1)
    ddHighlight:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.5)

    local function AnimateDDHighlight(targetHeight, duration)
        local startHeight = ddHighlight:GetHeight()
        if startHeight < 1 then startHeight = 1 end
        local elapsed = 0
        dd:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local t = math.min(elapsed / duration, 1)
            local h = startHeight + (targetHeight - startHeight) * t
            ddHighlight:SetHeight(math.max(h, 1))
            if t >= 1 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    -- Hover
    dd:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        arrow:SetVertexColor(1, 1, 1)
        AnimateDDHighlight(self:GetHeight() - 2, 0.15)
        ddHighlight:Show()
    end)
    dd:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(self._borderColor))
        arrow:SetVertexColor(0.7, 0.7, 0.7)
        AnimateDDHighlight(1, 0.1)
    end)

    -- Push effect
    dd:RegisterForClicks("LeftButtonUp")
    dd:SetScript("OnMouseDown", function(self)
        label:SetPoint("LEFT", 6, -1)
        arrow:SetPoint("RIGHT", -6, -1)
    end)
    dd:SetScript("OnMouseUp", function(self)
        label:SetPoint("LEFT", 6, 0)
        arrow:SetPoint("RIGHT", -6, 0)
    end)

    local function BuildList()
        local list = GetOrCreateDropdownList()
        -- Hide existing buttons
        for _, mb in ipairs(list._buttons) do mb:Hide() end

        local itemHeight = 20
        local count = #dd._items
        list:SetSize(width, count * itemHeight + 4)
        list:ClearAllPoints()
        list:SetPoint("TOP", dd, "BOTTOM", 0, -1)
        list:SetParent(dd)
        list:SetFrameStrata("DIALOG")

        for i, item in ipairs(dd._items) do
            if not list._buttons[i] then
                local mb = CreateFrame("Button", nil, list, "BackdropTemplate")
                mb:SetHeight(itemHeight)
                mb:SetBackdrop(BACKDROP)
                mb:SetBackdropColor(0, 0, 0, 0)
                mb:SetBackdropBorderColor(0, 0, 0, 0)

                mb:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.2)
                end)
                mb:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(0, 0, 0, 0)
                end)

                local txt = mb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetPoint("LEFT", 6, 0)
                txt:SetJustifyH("LEFT")
                mb._text = txt

                -- Selection indicator (accent border on left side)
                local sel = mb:CreateTexture(nil, "ARTWORK")
                sel:SetWidth(2)
                sel:SetPoint("TOPLEFT", 1, -1)
                sel:SetPoint("BOTTOMLEFT", 1, 1)
                sel:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
                sel:Hide()
                mb._selIndicator = sel

                list._buttons[i] = mb
            end
            local mb = list._buttons[i]
            mb:SetPoint("TOPLEFT", 2, -(i - 1) * itemHeight - 2)
            mb:SetPoint("TOPRIGHT", -2, -(i - 1) * itemHeight - 2)
            mb._text:SetText(item.text)

            -- Show selection indicator for current value
            if item.value == dd._selectedValue then
                mb._selIndicator:Show()
            else
                mb._selIndicator:Hide()
            end

            mb:SetScript("OnClick", function()
                dd._selectedValue = item.value
                label:SetText(item.text)
                list:Hide()
                if dd._onSelect then dd._onSelect(item.value, item.text, i) end
            end)
            mb:Show()
        end
    end

    dd:SetScript("OnClick", function()
        local list = GetOrCreateDropdownList()
        if list:IsShown() and list._currentOwner == dd then
            list:Hide()
        else
            KS.CloseDropdown()
            list._currentOwner = dd
            BuildList()
            list:Show()
            arrow:SetTexture(KS.MEDIA.ArrowUp)
        end
    end)

    -- Reset arrow when list hides (via owner tracking, not per-dropdown hooks)
    local function EnsureListHideHook()
        local list = GetOrCreateDropdownList()
        if not list._hideHooked then
            list._hideHooked = true
            list:HookScript("OnHide", function(self)
                if self._currentOwner and self._currentOwner._arrow then
                    self._currentOwner._arrow:SetTexture(KS.MEDIA.ArrowDown)
                end
                self._currentOwner = nil
            end)
        end
    end
    EnsureListHideHook()

    function dd:SetItems(items) self._items = items end
    function dd:SetOnSelect(fn) self._onSelect = fn end
    function dd:SetSelected(value)
        self._selectedValue = value
        for _, item in ipairs(self._items) do
            if item.value == value then self._label:SetText(item.text); return end
        end
    end
    function dd:GetSelected() return self._selectedValue end

    return dd
end

---------------------------------------------------------------------------
-- Slider (AF-style: fill bar, squared thumb, edit box)
---------------------------------------------------------------------------
function KS.CreateSlider(parent, labelText, minVal, maxVal, step, width)
    width = width or 160
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 36)

    -- Label (left)
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(0.7, 0.7, 0.7)

    -- Value readout (right, accent colored)
    local valText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("TOPRIGHT", 0, 0)
    valText:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B)

    -- Slider track
    local trackHeight = 6
    local trackFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    trackFrame:SetPoint("TOPLEFT", 0, -18)
    trackFrame:SetPoint("TOPRIGHT", 0, -18)
    trackFrame:SetHeight(trackHeight)
    trackFrame:SetBackdrop(BACKDROP)
    trackFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    trackFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    -- Fill bar
    local fill = trackFrame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetHeight(trackHeight - 2)
    fill:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.7)

    -- Thumb
    local thumbW, thumbH = 12, 14
    local thumb = CreateFrame("Frame", nil, trackFrame, "BackdropTemplate")
    thumb:SetSize(thumbW, thumbH)
    thumb:SetBackdrop(BACKDROP)
    thumb:SetBackdropColor(0.35, 0.35, 0.35, 1)
    thumb:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    thumb:SetFrameLevel(trackFrame:GetFrameLevel() + 2)
    thumb:EnableMouse(true)

    thumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.5, 0.5, 1)
        self:SetBackdropBorderColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    end)
    thumb:SetScript("OnLeave", function(self)
        if not self._dragging then
            self:SetBackdropColor(0.35, 0.35, 0.35, 1)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
    end)

    -- Internal state
    local currentValue = minVal

    local function UpdateVisuals()
        local trackWidth = trackFrame:GetWidth()
        if trackWidth < 1 then trackWidth = width end
        local range = maxVal - minVal
        local ratio = range > 0 and ((currentValue - minVal) / range) or 0
        ratio = math.max(0, math.min(ratio, 1))

        local usable = trackWidth - thumbW
        local xOff = ratio * usable
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", trackFrame, "LEFT", xOff, 0)
        fill:SetWidth(math.max(xOff + thumbW * 0.5, 1))

        valText:SetText(tostring(currentValue))
    end

    local function SetValueInternal(val)
        val = math.floor(val / step + 0.5) * step
        val = math.max(minVal, math.min(val, maxVal))
        if val == currentValue then return end
        currentValue = val
        UpdateVisuals()
        if container._onChange then container._onChange(currentValue) end
    end

    local function ValueFromMouseX(mouseX)
        local trackLeft = trackFrame:GetLeft()
        local trackWidth = trackFrame:GetWidth()
        if not trackLeft or trackWidth < 1 then return currentValue end
        local ratio = (mouseX - trackLeft) / trackWidth
        ratio = math.max(0, math.min(ratio, 1))
        return minVal + ratio * (maxVal - minVal)
    end

    -- Thumb drag
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        self._dragging = true
        self:SetBackdropColor(0.5, 0.5, 0.5, 1)
        self:SetBackdropBorderColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    end)
    thumb:SetScript("OnDragStop", function(self)
        self._dragging = false
        if not self:IsMouseOver() then
            self:SetBackdropColor(0.35, 0.35, 0.35, 1)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
    end)
    thumb:SetScript("OnUpdate", function(self)
        if not self._dragging then return end
        local mouseX = GetCursorPosition() / self:GetEffectiveScale()
        SetValueInternal(ValueFromMouseX(mouseX))
    end)

    -- Click on track to jump
    trackFrame:EnableMouse(true)
    trackFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local mouseX = GetCursorPosition() / self:GetEffectiveScale()
            SetValueInternal(ValueFromMouseX(mouseX))
        end
    end)

    -- Mouse wheel
    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function(_, delta)
        SetValueInternal(currentValue + delta * step)
    end)

    -- Initial layout
    trackFrame:SetScript("OnSizeChanged", function() UpdateVisuals() end)
    valText:SetText(tostring(minVal))
    UpdateVisuals()

    function container:SetOnChange(fn) self._onChange = fn end
    function container:SetValue(v)
        v = math.floor(v / step + 0.5) * step
        v = math.max(minVal, math.min(v, maxVal))
        currentValue = v
        UpdateVisuals()
    end
    function container:GetValue() return currentValue end

    return container
end

---------------------------------------------------------------------------
-- Switch (AF-style: segmented toggle with animated highlight)
---------------------------------------------------------------------------
function KS.CreateSwitch(parent, width, height, options)
    local container = KS.CreateBorderedFrame(parent, width, height, {0.1, 0.1, 0.1, 0.9}, {0.3, 0.3, 0.3, 1})
    container._options = options or {}
    container._buttons = {}
    container._selectedValue = nil
    container._onSelect = nil

    local numOptions = #container._options
    if numOptions == 0 then return container end

    local btnWidth = width / numOptions

    for i, opt in ipairs(container._options) do
        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(btnWidth, height)
        btn:SetPoint("LEFT", (i - 1) * btnWidth, 0)

        -- Highlight fill (grows from bottom when selected)
        local highlight = btn:CreateTexture(nil, "BACKGROUND")
        highlight:SetPoint("BOTTOMLEFT", 1, 1)
        highlight:SetPoint("BOTTOMRIGHT", -1, 1)
        highlight:SetHeight(1)
        highlight:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.6)
        btn._highlight = highlight
        btn._value = opt.value

        -- Label
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER", 0, 0)
        label:SetText(opt.text)
        btn._label = label

        -- Animate highlight height via OnUpdate (WoW has no native Height animation)
        local function AnimateHighlight(targetHeight)
            local startHeight = highlight:GetHeight()
            local elapsed = 0
            local duration = 0.15
            btn:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                local t = math.min(elapsed / duration, 1)
                local h = startHeight + (targetHeight - startHeight) * t
                highlight:SetHeight(math.max(h, 1))
                if t >= 1 then
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end

        btn:SetScript("OnClick", function(self)
            container:SetSelectedValue(self._value)
            if container._onSelect then
                container._onSelect(self._value)
            end
        end)

        -- Hover
        btn:SetScript("OnEnter", function(self)
            if self._value ~= container._selectedValue then
                self._label:SetTextColor(1, 1, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if self._value ~= container._selectedValue then
                self._label:SetTextColor(0.6, 0.6, 0.6)
            end
        end)

        -- Push effect
        btn:SetScript("OnMouseDown", function(self)
            self._label:SetPoint("CENTER", 0, -1)
        end)
        btn:SetScript("OnMouseUp", function(self)
            self._label:SetPoint("CENTER", 0, 0)
        end)

        btn._animateHighlight = AnimateHighlight
        container._buttons[i] = btn
    end

    function container:SetSelectedValue(value)
        self._selectedValue = value
        for _, btn in ipairs(self._buttons) do
            if btn._value == value then
                btn._animateHighlight(btn:GetHeight() - 2)
                btn._label:SetTextColor(1, 1, 1)
            else
                btn._animateHighlight(1)
                btn._label:SetTextColor(0.6, 0.6, 0.6)
            end
        end
    end

    function container:SetOnSelect(fn)
        self._onSelect = fn
    end

    return container
end

---------------------------------------------------------------------------
-- CheckButton (icon-based toggle, e.g., lock icon for groups)
---------------------------------------------------------------------------
function KS.CreateCheckButton(parent, iconPath, size, callback)
    size = size or 16
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetBackdrop(BACKDROP)
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    btn._borderColor = { 0.3, 0.3, 0.3, 1 }

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    if iconPath then icon:SetTexture(iconPath) end
    icon:SetVertexColor(0.4, 0.4, 0.4, 0.6)
    btn._icon = icon

    btn._checked = false
    btn._onToggle = callback

    -- Animated highlight
    local cbHighlight = btn:CreateTexture(nil, "BORDER")
    cbHighlight:SetPoint("BOTTOMLEFT", 1, 1)
    cbHighlight:SetPoint("BOTTOMRIGHT", -1, 1)
    cbHighlight:SetHeight(1)
    cbHighlight:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.4)

    local function AnimateCBHighlight(targetHeight, duration)
        local startHeight = cbHighlight:GetHeight()
        if startHeight < 1 then startHeight = 1 end
        local elapsed = 0
        btn:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local t = math.min(elapsed / duration, 1)
            local h = startHeight + (targetHeight - startHeight) * t
            cbHighlight:SetHeight(math.max(h, 1))
            if t >= 1 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    local function UpdateVisual()
        if btn._checked then
            icon:SetVertexColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
            btn:SetBackdropBorderColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.8)
        else
            icon:SetVertexColor(0.3, 0.3, 0.3, 0.5)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        btn._borderColor = btn._checked
            and { ACCENT_R, ACCENT_G, ACCENT_B, 0.8 }
            or { 0.3, 0.3, 0.3, 1 }
    end

    btn:SetScript("OnClick", function(self)
        self._checked = not self._checked
        UpdateVisual()
        if self._onToggle then self._onToggle(self._checked) end
    end)

    -- Push effect
    btn:SetScript("OnMouseDown", function(self)
        icon:SetPoint("CENTER", 0, -1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        icon:SetPoint("CENTER", 0, 0)
    end)

    -- Hover
    btn:SetScript("OnEnter", function(self)
        AnimateCBHighlight(self:GetHeight() - 2, 0.15)
        cbHighlight:Show()
        if not self._checked then
            icon:SetVertexColor(0.6, 0.6, 0.6, 0.8)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        AnimateCBHighlight(1, 0.1)
        UpdateVisual()
    end)

    function btn:SetChecked(checked)
        self._checked = checked
        UpdateVisual()
    end

    function btn:IsChecked()
        return self._checked
    end

    function btn:SetOnToggle(fn)
        self._onToggle = fn
    end

    UpdateVisual()
    return btn
end
