# Abstract Framework UI Refresh — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite KeySorter's widget system to match Abstract Framework's visual style, upgrading buttons, dropdowns, sliders, tooltips, scrollbars, drag-and-drop, and adding switch toggles and lock checkbuttons.

**Architecture:** Adapt & rewrite approach — no AF code is copied. All widgets are reimplemented from scratch in the `KS` namespace using KeySorter's existing cyan accent color (`0, 0.8, 1`). The migration is big-bang: Widgets.lua is fully rewritten and all consumer files are updated in one pass. `BACKDROP_PANEL` and `BACKDROP_BUTTON` constants are removed entirely.

**Tech Stack:** WoW Lua API (Interface 120000), BackdropTemplate, AnimationGroup API, TGA texture assets

**Spec:** `docs/superpowers/specs/2026-03-14-abstract-framework-ui-refresh-design.md`

---

## Chunk 1: Media Assets & Foundation Layer

### Task 1: Create TGA Media Assets

**Files:**
- Create: `Media/ArrowUp.tga`
- Create: `Media/ArrowDown.tga`
- Create: `Media/Lock.tga`
- Create: `scripts/generate_tga.py`

These are 16x16 white silhouette textures on transparent background, tintable via `SetVertexColor`. TGA is an uncompressed format that WoW reads natively.

- [ ] **Step 1: Write a Python script to generate the three TGA files**

```python
# scripts/generate_tga.py
# Generates 16x16 TGA files with alpha channel for WoW addon icons.
# TGA format: uncompressed RGBA, top-to-bottom, 32-bit.

import struct
import os

def write_tga(filename, pixels):
    """Write a 16x16 RGBA TGA file. pixels is a list of 256 (r,g,b,a) tuples."""
    header = struct.pack('<BBBHHBHHHHBB',
        0,    # ID length
        0,    # Color map type
        2,    # Image type (uncompressed true-color)
        0, 0, # Color map spec (unused)
        0,    # Color map entry size
        0, 0, # X origin
        16, 16, # Width, Height
        32,   # Bits per pixel
        0x28, # Image descriptor: top-left origin (0x20) + 8 alpha bits (0x08)
    )
    data = b''
    for r, g, b, a in pixels:
        data += struct.pack('BBBB', b, g, r, a)  # TGA stores BGRA
    with open(filename, 'wb') as f:
        f.write(header + data)

def make_arrow_up():
    """Upward-pointing triangle, centered in 16x16."""
    pixels = []
    for y in range(16):
        for x in range(16):
            # Triangle: apex at (8, 3), base from (2, 12) to (13, 12)
            # For each row y, the triangle spans from center-spread to center+spread
            row = y - 3
            if row < 0 or row > 9:
                pixels.append((0, 0, 0, 0))
            else:
                spread = row * 12 / 9 / 2  # half-width at this row
                center = 7.5
                if center - spread <= x <= center + spread:
                    pixels.append((255, 255, 255, 255))
                else:
                    pixels.append((0, 0, 0, 0))
    return pixels

def make_arrow_down():
    """Downward-pointing triangle, centered in 16x16."""
    pixels = []
    for y in range(16):
        for x in range(16):
            # Flip the up arrow vertically
            row = (15 - y) - 3
            if row < 0 or row > 9:
                pixels.append((0, 0, 0, 0))
            else:
                spread = row * 12 / 9 / 2
                center = 7.5
                if center - spread <= x <= center + spread:
                    pixels.append((255, 255, 255, 255))
                else:
                    pixels.append((0, 0, 0, 0))
    return pixels

def make_lock():
    """Simple padlock silhouette, centered in 16x16."""
    pixels = []
    W = (255, 255, 255, 255)
    T = (0, 0, 0, 0)
    # 16 rows, designed as a simple lock shape:
    # Rows 1-5: shackle (rounded arch)
    # Rows 6-14: lock body (rectangle)
    lock_bitmap = [
        "................",  # 0
        "....########....",  # 1 - padding adjusted
        "...##......##...",  # 2
        "...##......##...",  # 3
        "...##......##...",  # 4
        "...##......##...",  # 5
        "..############..",  # 6
        "..############..",  # 7
        "..############..",  # 8
        "..####.##.####..",  # 9 - keyhole top
        "..#####..#####..",  # 10 - keyhole
        "..#####..#####..",  # 11 - keyhole bottom
        "..############..",  # 12
        "..############..",  # 13
        "................",  # 14
        "................",  # 15
    ]
    # Re-center: the lock shape above uses . for transparent and # for white
    # Let's build a cleaner 16x16 lock
    lock_rows = [
        "                ",
        "     ######     ",
        "    ##    ##    ",
        "    ##    ##    ",
        "    ##    ##    ",
        "   ##      ##   ",
        "  ############  ",
        "  ############  ",
        "  ############  ",
        "  ##### #####   ",
        "  #####  ####   ",
        "  #####  ####   ",
        "  ############  ",
        "  ############  ",
        "  ############  ",
        "                ",
    ]
    for row in lock_rows:
        for ch in row:
            if ch == '#':
                pixels.append(W)
            else:
                pixels.append(T)
    return pixels

if __name__ == '__main__':
    media_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'Media')
    os.makedirs(media_dir, exist_ok=True)

    write_tga(os.path.join(media_dir, 'ArrowUp.tga'), make_arrow_up())
    write_tga(os.path.join(media_dir, 'ArrowDown.tga'), make_arrow_down())
    write_tga(os.path.join(media_dir, 'Lock.tga'), make_lock())
    print(f"Generated 3 TGA files in {media_dir}/")
```

