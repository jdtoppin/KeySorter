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

local BACKDROP_BUTTON = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local BACKDROP_PANEL = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
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
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    if text then label:SetText(text) end
    btn._label = label

    -- Hover effect
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(c.h))
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        if not self._locked then
            self:SetBackdropColor(unpack(c.n))
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
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
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end

    function btn:UnlockHighlight()
        self._locked = false
        self:SetBackdropColor(unpack(c.n))
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
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
    dd:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 6, 0)
    label:SetPoint("RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    label:SetText("Select...")
    dd._label = label

    -- Arrow
    local arrow = dd:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTexture("Interface/Buttons/UI-SortArrow")
    arrow:SetTexCoord(0, 0.5625, 1, 0) -- down arrow

    dd._items = {}
    dd._selectedValue = nil
    dd._onSelect = nil

    -- Menu frame
    local menu = CreateFrame("Frame", nil, dd, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop(BACKDROP_PANEL)
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    menu:Hide()
    dd._menu = menu

    local menuButtons = {}
    dd._menuButtons = menuButtons

    local function CloseMenu()
        menu:Hide()
    end

    local function BuildMenu()
        -- Hide existing
        for _, mb in ipairs(menuButtons) do
            mb:Hide()
        end

        local itemHeight = 20
        local count = #dd._items
        menu:SetSize(width, count * itemHeight + 8)
        menu:SetPoint("TOP", dd, "BOTTOM", 0, -2)

        for i, item in ipairs(dd._items) do
            if not menuButtons[i] then
                local mb = CreateFrame("Button", nil, menu)
                mb:SetHeight(itemHeight)
                mb:SetPoint("TOPLEFT", 4, -(i - 1) * itemHeight - 4)
                mb:SetPoint("TOPRIGHT", -4, -(i - 1) * itemHeight - 4)

                local hl = mb:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(0, 0.5, 0.8, 0.3)

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

    dd:SetScript("OnMouseDown", function()
        if menu:IsShown() then
            CloseMenu()
        else
            BuildMenu()
            menu:Show()
        end
    end)

    -- Close menu when clicking elsewhere
    menu:SetScript("OnShow", function()
        menu:SetPropagateKeyboardInput(true)
    end)
    menu:SetScript("OnHide", function() end)

    -- Close on escape or clicking away
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
