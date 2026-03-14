local addonName, KS = ...

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

-- Squared 1px border backdrop (modern flat look)
local BACKDROP_BUTTON = {
    bgFile = "Interface/BUTTONS/WHITE8X8",
    edgeFile = "Interface/BUTTONS/WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local BACKDROP_PANEL = {
    bgFile = "Interface/BUTTONS/WHITE8X8",
    edgeFile = "Interface/BUTTONS/WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Expose for reuse by UI files
KS.BACKDROP_BUTTON = BACKDROP_BUTTON
KS.BACKDROP_PANEL = BACKDROP_PANEL

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
-- Button
---------------------------------------------------------------------------
function KS.CreateButton(parent, text, colorName, width, height)
    local c = ResolveColor(colorName)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)

    btn:SetBackdrop(BACKDROP_BUTTON)
    btn:SetBackdropColor(unpack(c.n))
    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    if text then label:SetText(text) end
    btn._label = label
    btn._color = c

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(self._color.h))
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        if not self._locked then
            self:SetBackdropColor(unpack(self._color.n))
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
    end)

    btn:SetScript("OnMouseDown", function(self)
        self._label:SetPoint("CENTER", 0, -1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self._label:SetPoint("CENTER", 0, 0)
    end)

    function btn:SetOnClick(fn)
        self:SetScript("OnClick", fn)
    end

    function btn:SetText(t)
        self._label:SetText(t)
    end

    function btn:GetText()
        return self._label:GetText()
    end

    function btn:SetColor(colorOrName)
        self._color = ResolveColor(colorOrName)
        if not self._locked then
            self:SetBackdropColor(unpack(self._color.n))
        end
    end

    function btn:LockHighlight()
        self._locked = true
        self:SetBackdropColor(unpack(self._color.h))
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    function btn:UnlockHighlight()
        self._locked = false
        self:SetBackdropColor(unpack(self._color.n))
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end

    function btn:SetEnabled(enabled)
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
-- Scroll Frame (clean, minimal thumb, no arrows)
---------------------------------------------------------------------------
function KS.CreateScrollFrame(parent, name)
    local TRACK_WIDTH = 6
    local TRACK_GAP = 4   -- gap between content and scrollbar

    local scrollFrame = CreateFrame("ScrollFrame", name, parent)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -(TRACK_WIDTH + TRACK_GAP * 2), 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    -- Set a sensible default width; OnSizeChanged will correct it
    scrollChild:SetWidth(math.max(scrollFrame:GetWidth(), 600))
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Thin scroll track (sits in the gap to the right of the scroll frame)
    local track = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    track:SetWidth(TRACK_WIDTH)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", TRACK_WIDTH + TRACK_GAP, 0)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", TRACK_WIDTH + TRACK_GAP, 0)
    track:SetBackdrop(BACKDROP_BUTTON)
    track:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    track:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.5)

    -- Scroll thumb
    local thumb = CreateFrame("Frame", nil, track, "BackdropTemplate")
    thumb:SetWidth(6)
    thumb:SetHeight(30)
    thumb:SetBackdrop(BACKDROP_BUTTON)
    thumb:SetBackdropColor(0.4, 0.4, 0.4, 0.8)
    thumb:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    thumb:EnableMouse(true)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:Hide()

    thumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.5, 0.5, 1)
    end)
    thumb:SetScript("OnLeave", function(self)
        if not self._dragging then
            self:SetBackdropColor(0.4, 0.4, 0.4, 0.8)
        end
    end)

    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        self._dragging = true
        self._startY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self._startScroll = scrollFrame:GetVerticalScroll()
    end)
    thumb:SetScript("OnDragStop", function(self)
        self._dragging = false
        if not self:IsMouseOver() then
            self:SetBackdropColor(0.4, 0.4, 0.4, 0.8)
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

    -- Mouse wheel (correct event name: OnMouseWheel)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scroll = self:GetVerticalScroll() - (delta * 20)
        self:SetVerticalScroll(math.max(0, math.min(scroll, self:GetVerticalScrollRange())))
    end)

    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        if scrollRange <= 0 then
            thumb:Hide()
            return
        end
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
        scrollChild:SetWidth(math.max(w, 1))
        UpdateThumb()
    end)

    return scrollFrame, scrollChild
end