- [ ] **Step 2: Run the script to generate the TGA files**

Run: `python3 scripts/generate_tga.py`
Expected: "Generated 3 TGA files in .../Media/"

- [ ] **Step 3: Verify the files exist**

Run: `ls -la Media/*.tga`
Expected: Three files (ArrowUp.tga, ArrowDown.tga, Lock.tga), each ~1KB

- [ ] **Step 4: Commit media assets**

```bash
git add Media/ArrowUp.tga Media/ArrowDown.tga Media/Lock.tga scripts/generate_tga.py
git commit -m "feat: add TGA media assets for arrows and lock icon"
```

---

### Task 2: Rewrite Widgets.lua — Foundation (BorderedFrame, Button, Tooltips)

**Files:**
- Modify: `Widgets.lua` (full rewrite, lines 1-516)

This task replaces the entire file with the new foundation layer. The interactive components (Dropdown, Slider, ScrollFrame) are added in Task 3.

- [ ] **Step 1: Write the new Widgets.lua foundation**

Replace the entire `Widgets.lua` with the foundation layer. This includes:

1. **Color presets** — same `COLORS` table, no changes
2. **`ResolveColor`** — same helper, no changes
3. **Shared backdrop table** — single `BACKDROP` constant (replaces both `BACKDROP_BUTTON` and `BACKDROP_PANEL`)
4. **`KS.CreateBorderedFrame(parent, width, height, bgColor, borderColor)`** — new foundation widget
5. **`KS.SetBackdropHighlight(frame, borderHighlight, bgHighlight)`** — new hover highlight system
6. **`KS.CreateButton(parent, text, colorName, width, height)`** — rewritten with new methods
7. **`KS.CreateCloseButton(parent)`** — new "x" icon button
8. **`KS.CreateResizeButton(parent)`** — new styled resize handle
9. **Custom tooltip system** — `KS.Tooltip`, `KS.ShowTooltip`, `KS.SetTooltip`, `KS.HideTooltip`

```lua
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
    ArrowUp   = MEDIA_PATH .. "ArrowUp",
    ArrowDown = MEDIA_PATH .. "ArrowDown",
    Lock      = MEDIA_PATH .. "Lock",
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

    btn:SetScript("OnEnter", function(self)
        if self._disabled then return end
        self:SetBackdropColor(unpack(self._color.h))
        -- Border: use custom highlight or default
        if self._highlightBorder then
            self._highlightBorder()
        else
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
        -- Text highlight
        if self._highlightText then self._highlightText() end
    end)

    btn:SetScript("OnLeave", function(self)
        if self._disabled then return end
        if self._locked then return end
        self:SetBackdropColor(unpack(self._color.n))
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
```

**Note:** This replaces the old `KS.BACKDROP_BUTTON`, `KS.BACKDROP_PANEL`, `KS.ShowTooltip(owner, title, ...)`, `KS.AddTooltip(frame, title, ...)`, and `KS.HideTooltip()`. The old constants and `AddTooltip` are removed.

- [ ] **Step 2: Verify the foundation compiles (no syntax errors)**

Run: `luac -p Widgets.lua` (or `luajit -bl Widgets.lua > /dev/null` if available)

If neither Lua compiler is available, visually verify bracket matching and string closure.

- [ ] **Step 3: Commit the foundation**

```bash
git add Widgets.lua
git commit -m "feat(widgets): rewrite foundation — BorderedFrame, Button, Tooltips

Replaces BACKDROP_BUTTON/BACKDROP_PANEL with CreateBorderedFrame.
Button gains SetTextHighlightColor, SetBorderHighlightColor.
Custom tooltip system (KS.Tooltip) with styled frame.
Adds CreateCloseButton and CreateResizeButton."
```

---

### Task 3: Rewrite Widgets.lua — Interactive Components

**Files:**
- Modify: `Widgets.lua` (append to file from Task 2)

