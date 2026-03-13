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
-- KS.CreateButton(parent, text, colorName, width, height)
-- colorName: "accent", "green", "blue", "red", "widget", "gray_hover", "dark"
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

    -- Hover effect
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(c.h))
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        if not self._locked then
            self:SetBackdropColor(unpack(c.n))
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
    end)

    -- Push effect
    btn:SetScript("OnMouseDown", function(self)
        label:SetPoint("CENTER", 0, -1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        label:SetPoint("CENTER", 0, 0)
    end)

    -- API
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
        local nc = ResolveColor(colorOrName)
        c = nc
        self:SetBackdropColor(unpack(c.n))
    end

    function btn:LockHighlight()
        self._locked = true
        self:SetBackdropColor(unpack(c.h))
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    function btn:UnlockHighlight()
        self._locked = false
        self:SetBackdropColor(unpack(c.n))
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
-- KS.CreateScrollFrame(parent)
-- Returns scrollFrame, scrollChild
function KS.CreateScrollFrame(parent, name)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -10, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Thin scroll track
    local track = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    track:SetWidth(6)
    track:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, 0)
    track:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 0)
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
    scrollFrame._thumb = thumb
    scrollFrame._track = track

    -- Hover effect on thumb
    thumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.5, 0.5, 1)
    end)
    thumb:SetScript("OnLeave", function(self)
        if not self._dragging then
            self:SetBackdropColor(0.4, 0.4, 0.4, 0.8)
        end
    end)

    -- Drag to scroll
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

    -- Mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheelScroll", function(self, delta)
        local scroll = self:GetVerticalScroll() - (delta * 20)
        self:SetVerticalScroll(math.max(0, math.min(scroll, self:GetVerticalScrollRange())))
    end)

    -- Update thumb position/size on scroll
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
        scrollChild:SetWidth(w)
        UpdateThumb()
    end)

    return scrollFrame, scrollChild
end

---------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------
-- KS.CreateDropdown(parent, width, height)
-- Returns a dropdown frame. Use :SetItems(items) and :SetOnSelect(fn).
-- items = { { text = "Label", value = val }, ... }
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

    -- Down arrow (simple triangle via font)
    local arrow = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("|cffaaaaaa\226\150\188|r") -- ▼ unicode

    dd._items = {}
    dd._selectedValue = nil
    dd._onSelect = nil

    -- Menu frame
    local menu = CreateFrame("Frame", nil, dd, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop(BACKDROP_PANEL)
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    menu:Hide()
    dd._menu = menu

    local menuButtons = {}
    dd._menuButtons = menuButtons

    local function CloseMenu()
        menu:Hide()
    end

    local function BuildMenu()
        for _, mb in ipairs(menuButtons) do
            mb:Hide()
        end

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

                -- Hover highlight
                mb:SetBackdrop(BACKDROP_BUTTON)
                mb:SetBackdropColor(0, 0, 0, 0)
                mb:SetBackdropBorderColor(0, 0, 0, 0)
                mb:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0, 0.5, 0.8, 0.3)
                end)
                mb:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(0, 0, 0, 0)
                end)

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
                if dd._onSelect then
                    dd._onSelect(item.value, item.text, i)
                end
            end)
            mb:Show()
        end
    end

    -- Hover effect on dropdown itself
    dd:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)
    dd:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end)

    dd:SetScript("OnMouseDown", function()
        if menu:IsShown() then
            CloseMenu()
        else
            BuildMenu()
            menu:Show()
        end
    end)

    -- Click-away closer
    local closer = CreateFrame("Button", nil, menu)
    closer:SetAllPoints(UIParent)
    closer:SetFrameLevel(menu:GetFrameLevel() - 1)
    closer:SetScript("OnClick", CloseMenu)
    closer:Hide()
    menu:HookScript("OnShow", function() closer:Show() end)
    menu:HookScript("OnHide", function() closer:Hide() end)

    -- API
    function dd:SetItems(items)
        self._items = items
    end

    function dd:SetOnSelect(fn)
        self._onSelect = fn
    end

    function dd:SetSelected(value)
        self._selectedValue = value
        for _, item in ipairs(self._items) do
            if item.value == value then
                self._label:SetText(item.text)
                return
            end
        end
    end

    function dd:GetSelected()
        return self._selectedValue
    end

    return dd
end

---------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------
-- KS.CreateSlider(parent, label, min, max, step, width)
function KS.CreateSlider(parent, labelText, minVal, maxVal, step, width)
    width = width or 160

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 40)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)

    -- Value text
    local valText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("TOPRIGHT", 0, 0)

    -- Slider
    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -16)
    slider:SetPoint("TOPRIGHT", 0, -16)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(minVal)

    -- Hide default text
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    valText:SetText(tostring(minVal))

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valText:SetText(tostring(value))
        if container._onChange then
            container._onChange(value)
        end
    end)

    container._slider = slider
    container._valText = valText

    -- API
    function container:SetOnChange(fn)
        self._onChange = fn
    end

    function container:SetValue(v)
        self._slider:SetValue(v)
    end

    function container:GetValue()
        return self._slider:GetValue()
    end

    return container
end

---------------------------------------------------------------------------
-- Tooltip helpers
---------------------------------------------------------------------------
function KS.ShowTooltip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if title then
        GameTooltip:AddLine(title, 1, 1, 1)
    end
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then
            GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
        end
    end
    GameTooltip:Show()
end

function KS.HideTooltip()
    GameTooltip:Hide()
end

-- Attach tooltip to a frame (convenience)
-- KS.AddTooltip(frame, title, line1, line2, ...)
function KS.AddTooltip(frame, title, ...)
    local lines = { ... }
    frame:HookScript("OnEnter", function(self)
        KS.ShowTooltip(self, title, unpack(lines))
    end)
    frame:HookScript("OnLeave", function()
        KS.HideTooltip()
    end)
end