---------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------
function KS.CreateDropdown(parent, width, height)
    height = height or 24
    local dd = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dd:SetSize(width, height)
    dd:EnableMouse(true)

    dd:SetBackdrop(BACKDROP_BUTTON)
    dd:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    dd:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 6, 0)
    label:SetPoint("RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    label:SetText("Select...")
    dd._label = label

    local arrow = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("|cffaaaaaav|r")

    dd._items = {}
    dd._selectedValue = nil
    dd._onSelect = nil

    local menu = CreateFrame("Frame", nil, dd, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop(BACKDROP_PANEL)
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    menu:Hide()

    local menuButtons = {}

    local function CloseMenu()
        menu:Hide()
    end

    local function BuildMenu()
        for _, mb in ipairs(menuButtons) do mb:Hide() end
        local itemHeight = 20
        local count = #dd._items
        menu:SetSize(width, count * itemHeight + 4)
        menu:SetPoint("TOP", dd, "BOTTOM", 0, -1)

        for i, item in ipairs(dd._items) do
            if not menuButtons[i] then
                local mb = CreateFrame("Button", nil, menu, "BackdropTemplate")
                mb:SetHeight(itemHeight)
                mb:SetPoint("TOPLEFT", 2, -(i - 1) * itemHeight - 2)
                mb:SetPoint("TOPRIGHT", -2, -(i - 1) * itemHeight - 2)
                mb:SetBackdrop(BACKDROP_BUTTON)
                mb:SetBackdropColor(0, 0, 0, 0)
                mb:SetBackdropBorderColor(0, 0, 0, 0)
                mb:SetScript("OnEnter", function(self) self:SetBackdropColor(0, 0.5, 0.8, 0.3) end)
                mb:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
                local txt = mb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetPoint("LEFT", 4, 0)
                txt:SetJustifyH("LEFT")
                mb._text = txt
                menuButtons[i] = mb
            end
            local mb = menuButtons[i]
            mb._text:SetText(item.text)
            mb:SetScript("OnClick", function()
                dd._selectedValue = item.value
                label:SetText(item.text)
                CloseMenu()
                if dd._onSelect then dd._onSelect(item.value, item.text, i) end
            end)
            mb:Show()
        end
    end

    dd:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) end)
    dd:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end)
    dd:SetScript("OnMouseDown", function()
        if menu:IsShown() then CloseMenu() else BuildMenu(); menu:Show() end
    end)

    local closer = CreateFrame("Button", nil, menu)
    closer:SetAllPoints(UIParent)
    closer:SetFrameLevel(menu:GetFrameLevel() - 1)
    closer:SetScript("OnClick", CloseMenu)
    closer:Hide()
    menu:HookScript("OnShow", function() closer:Show() end)
    menu:HookScript("OnHide", function() closer:Hide() end)

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
-- Slider (flat squared style matching the rest of the UI)
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
    valText:SetTextColor(0, 0.8, 1)

    -- Slider track (flat bar)
    local trackHeight = 6
    local trackFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    trackFrame:SetPoint("TOPLEFT", 0, -18)
    trackFrame:SetPoint("TOPRIGHT", 0, -18)
    trackFrame:SetHeight(trackHeight)
    trackFrame:SetBackdrop(BACKDROP_BUTTON)
    trackFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    trackFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    -- Fill bar (shows progress from min to current value)
    local fill = trackFrame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetHeight(trackHeight - 2)
    fill:SetColorTexture(0, 0.5, 0.8, 0.7)

    -- Thumb (squared, draggable)
    local thumbW, thumbH = 12, 14
    local thumb = CreateFrame("Frame", nil, trackFrame, "BackdropTemplate")
    thumb:SetSize(thumbW, thumbH)
    thumb:SetBackdrop(BACKDROP_BUTTON)
    thumb:SetBackdropColor(0.35, 0.35, 0.35, 1)
    thumb:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    thumb:SetFrameLevel(trackFrame:GetFrameLevel() + 2)
    thumb:EnableMouse(true)

    thumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.5, 0.5, 1)
        self:SetBackdropBorderColor(0, 0.8, 1, 1)
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

        -- Position thumb centered on the value point
        local usable = trackWidth - thumbW
        local xOff = ratio * usable
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", trackFrame, "LEFT", xOff, 0)

        -- Fill bar width
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
        self:SetBackdropBorderColor(0, 0.8, 1, 1)
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

    -- Click anywhere on track to jump
    trackFrame:EnableMouse(true)
    trackFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local mouseX = GetCursorPosition() / self:GetEffectiveScale()
            SetValueInternal(ValueFromMouseX(mouseX))
        end
    end)

    -- Mouse wheel on the whole container
    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function(_, delta)
        SetValueInternal(currentValue + delta * step)
    end)

    -- Initial layout
    trackFrame:SetScript("OnSizeChanged", function() UpdateVisuals() end)
    valText:SetText(tostring(minVal))
    UpdateVisuals()

    container._slider = true
    container._currentValue = function() return currentValue end
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
-- Tooltip helpers
---------------------------------------------------------------------------
function KS.ShowTooltip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if title then GameTooltip:AddLine(title, 1, 1, 1) end
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end

function KS.HideTooltip()
    GameTooltip:Hide()
end

function KS.AddTooltip(frame, title, ...)
    local lines = { ... }
    frame:HookScript("OnEnter", function(self)
        KS.ShowTooltip(self, title, unpack(lines))
    end)
    frame:HookScript("OnLeave", function()
        KS.HideTooltip()
    end)
end