Add the remaining interactive components to the end of `Widgets.lua`.

- [ ] **Step 1: Add ScrollFrame with AF-style scrollbar**

Append to `Widgets.lua`:

```lua
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
        scrollChild:SetWidth(math.max(w, 1))
        UpdateThumb()
    end)

    return scrollFrame, scrollChild
end
```

- [ ] **Step 2: Add Dropdown with arrow icons**

Append to `Widgets.lua`:

```lua
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

    -- Label text
    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 6, 0)
    label:SetPoint("RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
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

    -- Hover
    dd:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        arrow:SetVertexColor(1, 1, 1)
    end)
    dd:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(self._borderColor))
        arrow:SetVertexColor(0.7, 0.7, 0.7)
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
```

- [ ] **Step 3: Add Slider with edit box**

Append to `Widgets.lua`:

```lua
---------------------------------------------------------------------------
-- Slider (AF-style: fill bar, squared thumb, edit box)
---------------------------------------------------------------------------
function KS.CreateSlider(parent, labelText, minVal, maxVal, step, width)
    width = width or 160
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 50) -- taller to fit edit box

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

    -- Edit box (below track)
    local editBox = CreateFrame("EditBox", nil, container, "BackdropTemplate")
    editBox:SetSize(50, 18)
    editBox:SetPoint("TOP", trackFrame, "BOTTOM", 0, -4)
    editBox:SetBackdrop(BACKDROP)
    editBox:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    editBox:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetJustifyH("CENTER")
    editBox:SetNumeric(true)
    editBox:SetAutoFocus(false)

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
        editBox:SetText(tostring(currentValue))
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

    -- Edit box enter/focus-lost
    editBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            SetValueInternal(val)
        else
            self:SetText(tostring(currentValue))
        end
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        local val = tonumber(self:GetText())
        if val then
            SetValueInternal(val)
        else
            self:SetText(tostring(currentValue))
        end
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(currentValue))
        self:ClearFocus()
    end)

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
```

- [ ] **Step 4: Add Switch toggle**

Append to `Widgets.lua`:

```lua
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
```

- [ ] **Step 5: Add CheckButton with icon**

Append to `Widgets.lua`:

```lua
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
    icon:SetSize(size - 4, size - 4)
    icon:SetPoint("CENTER")
    if iconPath then icon:SetTexture(iconPath) end
    icon:SetVertexColor(0.4, 0.4, 0.4, 0.6)
    btn._icon = icon

    btn._checked = false
    btn._onToggle = callback

    local function UpdateVisual()
        if btn._checked then
            icon:SetVertexColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
            btn:SetBackdropBorderColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.8)
        else
            icon:SetVertexColor(0.4, 0.4, 0.4, 0.6)
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
        if not self._checked then
            icon:SetVertexColor(0.6, 0.6, 0.6, 0.8)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
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
```

- [ ] **Step 6: Verify all components compile**

Run: `luac -p Widgets.lua`

- [ ] **Step 7: Commit interactive components**

```bash
git add Widgets.lua
git commit -m "feat(widgets): add Dropdown, Slider, ScrollFrame, Switch, CheckButton

Dropdown: arrow icons, shared singleton list, ESC to close.
Slider: fill bar, edit box for direct value entry.
ScrollFrame: 5px thin scrollbar, proportional cyan thumb.
Switch: animated segmented toggle for sort mode.
CheckButton: icon-based toggle for group lock."
```

---

## Chunk 2: Consumer Updates — MainFrame, GroupView, RosterView

### Task 4: Update UI/MainFrame.lua

**Files:**
- Modify: `UI/MainFrame.lua` (lines 1-220)

Replace all `KS.BACKDROP_PANEL` references with `KS.CreateBorderedFrame`, replace sort mode toggle with `KS.CreateSwitch`, update close/resize buttons, migrate tooltips.

- [ ] **Step 1: Rewrite MainFrame.lua**

Key changes (apply as edits to the existing file):

1. **Line 11-23**: Replace `f:SetBackdrop(KS.BACKDROP_PANEL)` block. The main frame uses `CreateFrame("Frame", ..., "BackdropTemplate")` directly since it needs the global name. Apply backdrop manually using the shared constant. Since `BACKDROP` is local to Widgets.lua, use `KS.CreateBorderedFrame` pattern inline:

```lua
-- Replace lines 20-23:
local f = CreateFrame("Frame", "KeySorterMainFrame", UIParent, "BackdropTemplate")
f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
f:SetFrameStrata("HIGH")
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)

local p = KeySorterDB.point
f:SetPoint(p[1], UIParent, p[3], p[4], p[5])

-- Use shared backdrop constant (exposed from Widgets.lua)
f:SetBackdrop(KS.BACKDROP)
f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
```

2. **Title bar (lines 28-34)**: Replace `KS.BACKDROP_PANEL` with inline backdrop:
```lua
local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
-- ... positioning stays the same ...
titleBar:SetBackdrop(KS.BACKDROP)
titleBar:SetBackdropColor(0.12, 0.12, 0.12, 1)
titleBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
```

3. **Close button (line 51)**: Replace with `KS.CreateCloseButton`:
```lua
local close = KS.CreateCloseButton(titleBar)
close:SetPoint("RIGHT", -4, 0)
close:SetOnClick(function() f:Hide() end)
```

4. **Tooltip migrations (lines 59, 65, 149, 177)**: Replace `KS.AddTooltip(...)` with `KS.SetTooltip(...)`:
```lua
-- Line 59: Settings button tooltip
KS.SetTooltip(settingsBtn, "ANCHOR_BOTTOM", {"Settings", "Configure KeySorter options."})

-- Line 65: About button tooltip
KS.SetTooltip(aboutBtn, "ANCHOR_BOTTOM", {"About KeySorter", "View overview, sort logic, and command reference."})

-- Line 149: Sort button tooltip
KS.SetTooltip(sortBtnGroups, "ANCHOR_BOTTOM", {"Sort Groups", "Sort players using the selected mode and move them into raid subgroups.", "1 tank, 1 healer, 3 DPS per group. BR/BL balanced where possible."})
```

5. **Toolbar (lines 103-111)**: Replace `KS.BACKDROP_PANEL`:
```lua
toolbar = CreateFrame("Frame", nil, f, "BackdropTemplate")
-- ... positioning stays the same ...
toolbar:SetBackdrop(KS.BACKDROP)
toolbar:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
toolbar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
```

6. **Sort mode toggle (lines 151-177)**: Replace button with `KS.CreateSwitch`:
```lua
-- Replace the sortModeBtn block:
local switchOptions = {}
for _, mode in ipairs(KS.SORT_MODES) do
    table.insert(switchOptions, { text = mode.label, value = mode.key })
end
local sortSwitch = KS.CreateSwitch(groupsToolbar, 180, 22, switchOptions)
sortSwitch:SetPoint("LEFT", sortBtnGroups, "RIGHT", 8, 0)
sortSwitch:SetSelectedValue(KS.sortMode)
sortSwitch:SetOnSelect(function(value)
    KS.sortMode = value
end)
KS.SetTooltip(sortSwitch, "ANCHOR_BOTTOM", {"Sort Mode", "Click to toggle sort algorithm."})
```

7. **Resize handle (lines 195-206)**: Replace with `KS.CreateResizeButton`:
```lua
f:SetResizable(true)
f:SetResizeBounds(500, 350, 1000, 800)

local resizer = KS.CreateResizeButton(f)
resizer:SetScript("OnMouseDown", function()
    f:StartSizing("BOTTOMRIGHT")
end)
resizer:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
end)
```

- [ ] **Step 2: Commit MainFrame changes**

```bash
git add UI/MainFrame.lua
git commit -m "feat(mainframe): migrate to new widget system

Switch toggle replaces sort mode button.
Close/resize use styled components.
Tooltips migrated to KS.SetTooltip.
BACKDROP_PANEL references removed."
```

---

### Task 5: Update UI/GroupView.lua — Cards, Lock, and Drag Visuals

**Files:**
- Modify: `UI/GroupView.lua` (lines 1-468)

This task updates group cards, lock buttons, announce buttons, and the drag-and-drop visual system.

- [ ] **Step 1: Update drag cursor to styled moverTip**

Replace `GetOrCreateDragCursor()` (lines 52-67):

```lua
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
```

- [ ] **Step 2: Update StartDrag to set role icon and add source overlay**

Replace `StartDrag` function (lines 69-90):

```lua
local function StartDrag(line)
    if not line._member then return end

    dragSource = {
        groupIdx = line._groupIdx,
        slot = line._slot,
        slotIdx = line._slotIdx,
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
```

- [ ] **Step 3: Update StopDrag with flash animation**

Replace `StopDrag` function (lines 128-159):

```lua
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
```

- [ ] **Step 4: Update group card creation**

Replace `CreateGroupCard` (lines 267-348) — key changes:

```lua
local function CreateGroupCard(parent, groupIdx, group, xOffset, yOffset)
    local numDpsSlots = math.max(#group.dps, 3)
    local cardHeight = 24 + (2 + numDpsSlots) * MEMBER_HEIGHT + 8

    -- Use BorderedFrame for group card
    local card = KS.CreateBorderedFrame(parent, CARD_WIDTH, cardHeight,
        {0.12, 0.12, 0.12, 0.95}, {0.3, 0.3, 0.3, 1})
    card:SetPoint("TOPLEFT", xOffset, yOffset)

    -- Lock toggle — CheckButton with lock icon
    local lockBtn = KS.CreateCheckButton(card, KS.MEDIA.Lock, 16, function(checked)
        group.locked = checked
        if checked then
            card:SetBorderColor(0.1, 0.5, 0.1, 1)
        else
            card:SetBorderColor(0.3, 0.3, 0.3, 1)
        end
    end)
    lockBtn:SetPoint("TOPLEFT", 6, -5)
    lockBtn:SetChecked(group.locked)
    if group.locked then
        card:SetBorderColor(0.1, 0.5, 0.1, 1)
    end
    KS.SetTooltip(lockBtn, "ANCHOR_RIGHT", {"Lock Group", "Locked groups are preserved when re-sorting."})

    -- Group header
    local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("LEFT", lockBtn, "RIGHT", 2, 0)
    header:SetText(format("Group %d", groupIdx))
    header:SetTextColor(0, 0.8, 1)

    -- Announce button with border highlight
    local announceBtn = KS.CreateButton(card, "Announce", "widget", 52, 16)
    announceBtn:SetPoint("TOPRIGHT", -6, -5)
    announceBtn:SetBorderHighlightColor(0, 0.8, 1, 0.6)
    announceBtn:SetOnClick(function() KS.AnnounceGroup(groupIdx) end)
    KS.SetTooltip(announceBtn, "ANCHOR_RIGHT", {"Announce Group", "Post this group's assignments to raid chat."})

    -- Average score and utility text remain unchanged
    local avgScore = KS.GroupScore(group)
    local avgText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    avgText:SetPoint("RIGHT", announceBtn, "LEFT", -6, 0)
    avgText:SetText(format("Avg: %d", avgScore))
    avgText:SetTextColor(0.7, 0.7, 0.7)

    local utilText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    utilText:SetPoint("TOPRIGHT", -8, -24)
    utilText:SetText(GetGroupUtilityString(group))

    -- Members (unchanged except member lines now get hover highlight)
    local y = -24
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
```

- [ ] **Step 5: Update unassigned section**

Replace `CreateUnassignedSection` (lines 350-375) — use `KS.CreateBorderedFrame`:

```lua
local function CreateUnassignedSection(parent, yOffset)
    if #KS.unassigned == 0 then return nil end

    local height = 24 + #KS.unassigned * MEMBER_HEIGHT + 8
    local card = KS.CreateBorderedFrame(parent, nil, height,
        {0.15, 0.1, 0.05, 0.95}, {0.5, 0.35, 0.15, 1})
    card:SetPoint("TOPLEFT", 0, yOffset)
    card:SetPoint("RIGHT", -CARD_PADDING, 0)

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
```

- [ ] **Step 6: Update member line tooltips to use custom tooltip**

In `CreateMemberLine`, update the `OnEnter` tooltip calls (lines 241-253) to use `KS.ShowTooltip` and `KS.HideTooltip` instead of direct `GameTooltip` calls for the hint tooltip. The shift-hover `KS.ShowMemberTooltip` call stays — it will be migrated to custom tooltip in Task 7.

```lua
-- In OnEnter handler, replace GameTooltip block:
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
    GameTooltip:Hide()  -- Also hide GameTooltip in case ShowMemberTooltip used it
    self._shiftShown = false
    if self._highlightTex then self._highlightTex:Hide() end
    if self._dropBorder then self._dropBorder:Hide() end
end)
```

Also update the inline tooltip in the OnUpdate shift-toggle (lines 211-222). Replace the shift-release block that uses `GameTooltip:SetOwner(...)` directly:

```lua
-- In the OnUpdate handler, replace lines 218-222:
elseif not IsShiftKeyDown() and self._shiftShown then
    self._shiftShown = false
    KS.ShowTooltip(self, "ANCHOR_RIGHT", {
        "Member Actions",
        {"|cffccccccLeft-click drag|r to move", 0.8, 0.8, 0.8},
        {"|cffccccccRight-click|r to inspect", 0.8, 0.8, 0.8},
        {"|cffccccccShift-hover|r for details", 0.5, 0.5, 0.5},
    })
end
```

Also fix the drop target highlight comparison bug (line 227). Replace `if dragSource and self ~= dragSource then` with:

```lua
if dragSource and self ~= dragSource.sourceLine then
```

And add cyan border highlight to drop targets (not just background tint). Replace the drop target OnUpdate block (lines 227-238):

```lua
-- Drop target highlighting with border
if dragSource and self ~= dragSource.sourceLine then
    if self:IsMouseOver() and self._member then
        if not self._highlightTex then
            self._highlightTex = self:CreateTexture(nil, "BACKGROUND")
            self._highlightTex:SetAllPoints()
            self._highlightTex:SetColorTexture(0, 0.8, 1, 0.15)
        end
        self._highlightTex:Show()
        -- Cyan border on drop target (use parent card if available)
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
```

- [ ] **Step 7: Commit GroupView changes**

```bash
git add UI/GroupView.lua
git commit -m "feat(groupview): styled drag-and-drop, lock checkbutton, bordered cards

Drag cursor shows role icon + class-colored name.
Source slot gets dimmed overlay during drag.
Drop flash animation on successful swap.
Group lock uses CheckButton with Lock.tga icon.
Cards use CreateBorderedFrame. Tooltips migrated."
```

---

### Task 6: Update UI/RosterView.lua

**Files:**
- Modify: `UI/RosterView.lua` (lines 1-544)

Update dropdowns, sort indicators, header bar, and member tooltip.

- [ ] **Step 1: Update filter dropdowns**

Change all 4 `KS.CreateDropdown(toolbar, width, 22)` calls to `KS.CreateDropdown(toolbar, width)` (remove the height parameter). The callsites are at lines 319, 334, 353, 372.

```lua
-- Line 319: was KS.CreateDropdown(toolbar, 100, 22)
local filterDD = KS.CreateDropdown(toolbar, 100)

-- Line 334: was KS.CreateDropdown(toolbar, 80, 22)
local roleDD = KS.CreateDropdown(toolbar, 80)

-- Line 353: was KS.CreateDropdown(toolbar, 80, 22)
local utilDD = KS.CreateDropdown(toolbar, 80)

-- Line 372: was KS.CreateDropdown(toolbar, 62, 22)
local timedDD = KS.CreateDropdown(toolbar, 62)
```

- [ ] **Step 2: Update sort indicators to use arrow textures**

Replace `UpdateSortIndicators` (lines 202-215):

```lua
local sortArrows = {} -- arrow texture per column index

local function UpdateSortIndicators()
    for ci, col in ipairs(COLUMNS) do
        if col.sortable and headerTexts[ci] then
            if sortField == col.key then
                headerTexts[ci]:SetText(col.label)
                headerTexts[ci]:SetTextColor(1, 1, 1)
                -- Show arrow texture
                if not sortArrows[ci] then
                    local arrow = headerTexts[ci]:GetParent():CreateTexture(nil, "OVERLAY")
                    arrow:SetSize(8, 8)
                    arrow:SetPoint("LEFT", headerTexts[ci], "RIGHT", 2, 0)
                    sortArrows[ci] = arrow
                end
                sortArrows[ci]:SetTexture(sortAsc and KS.MEDIA.ArrowUp or KS.MEDIA.ArrowDown)
                sortArrows[ci]:SetVertexColor(0, 0.8, 1)
                sortArrows[ci]:Show()
            else
                headerTexts[ci]:SetText(col.label)
                headerTexts[ci]:SetTextColor(0.7, 0.7, 0.7)
                if sortArrows[ci] then sortArrows[ci]:Hide() end
            end
        end
    end
end
```

- [ ] **Step 3: Update header bar to use inline backdrop (remove KS.BACKDROP_PANEL)**

Replace lines 400-406:

```lua
local headerBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
headerBar:SetPoint("TOPLEFT", 0, -TOOLBAR_HEIGHT)
headerBar:SetPoint("TOPRIGHT", 0, -TOOLBAR_HEIGHT)
headerBar:SetHeight(HEADER_HEIGHT)
headerBar:SetBackdrop(KS.BACKDROP)
headerBar:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
headerBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
```

- [ ] **Step 4: Migrate ShowMemberTooltip to custom tooltip**

Replace `KS.ShowMemberTooltip` (lines 121-191):

```lua
function KS.ShowMemberTooltip(row, member)
    local lines = {}

    -- Title: class-colored name
    local classColor = KS.CLASS_COLORS[member.classFile]
    if classColor then
        table.insert(lines, {member.name, classColor.r, classColor.g, classColor.b})
    else
        table.insert(lines, member.name)
    end

    -- Score / avg key / ilvl summary line
    local ilvlStr = (member.ilvl and member.ilvl > 0) and format("  |  iLvl: %d", member.ilvl) or ""
    table.insert(lines, {format("Score: %d  |  Avg Key: %.1f%s", member.score, member.avgKeyLevel, ilvlStr), 0.7, 0.7, 0.7})
    table.insert(lines, " ")

    -- Dungeon breakdown
    if not member.runs or next(member.runs) == nil then
        table.insert(lines, {"No dungeon runs recorded.", 0.5, 0.5, 0.5})
    else
        table.insert(lines, {"Dungeon Breakdown:", 0, 0.8, 1})
        local shown = {}
        for _, mapID in ipairs(KS.DUNGEON_IDS) do
            local run = member.runs[mapID]
            if run then
                shown[mapID] = true
                local name = GetDungeonName(mapID)
                local timedStr = run.timed and "|cff00cc00Timed|r" or "|cffcc0000Untimed|r"
                table.insert(lines, {format("  %s", name), format("+%d  %s", run.level, timedStr)})
            end
        end
        for mapID, run in pairs(member.runs) do
            if not shown[mapID] then
                local name = GetDungeonName(mapID)
                local timedStr = run.timed and "|cff00cc00Timed|r" or "|cffcc0000Untimed|r"
                table.insert(lines, {format("  %s", name), format("+%d  %s", run.level, timedStr)})
            end
        end
    end

    -- Utilities
    local utils = {}
    if member.hasBrez then table.insert(utils, "Battle Rez") end
    if member.hasLust then table.insert(utils, "Bloodlust") end
    if member.hasShroud then table.insert(utils, "Shroud") end
    if #utils > 0 then
        table.insert(lines, " ")
        table.insert(lines, {"Utilities: " .. table.concat(utils, ", "), 0.5, 0.8, 0.5})
    end

    table.insert(lines, " ")
    table.insert(lines, {"Hold Shift to keep open", 0.4, 0.4, 0.4})

    KS.ShowTooltip(row, "ANCHOR_RIGHT", lines)
end
```

- [ ] **Step 5: Update roster row tooltips**

In `CreateRow` (lines 217-298), replace the `GameTooltip` calls in `OnEnter`/`OnLeave` (lines 240-256):

```lua
row:SetScript("OnEnter", function(self)
    hoverTex:Show()
    if IsShiftKeyDown() and self._member then
        KS.ShowMemberTooltip(self, self._member)
        self._shiftShown = true
    elseif self._member then
        KS.ShowTooltip(self, "ANCHOR_RIGHT", {
            "Member Info",
            {"|cffccccccClick|r to inspect", 0.8, 0.8, 0.8},
            {"|cffccccccShift-hover|r for details", 0.5, 0.5, 0.5},
        })
    end
end)
row:SetScript("OnLeave", function(self)
    hoverTex:Hide()
    KS.HideTooltip()
    GameTooltip:Hide()
    self._shiftShown = false
end)
```

Also update the `OnUpdate` shift-toggle (lines 262-272):

```lua
row:SetScript("OnUpdate", function(self)
    if not self:IsMouseOver() then return end
    local shiftDown = IsShiftKeyDown()
    if shiftDown and not self._shiftShown and self._member then
        KS.ShowMemberTooltip(self, self._member)
        self._shiftShown = true
    elseif not shiftDown and self._shiftShown then
        KS.HideTooltip()
        GameTooltip:Hide()
        self._shiftShown = false
    end
end)
```

- [ ] **Step 6: Commit RosterView changes**

```bash
git add UI/RosterView.lua
git commit -m "feat(rosterview): arrow sort icons, new dropdowns, styled tooltips

Sort indicators use ArrowUp/ArrowDown.tga textures.
Dropdowns use new 2-param constructor (fixed 22px height).
ShowMemberTooltip migrated to custom tooltip system.
BACKDROP_PANEL reference removed from header bar."
```

---

## Chunk 3: Consumer Updates — Settings, About, CharacterDetail, Minimap

### Task 7: Update UI/Settings.lua

**Files:**
- Modify: `UI/Settings.lua` (lines 1-145)

- [ ] **Step 1: Replace backdrop and close button**

Replace lines 17-36:

```lua
function KS.CreateSettingsFrame()
    -- Use inline backdrop (needs global name for UISpecialFrames)
    settingsFrame = CreateFrame("Frame", "KeySorterSettingsFrame", UIParent, "BackdropTemplate")
    settingsFrame:SetSize(360, 480)
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetMovable(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:SetClampedToScreen(true)
    settingsFrame:SetPoint("CENTER")

    settingsFrame:SetBackdrop(KS.BACKDROP)
    settingsFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    settingsFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    settingsFrame:RegisterForDrag("LeftButton")
    settingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    settingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Close button (styled)
    local close = KS.CreateCloseButton(settingsFrame)
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetOnClick(function() settingsFrame:Hide() end)
```

The slider at line 112 already uses `KS.CreateSlider` with the correct parameter order — no change needed. The slider container height should be updated from 36 to 50 (to accommodate the edit box), and `y` offset after slider should be `-62` instead of `-48`.

- [ ] **Step 2: Update y-offset for taller slider**

```lua
-- Line 123: was y = y - 48
y = y - 62
```

- [ ] **Step 3: Commit Settings changes**

```bash
git add UI/Settings.lua
git commit -m "feat(settings): styled close button, backdrop cleanup

Uses CreateCloseButton. Removes KS.BACKDROP_PANEL reference.
Adjusts layout for taller slider with edit box."
```

---

### Task 8: Update UI/About.lua — Add Attribution

**Files:**
- Modify: `UI/About.lua` (lines 1-108)

- [ ] **Step 1: Add attribution section before the Author section**

Insert before line 92 (`AddHeading("Author")`):

```lua
    ---------------------------------------------------------------------------
    AddHeading("Acknowledgments")
    AddText("UI components inspired by AbstractFramework by enderneko (GPLv3).", 0.7, 0.7, 0.7)
    AddSpacer()
```

- [ ] **Step 2: Commit About changes**

```bash
git add UI/About.lua
git commit -m "feat(about): add AbstractFramework attribution"
```

---

### Task 9: Update UI/CharacterDetail.lua

**Files:**
- Modify: `UI/CharacterDetail.lua` (lines 1-426)

- [ ] **Step 1: Replace backdrop references**

Replace lines 350-357 in `EnsureDetailFrame()`:

```lua
    detailFrame = CreateFrame("Frame", nil, KS.mainFrame, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", 1, -29)
    detailFrame:SetPoint("BOTTOMRIGHT", -1, 1)
    detailFrame:SetFrameLevel(KS.mainFrame:GetFrameLevel() + 10)
    detailFrame:SetBackdrop(KS.BACKDROP)
    detailFrame:SetBackdropColor(0.08, 0.08, 0.08, 1)
    detailFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    detailFrame:Hide()
```

- [ ] **Step 2: Update HideCharacterDetail to clear custom tooltip**

Add `KS.HideTooltip()` alongside the existing `GameTooltip:Hide()` at line 392:

```lua
function KS.ShowCharacterDetail(member, fromTab)
    if not member then return end
    if not KS.mainFrame then return end

    KS.HideTooltip()
    GameTooltip:Hide()
    -- ... rest unchanged
```

- [ ] **Step 3: Commit CharacterDetail changes**

```bash
git add UI/CharacterDetail.lua
git commit -m "feat(chardetail): remove BACKDROP_PANEL, clear custom tooltip"
```

---

### Task 10: Update UI/Minimap.lua — Tooltip Migration

**Files:**
- Modify: `UI/Minimap.lua` (lines 1-97)

- [ ] **Step 1: Migrate minimap tooltip to custom tooltip**

Replace lines 46-54:

```lua
    btn:SetScript("OnEnter", function(self)
        KS.ShowTooltip(self, "ANCHOR_LEFT", {
            "KeySorter",
            {"|cffccccccLeft-click|r toggle window", 0.8, 0.8, 0.8},
            {"|cffccccccRight-click|r about", 0.8, 0.8, 0.8},
        })
    end)
    btn:SetScript("OnLeave", function()
        KS.HideTooltip()
    end)
```

- [ ] **Step 2: Commit Minimap changes**

```bash
git add UI/Minimap.lua
git commit -m "feat(minimap): migrate tooltip to custom styled system"
```

---

### Task 11: Final Cleanup & Gitignore

**Files:**
- Modify: `.gitignore` (add `.superpowers/`)

- [ ] **Step 1: Add .superpowers to gitignore**

```
# Brainstorming sessions
.superpowers/
```

- [ ] **Step 2: Final commit**

```bash
git add .gitignore
git commit -m "chore: add .superpowers to gitignore"
```

- [ ] **Step 3: Verify no remaining references to removed APIs**

Search for any leftover references that should have been removed:

```bash
grep -rn "BACKDROP_PANEL\|BACKDROP_BUTTON\|KS.AddTooltip\|KS\.BACKDROP" --include="*.lua" .
```

Expected: No matches. If any remain, update those files.

---

## Summary

| Task | Files | What |
|------|-------|------|
| 1 | `Media/*.tga`, `scripts/generate_tga.py` | Create arrow and lock TGA assets |
| 2 | `Widgets.lua` | Foundation: BorderedFrame, Button, Tooltips, CloseButton, ResizeButton |
| 3 | `Widgets.lua` | Components: ScrollFrame, Dropdown, Slider, Switch, CheckButton |
| 4 | `UI/MainFrame.lua` | Switch toggle, close/resize, tooltip migration |
| 5 | `UI/GroupView.lua` | Styled drag-and-drop, lock checkbutton, bordered cards |
| 6 | `UI/RosterView.lua` | Arrow sort icons, dropdown update, tooltip migration |
| 7 | `UI/Settings.lua` | Close button, backdrop cleanup |
| 8 | `UI/About.lua` | Attribution section |
| 9 | `UI/CharacterDetail.lua` | Backdrop cleanup |
| 10 | `UI/Minimap.lua` | Tooltip migration |
| 11 | `.gitignore` | Cleanup |
