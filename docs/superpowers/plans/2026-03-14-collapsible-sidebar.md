# Collapsible Sidebar Navigation — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the title bar tab system with a collapsible sidebar navigation featuring icons, gradient highlights, and animated collapse/expand.

**Architecture:** New `UI/Sidebar.lua` encapsulates the sidebar widget. `UI/MainFrame.lua` is restructured to remove the title bar and use the sidebar for navigation. `UI/Settings.lua` is converted from a popup to an inline content panel. 7 new TGA textures are generated for icons, logos, and gradient.

**Tech Stack:** WoW Lua API (Interface 120001), BackdropTemplate, OnUpdate animation, TGA texture assets

**Spec:** `docs/superpowers/specs/2026-03-14-collapsible-sidebar-design.md`

---

## Chunk 1: Media Assets & Sidebar Component

### Task 1: Generate TGA Media Assets

**Files:**
- Modify: `scripts/generate_tga.py`
- Create: `Media/LogoFull.tga` (128×16)
- Create: `Media/LogoKS.tga` (32×32)
- Create: `Media/IconRoster.tga` (16×16)
- Create: `Media/IconGroups.tga` (16×16)
- Create: `Media/IconSettings.tga` (16×16)
- Create: `Media/IconAbout.tga` (16×16)
- Create: `Media/GradientH.tga` (64×4)

- [ ] **Step 1: Update generate_tga.py with new icon generators**

Add these functions to `scripts/generate_tga.py`. The existing `write_tga` function needs to be generalized to support arbitrary sizes, then add generators for each icon:

```python
def write_tga_sized(filename, width, height, pixels):
    """Write an arbitrary-sized RGBA TGA file."""
    header = struct.pack('<BBBHHBHHHHBB',
        0, 0, 2, 0, 0, 0, 0, 0,
        width, height, 32, 0x28,
    )
    data = b''
    for r, g, b, a in pixels:
        data += struct.pack('BBBB', b, g, r, a)
    with open(filename, 'wb') as f:
        f.write(header + data)

def make_gradient_h():
    """64x4 white-to-transparent horizontal gradient."""
    pixels = []
    for y in range(4):
        for x in range(64):
            alpha = int(255 * (1.0 - x / 63.0))
            pixels.append((255, 255, 255, alpha))
    return 64, 4, pixels

def make_icon_roster():
    """16x16 people/list icon."""
    W = (255, 255, 255, 255)
    T = (0, 0, 0, 0)
    rows = [
        "                ",
        "    ####        ",
        "   ######       ",
        "   ######       ",
        "    ####        ",
        "   ######       ",
        "  ########      ",
        "                ",
        "        ####    ",
        "       ######   ",
        "       ######   ",
        "        ####    ",
        "       ######   ",
        "      ########  ",
        "                ",
        "                ",
    ]
    pixels = []
    for row in rows:
        for ch in row:
            pixels.append(W if ch == '#' else T)
    return pixels

def make_icon_groups():
    """16x16 2x2 grid icon."""
    W = (255, 255, 255, 255)
    T = (0, 0, 0, 0)
    rows = [
        "                ",
        "  ######  ##### ",
        "  ######  ##### ",
        "  ######  ##### ",
        "  ######  ##### ",
        "  ######  ##### ",
        "                ",
        "                ",
        "  ######  ##### ",
        "  ######  ##### ",
        "  ######  ##### ",
        "  ######  ##### ",
        "  ######  ##### ",
        "                ",
        "                ",
        "                ",
    ]
    pixels = []
    for row in rows:
        for ch in row:
            pixels.append(W if ch == '#' else T)
    return pixels

def make_icon_settings():
    """16x16 gear icon."""
    W = (255, 255, 255, 255)
    T = (0, 0, 0, 0)
    rows = [
        "                ",
        "     ####       ",
        "    ######      ",
        "  ##########    ",
        "  ###    ###    ",
        " ####    ####   ",
        " ###      ###   ",
        " ###      ###   ",
        " ###      ###   ",
        " ####    ####   ",
        "  ###    ###    ",
        "  ##########    ",
        "    ######      ",
        "     ####       ",
        "                ",
        "                ",
    ]
    pixels = []
    for row in rows:
        for ch in row:
            pixels.append(W if ch == '#' else T)
    return pixels

def make_icon_about():
    """16x16 circled 'i' icon."""
    W = (255, 255, 255, 255)
    T = (0, 0, 0, 0)
    rows = [
        "                ",
        "    ######      ",
        "   ##    ##     ",
        "  ##      ##    ",
        "  ##  ##  ##    ",
        "  ##      ##    ",
        "  ##  ##  ##    ",
        "  ##  ##  ##    ",
        "  ##  ##  ##    ",
        "  ##  ##  ##    ",
        "  ##      ##    ",
        "   ##    ##     ",
        "    ######      ",
        "                ",
        "                ",
        "                ",
    ]
    pixels = []
    for row in rows:
        for ch in row:
            pixels.append(W if ch == '#' else T)
    return pixels

def make_logo_ks():
    """32x32 'KS' text with cyan glow."""
    import math
    W, H = 32, 32
    # Draw K and S as bitmaps on a grid, then add glow
    text_pixels = [[0]*W for _ in range(H)]

    # K shape (columns 4-14, rows 8-23)
    k_rows = [
        "##    ##",
        "##   ## ",
        "##  ##  ",
        "## ##   ",
        "####    ",
        "## ##   ",
        "##  ##  ",
        "##   ## ",
        "##    ##",
    ]
    for ry, row in enumerate(k_rows):
        for rx, ch in enumerate(row):
            if ch == '#':
                text_pixels[10 + ry][5 + rx] = 255

    # S shape (columns 16-25, rows 8-23)
    s_rows = [
        " #####  ",
        "##   ## ",
        "##      ",
        " ####   ",
        "   ###  ",
        "     ## ",
        "##   ## ",
        " #####  ",
    ]
    for ry, row in enumerate(s_rows):
        for rx, ch in enumerate(row):
            if ch == '#':
                text_pixels[10 + ry][17 + rx] = 255

    # Generate glow (gaussian blur of text)
    glow_radius = 3
    pixels = []
    for y in range(H):
        for x in range(W):
            # Text pixel (white, full alpha)
            if text_pixels[y][x] > 0:
                pixels.append((255, 255, 255, 255))
            else:
                # Glow: check nearby text pixels
                glow = 0.0
                for dy in range(-glow_radius, glow_radius + 1):
                    for dx in range(-glow_radius, glow_radius + 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < H and 0 <= nx < W and text_pixels[ny][nx] > 0:
                            dist = math.sqrt(dx*dx + dy*dy)
                            if dist <= glow_radius:
                                glow += (1.0 - dist / glow_radius) * 0.6
                glow = min(glow, 1.0)
                if glow > 0.05:
                    # Cyan glow: (0, 204, 255)
                    a = int(glow * 200)
                    pixels.append((0, 204, 255, a))
                else:
                    pixels.append((0, 0, 0, 0))
    return W, H, pixels

def make_logo_full():
    """128x16 'KeySorter' text with cyan glow."""
    import math
    W, H = 128, 16
    text_pixels = [[0]*W for _ in range(H)]

    # Simple block letters for "KeySorter" starting at row 3
    letters = {
        'K': ["##  ##", "## ## ", "####  ", "## ## ", "##  ##"],
        'e': ["      ", " #### ", "##  ##", "######", "##    ", " #### "],
        'y': ["##  ##", "##  ##", " #### ", "  ##  ", " ##   "],
        'S': [" #### ", "##    ", " ###  ", "   ## ", "####  "],
        'o': [" #### ", "##  ##", "##  ##", "##  ##", " #### "],
        'r': ["      ", "## ## ", "###  #", "##    ", "##    "],
        't': [" ##   ", "#####", " ##  ", " ##  ", "  ## "],
    }

    # Positions for each character (x offset)
    chars = [
        ('K', 6), ('e', 14), ('y', 22),
        ('S', 34), ('o', 42), ('r', 50), ('t', 58),
        ('e', 64), ('r', 72),
    ]

    for ch, xoff in chars:
        if ch in letters:
            for ry, row in enumerate(letters[ch]):
                for rx, c in enumerate(row):
                    if c == '#':
                        px, py = xoff + rx, 5 + ry
                        if 0 <= px < W and 0 <= py < H:
                            text_pixels[py][px] = 255

    # Glow
    glow_radius = 2
    pixels = []
    for y in range(H):
        for x in range(W):
            if text_pixels[y][x] > 0:
                pixels.append((255, 255, 255, 255))
            else:
                glow = 0.0
                for dy in range(-glow_radius, glow_radius + 1):
                    for dx in range(-glow_radius, glow_radius + 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < H and 0 <= nx < W and text_pixels[ny][nx] > 0:
                            dist = math.sqrt(dx*dx + dy*dy)
                            if dist <= glow_radius:
                                glow += (1.0 - dist / glow_radius) * 0.5
                glow = min(glow, 1.0)
                if glow > 0.05:
                    a = int(glow * 180)
                    pixels.append((0, 204, 255, a))
                else:
                    pixels.append((0, 0, 0, 0))
    return W, H, pixels
```

Update `__main__` to generate all new assets:

```python
if __name__ == '__main__':
    media_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'Media')
    os.makedirs(media_dir, exist_ok=True)

    # Original assets
    write_tga(os.path.join(media_dir, 'ArrowUp.tga'), make_arrow_up())
    write_tga(os.path.join(media_dir, 'ArrowDown.tga'), make_arrow_down())
    write_tga(os.path.join(media_dir, 'Lock.tga'), make_lock())

    # Sidebar icons
    write_tga(os.path.join(media_dir, 'IconRoster.tga'), make_icon_roster())
    write_tga(os.path.join(media_dir, 'IconGroups.tga'), make_icon_groups())
    write_tga(os.path.join(media_dir, 'IconSettings.tga'), make_icon_settings())
    write_tga(os.path.join(media_dir, 'IconAbout.tga'), make_icon_about())

    # Gradient
    w, h, px = make_gradient_h()
    write_tga_sized(os.path.join(media_dir, 'GradientH.tga'), w, h, px)

    # Logos
    w, h, px = make_logo_ks()
    write_tga_sized(os.path.join(media_dir, 'LogoKS.tga'), w, h, px)

    w, h, px = make_logo_full()
    write_tga_sized(os.path.join(media_dir, 'LogoFull.tga'), w, h, px)

    print(f"Generated 10 TGA files in {media_dir}/")
```

- [ ] **Step 2: Run the script**

Run: `python3 scripts/generate_tga.py`
Expected: "Generated 10 TGA files in .../Media/"

- [ ] **Step 3: Update KS.MEDIA in Widgets.lua**

Add new media paths to `Widgets.lua` after the existing `KS.MEDIA` table (around line 14):

```lua
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
}
```

- [ ] **Step 4: Commit**

```bash
git add scripts/generate_tga.py Media/*.tga Widgets.lua
git commit -m "feat: add sidebar TGA assets — icons, logos, gradient"
```

---

### Task 2: Create UI/Sidebar.lua

**Files:**
- Create: `UI/Sidebar.lua`
- Modify: `KeySorter.toc` (add Sidebar.lua before MainFrame.lua)

This is the core new file. It creates the sidebar widget with header, nav buttons, gradient highlights, collapse toggle, and animation.

- [ ] **Step 1: Write UI/Sidebar.lua**

```lua
local addonName, KS = ...

local EXPANDED_WIDTH = 140
local COLLAPSED_WIDTH = 32
local HEADER_HEIGHT = 28
local BUTTON_HEIGHT = 28
local TOGGLE_HEIGHT = 24
local ANIM_DURATION = 0.15

function KS.CreateSidebar(parent)
    local sidebar = CreateFrame("Frame", nil, parent)
    sidebar:SetPoint("TOPLEFT", 1, -1)
    sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(EXPANDED_WIDTH)

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

    -- Full logo (expanded)
    local logoFull = header:CreateTexture(nil, "ARTWORK")
    logoFull:SetSize(108, 14)
    logoFull:SetPoint("LEFT", 10, 0)
    logoFull:SetTexture(KS.MEDIA.LogoFull)

    -- Short logo (collapsed)
    local logoShort = header:CreateTexture(nil, "ARTWORK")
    logoShort:SetSize(24, 24)
    logoShort:SetPoint("CENTER", 0, 0)
    logoShort:SetTexture(KS.MEDIA.LogoKS)
    logoShort:Hide()

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

    local buttons = {}  -- keyed by nav key
    local selectedKey = nil
    sidebar._buttons = buttons
    sidebar._animating = false

    local navY = -HEADER_HEIGHT - 8

    -- Animate a texture's width via the parent button's OnUpdate
    -- (Textures cannot have scripts — only Frames can)
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
        btn:SetPoint("TOPLEFT", 6, yOffset)
        btn:SetPoint("TOPRIGHT", -6, yOffset)

        -- Gradient highlight (pre-rendered TGA)
        local highlight = btn:CreateTexture(nil, "BORDER")
        highlight:SetPoint("TOPLEFT", 0, 0)
        highlight:SetPoint("BOTTOMLEFT", 0, 0)
        highlight:SetWidth(1)
        highlight:SetTexture(KS.MEDIA.GradientH)
        highlight:SetVertexColor(0, 0.8, 1, 1)
        btn._highlight = highlight

        -- Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 8, 0)
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
            icon:SetPoint("LEFT", 8, -1)
        end)
        btn:SetScript("OnMouseUp", function(self)
            icon:SetPoint("LEFT", 8, 0)
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
            sep:SetPoint("TOPLEFT", 10, navY - 4)
            sep:SetPoint("TOPRIGHT", -10, navY - 4)
            sep:SetColorTexture(0.25, 0.25, 0.25, 1)
            navY = navY - 10
        else
            local btn = CreateNavButton(item, navY)
            buttons[item.key] = btn
            navY = navY - BUTTON_HEIGHT - 2
        end
    end

    ---------------------------------------------------------------------------
    -- Select / deselect buttons
    ---------------------------------------------------------------------------
    function sidebar:SelectButton(key)
        -- Deselect old
        if selectedKey and buttons[selectedKey] then
            local oldBtn = buttons[selectedKey]
            AnimateWidth(oldBtn._highlight, 1, 0.15, function()
                if selectedKey ~= key then
                    oldBtn._highlight:Hide()
                end
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

    ---------------------------------------------------------------------------
    -- Collapse toggle
    ---------------------------------------------------------------------------
    local toggle = CreateFrame("Button", nil, sidebar)
    toggle:SetHeight(TOGGLE_HEIGHT)
    toggle:SetPoint("BOTTOMLEFT", 0, 0)
    toggle:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Top border
    local toggleBorder = toggle:CreateTexture(nil, "BORDER")
    toggleBorder:SetHeight(1)
    toggleBorder:SetPoint("TOPLEFT", 0, 0)
    toggleBorder:SetPoint("TOPRIGHT", 0, 0)
    toggleBorder:SetColorTexture(0.25, 0.25, 0.25, 1)

    local toggleIcon = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toggleIcon:SetPoint("LEFT", 8, 0)
    toggleIcon:SetText("◀◀")
    toggleIcon:SetTextColor(0.5, 0.5, 0.5)

    local toggleLabel = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toggleLabel:SetPoint("LEFT", toggleIcon, "RIGHT", 4, 0)
    toggleLabel:SetText("Collapse")
    toggleLabel:SetTextColor(0.5, 0.5, 0.5)

    toggle:SetScript("OnEnter", function()
        toggleIcon:SetTextColor(1, 1, 1)
        toggleLabel:SetTextColor(1, 1, 1)
    end)
    toggle:SetScript("OnLeave", function()
        toggleIcon:SetTextColor(0.5, 0.5, 0.5)
        toggleLabel:SetTextColor(0.5, 0.5, 0.5)
    end)

    ---------------------------------------------------------------------------
    -- Collapse / Expand animation
    ---------------------------------------------------------------------------
    local collapsed = false

    local function ApplyCollapsedState()
        collapsed = true
        for _, btn in pairs(buttons) do
            btn._label:Hide()
            btn._icon:ClearAllPoints()
            btn._icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        end
        logoFull:Hide()
        logoShort:Show()
        toggleIcon:SetText("▶▶")
        toggleIcon:ClearAllPoints()
        toggleIcon:SetPoint("CENTER", toggle, "CENTER", 0, 0)
        toggleLabel:Hide()
        -- Re-select to fix highlight width
        if selectedKey and buttons[selectedKey] then
            buttons[selectedKey]._highlight:SetWidth(buttons[selectedKey]:GetWidth())
        end
    end

    local function ApplyExpandedState()
        collapsed = false
        for _, btn in pairs(buttons) do
            btn._label:Show()
            btn._icon:ClearAllPoints()
            btn._icon:SetPoint("LEFT", 8, 0)
        end
        logoFull:Show()
        logoShort:Hide()
        toggleIcon:SetText("◀◀")
        toggleIcon:ClearAllPoints()
        toggleIcon:SetPoint("LEFT", 8, 0)
        toggleLabel:Show()
        -- Re-select to fix highlight width
        if selectedKey and buttons[selectedKey] then
            buttons[selectedKey]._highlight:SetWidth(buttons[selectedKey]:GetWidth())
        end
    end

    local function ToggleSidebar()
        if sidebar._animating then return end
        sidebar._animating = true

        local targetWidth = collapsed and EXPANDED_WIDTH or COLLAPSED_WIDTH
        local startWidth = sidebar:GetWidth()
        local elapsed = 0
        local swapped = false

        sidebar:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local t = math.min(elapsed / ANIM_DURATION, 1)
            local w = startWidth + (targetWidth - startWidth) * t
            self:SetWidth(w)

            -- Swap labels/logos at midpoint
            if not swapped and t >= 0.5 then
                swapped = true
                if collapsed then
                    ApplyExpandedState()
                else
                    ApplyCollapsedState()
                end
            end

            if t >= 1 then
                self:SetScript("OnUpdate", nil)
                self._animating = false
                KeySorterDB.sidebarCollapsed = not collapsed  -- collapsed was toggled at midpoint
            end
        end)
    end

    toggle:SetScript("OnClick", ToggleSidebar)

    -- Apply initial state
    if KeySorterDB and KeySorterDB.sidebarCollapsed then
        sidebar:SetWidth(COLLAPSED_WIDTH)
        ApplyCollapsedState()
    end

    sidebar.collapsed = function() return collapsed end
    sidebar.toggle = ToggleSidebar

    return sidebar
end
```

- [ ] **Step 2: Add UI/Sidebar.lua to TOC**

In `KeySorter.toc`, add `UI/Sidebar.lua` before `UI/MainFrame.lua`:

```
UI/Sidebar.lua
UI/MainFrame.lua
```

- [ ] **Step 3: Add sidebarCollapsed to SavedVariables init in Core.lua**

In `Core.lua` around line 99, after `KeySorterDB.uiScale`:

```lua
KeySorterDB.sidebarCollapsed = KeySorterDB.sidebarCollapsed or false
```

- [ ] **Step 4: Commit**

```bash
git add UI/Sidebar.lua KeySorter.toc Core.lua
git commit -m "feat: add collapsible sidebar navigation component

New UI/Sidebar.lua with gradient highlights, animated collapse,
logo/icon swap, and persistent state."
```

---

## Chunk 2: MainFrame Restructure & Consumer Updates

### Task 3: Restructure UI/MainFrame.lua

**Files:**
- Modify: `UI/MainFrame.lua` (major restructure)

Remove the title bar and tab system. Add sidebar and content area. The groups toolbar moves inside the groups content panel.

- [ ] **Step 1: Rewrite MainFrame.lua**

The file needs a significant restructure. Key changes:

1. Remove constants: `TITLEBAR_H`, `TOOLBAR_H`, `CONTENT_Y_NO_TOOLBAR`, `CONTENT_Y_WITH_TOOLBAR`
2. Remove: title bar frame, tab buttons, settings/about buttons, `CreateTab()` helper
3. Add: sidebar, content area, close button on main frame
4. Update: `KS.SetTab()` to use sidebar button states
5. Move: groups toolbar inside groups content
6. Update: minimum width to 540px

Replace the entire `KS.CreateMainFrame()` function with:

```lua
local addonName, KS = ...

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500
local TOOLBAR_H = 30

function KS.CreateMainFrame()
    local f = CreateFrame("Frame", "KeySorterMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    local p = KeySorterDB.point
    f:SetPoint(p[1], UIParent, p[3], p[4], p[5])

    f:SetBackdrop(KS.BACKDROP)
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    ---------------------------------------------------------------------------
    -- Sidebar
    ---------------------------------------------------------------------------
    local sidebar = KS.CreateSidebar(f)

    ---------------------------------------------------------------------------
    -- Content area (fills space to the right of sidebar)
    ---------------------------------------------------------------------------
    local contentArea = CreateFrame("Frame", nil, f)
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    contentArea:SetPoint("BOTTOMRIGHT", -1, 1)
    KS.contentArea = contentArea

    ---------------------------------------------------------------------------
    -- Close button (top-right of main frame)
    ---------------------------------------------------------------------------
    local close = KS.CreateCloseButton(f)
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetOnClick(function() f:Hide() end)

    ---------------------------------------------------------------------------
    -- Content panels (all share the content area)
    ---------------------------------------------------------------------------
    local tabContents = {}

    -- Roster content
    local rosterContent = CreateFrame("Frame", nil, contentArea)
    rosterContent:SetPoint("TOPLEFT", 8, -8)
    rosterContent:SetPoint("BOTTOMRIGHT", -8, 8)
    rosterContent:Hide()
    tabContents["roster"] = rosterContent

    -- Groups content (with internal toolbar)
    local groupsWrapper = CreateFrame("Frame", nil, contentArea)
    groupsWrapper:SetPoint("TOPLEFT", 0, 0)
    groupsWrapper:SetPoint("BOTTOMRIGHT", 0, 0)
    groupsWrapper:Hide()
    tabContents["groups"] = groupsWrapper

    -- Groups toolbar (inside groups wrapper)
    local groupsToolbar = CreateFrame("Frame", nil, groupsWrapper, "BackdropTemplate")
    groupsToolbar:SetPoint("TOPLEFT", 1, -1)
    groupsToolbar:SetPoint("TOPRIGHT", -1, -1)
    groupsToolbar:SetHeight(TOOLBAR_H)
    groupsToolbar:SetBackdrop(KS.BACKDROP)
    groupsToolbar:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    groupsToolbar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    -- Groups content below toolbar
    local groupContent = CreateFrame("Frame", nil, groupsWrapper)
    groupContent:SetPoint("TOPLEFT", 8, -(TOOLBAR_H + 2))
    groupContent:SetPoint("BOTTOMRIGHT", -8, 8)

    -- Settings content
    local settingsContent = CreateFrame("Frame", nil, contentArea)
    settingsContent:SetPoint("TOPLEFT", 0, 0)
    settingsContent:SetPoint("BOTTOMRIGHT", 0, 0)
    settingsContent:Hide()
    tabContents["settings"] = settingsContent

    -- About content
    local aboutContent = CreateFrame("Frame", nil, contentArea)
    aboutContent:SetPoint("TOPLEFT", 8, -8)
    aboutContent:SetPoint("BOTTOMRIGHT", -8, 8)
    aboutContent:Hide()
    tabContents["about"] = aboutContent

    ---------------------------------------------------------------------------
    -- Groups toolbar controls: Sort, Switch
    ---------------------------------------------------------------------------
    local sortBtnGroups = KS.CreateButton(groupsToolbar, "Sort", "accent", 52, 22)
    sortBtnGroups:SetPoint("LEFT", 6, 0)
    sortBtnGroups:SetOnClick(function()
        if #KS.roster == 0 then KS.ScanRoster() end
        KS.SortGroups()
        KS.ApplyGroups()
        if KS.UpdateGroupView then KS.UpdateGroupView() end
    end)
    KS.sortButtonGroups = sortBtnGroups
    KS.SetTooltip(sortBtnGroups, "ANCHOR_BOTTOM", {"Sort Groups", "Sort players using the selected mode and move them into raid subgroups.", "1 tank, 1 healer, 3 DPS per group. BR/BL balanced where possible."})

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

    ---------------------------------------------------------------------------
    -- Tab switching
    ---------------------------------------------------------------------------
    local function SetTabInternal(tab)
        for name, content in pairs(tabContents) do
            if name == tab then content:Show() else content:Hide() end
        end
        sidebar:SelectButton(tab)
    end
    KS.SetTab = SetTabInternal

    ---------------------------------------------------------------------------
    -- Store references and build views
    ---------------------------------------------------------------------------
    KS.mainFrame = f
    KS.rosterContent = rosterContent
    KS.groupContent = groupContent
    KS.aboutContent = aboutContent
    KS.settingsContent = settingsContent

    KS.CreateRosterView(rosterContent)
    KS.CreateGroupView(groupContent)
    KS.CreateAboutView(aboutContent)
    KS.CreateSettingsView(settingsContent)

    -- Resize handle
    f:SetResizable(true)
    f:SetResizeBounds(540, 350, 1000, 800)

    local resizer = KS.CreateResizeButton(f)
    resizer:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
    end)

    -- Auto-scan on first show
    f:SetScript("OnShow", function()
        if not KS.previewMode and #KS.roster == 0 then
            KS.ScanRoster()
        end
        KS.UpdatePermissionState()
    end)

    -- Apply saved UI scale
    if KeySorterDB and KeySorterDB.uiScale then
        f:SetScale(KeySorterDB.uiScale)
    end

    SetTabInternal("roster")

    table.insert(UISpecialFrames, "KeySorterMainFrame")
    f:Hide()
end
```

Note: `KS.ApplyGroups()` and `KS.AnnounceGroup()` stay in this file unchanged (below `CreateMainFrame`).

- [ ] **Step 2: Commit**

```bash
git add UI/MainFrame.lua
git commit -m "feat(mainframe): replace title bar with sidebar navigation

Removes tab system, settings/about buttons from title bar.
Sidebar handles all navigation. Groups toolbar moved inside
groups content. Content area anchors to sidebar right edge.
Minimum width updated to 540px."
```

---

### Task 4: Convert Settings to Inline Panel

**Files:**
- Modify: `UI/Settings.lua` (convert from popup to inline panel)

Settings becomes a scrollable inline panel created via `KS.CreateSettingsView(parent)`. The old `KS.ToggleSettings()` and `KS.CreateSettingsFrame()` are replaced.

- [ ] **Step 1: Rewrite Settings.lua**

```lua
local addonName, KS = ...

function KS.CreateSettingsView(parent)
    local scrollFrame, scrollChild = KS.CreateScrollFrame(parent, "KeySorterSettingsScroll")

    local y = -12

    local function AddSettingLabel(text, r, g, b, font)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetPoint("TOPRIGHT", -16, y)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        if r then fs:SetTextColor(r, g, b) end
        y = y - (fs:GetStringHeight() + 8)
        return fs
    end

    local function AddSettingRow(label, status)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetPoint("TOPLEFT", 16, y)
        row:SetPoint("TOPRIGHT", -16, y)
        row:SetHeight(24)

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", 0, 0)
        lbl:SetText(label)
        lbl:SetTextColor(0.8, 0.8, 0.8)

        local tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tag:SetPoint("RIGHT", 0, 0)
        tag:SetText(status)
        tag:SetTextColor(0.4, 0.4, 0.4)

        y = y - 28
        return row
    end

    -- Title
    local title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText("Settings")
    title:SetTextColor(0, 0.8, 1)
    y = y - 28

    ---------------------------------------------------------------------------
    -- Preview Mode
    ---------------------------------------------------------------------------
    AddSettingLabel("Preview Mode", 0, 0.8, 1, "GameFontNormal")

    local previewDesc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewDesc:SetPoint("TOPLEFT", 16, y)
    previewDesc:SetPoint("TOPRIGHT", -16, y)
    previewDesc:SetJustifyH("LEFT")
    previewDesc:SetText("Generate fake raid data to test the UI without a group.")
    previewDesc:SetTextColor(0.6, 0.6, 0.6)
    y = y - 20

    local previewStatus = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewStatus:SetPoint("TOPLEFT", 16, y)
    previewStatus:SetText(KS.previewMode and "|cff00ff00ON|r" or "|cffff0000OFF|r")

    local toggleBtn = KS.CreateButton(scrollChild, KS.previewMode and "Disable" or "Enable", "accent", 70, 22)
    toggleBtn:SetPoint("LEFT", previewStatus, "RIGHT", 12, 0)
    toggleBtn:SetOnClick(function()
        KS.TogglePreview()
        if KS.previewMode then
            previewStatus:SetText("|cff00ff00ON|r")
            toggleBtn:SetText("Disable")
        else
            previewStatus:SetText("|cffff0000OFF|r")
            toggleBtn:SetText("Enable")
        end
    end)
    y = y - 30

    local countSlider = KS.CreateSlider(scrollChild, "Player Count", 1, 40, 1, 200)
    countSlider:SetPoint("TOPLEFT", 16, y)
    countSlider:SetValue(KS.previewPlayerCount or 25)
    countSlider:SetOnChange(function(val)
        KS.previewPlayerCount = val
        if KS.previewMode then
            KS.GeneratePreviewData()
            if KS.UpdateRosterView then KS.UpdateRosterView() end
            if KS.UpdateGroupView then KS.UpdateGroupView() end
        end
    end)
    y = y - 62

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    AddSettingLabel("General", 0, 0.8, 1, "GameFontNormal")

    local scaleSlider = KS.CreateSlider(scrollChild, "UI Scale", 0.5, 2.0, 0.1, 200)
    scaleSlider:SetPoint("TOPLEFT", 16, y)
    scaleSlider:SetValue(KeySorterDB.uiScale or 1.0)
    scaleSlider:SetOnChange(function(val)
        KeySorterDB.uiScale = val
        if KS.mainFrame then
            KS.mainFrame:SetScale(val)
        end
    end)
    y = y - 62

    AddSettingRow("Season Dungeon Pool", "|cff666666Coming Soon|r")
    AddSettingRow("Font", "|cff666666Coming Soon|r")
    AddSettingRow("Font Size", "|cff666666Coming Soon|r")

    y = y - 8
    AddSettingLabel("Data", 0, 0.8, 1, "GameFontNormal")
    AddSettingRow("Data Source Priority", "|cff666666Coming Soon|r")
    AddSettingRow("Export to Spreadsheet", "|cff666666Coming Soon|r")

    y = y - 8
    AddSettingLabel("Sorting", 0, 0.8, 1, "GameFontNormal")
    AddSettingRow("Swap Threshold", "|cff666666Coming Soon|r")
    AddSettingRow("Group Size", "|cff666666Coming Soon|r")

    scrollChild:SetHeight(math.abs(y) + 16)
end
```

- [ ] **Step 2: Commit**

```bash
git add UI/Settings.lua
git commit -m "feat(settings): convert from popup to inline scrollable panel

Replaces standalone dialog with KS.CreateSettingsView(parent).
Now renders in content area alongside other tabs.
Wrapped in ScrollFrame for overflow support."
```

---

### Task 5: Update CharacterDetail Anchoring

**Files:**
- Modify: `UI/CharacterDetail.lua` (lines 350-352)

- [ ] **Step 1: Update EnsureDetailFrame anchoring**

Replace lines 350-352:

```lua
    detailFrame = CreateFrame("Frame", nil, KS.mainFrame, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", KS.contentArea, "TOPLEFT", 0, 0)
    detailFrame:SetPoint("BOTTOMRIGHT", KS.mainFrame, "BOTTOMRIGHT", -1, 1)
```

- [ ] **Step 2: Commit**

```bash
git add UI/CharacterDetail.lua
git commit -m "fix(chardetail): anchor overlay to content area instead of title bar offset"
```

---

### Task 6: Update Slash Commands in Core.lua

**Files:**
- Modify: `Core.lua` (lines 189-194)

- [ ] **Step 1: Update preview/settings slash command**

Replace lines 189-194:

```lua
    elseif cmd == "preview" or cmd == "test" or cmd == "settings" then
        EnsureMainFrame()
        KS.mainFrame:Show()
        KS.SetTab("settings")
    elseif cmd == "about" or cmd == "credits" then
        EnsureMainFrame()
        KS.mainFrame:Show()
        KS.SetTab("about")
```

- [ ] **Step 2: Remove KS.ToggleAbout reference**

Check if `KS.ToggleAbout` is referenced anywhere. In `About.lua` it's defined but only used by the slash command. The slash command now uses `KS.SetTab("about")` directly, so `KS.ToggleAbout` can stay as a convenience function (it already calls `KS.SetTab("about")`).

- [ ] **Step 3: Commit**

```bash
git add Core.lua
git commit -m "fix(core): update slash commands for sidebar navigation

/ks settings and /ks preview now open main frame with settings tab.
/ks about opens main frame with about tab."
```

---

### Task 7: Deploy and Verify

- [ ] **Step 1: Verify no remaining references to removed APIs**

```bash
grep -rn "KS.ToggleSettings\|KS.CreateSettingsFrame\|TITLEBAR_H\|CreateTab\|CONTENT_Y_" --include="*.lua" .
```

Expected: No matches (except possibly comments).

- [ ] **Step 2: Deploy to WoW**

```bash
rsync -av --delete --exclude='.git' --exclude='.superpowers' --exclude='docs' --exclude='scripts' . "/Applications/World of Warcraft/_retail_/Interface/AddOns/KeySorter/"
```

- [ ] **Step 3: Commit any remaining fixes**

---

## Summary

| Task | Files | What |
|------|-------|------|
| 1 | `scripts/generate_tga.py`, `Media/*.tga`, `Widgets.lua` | Generate 7 new TGA assets, update media paths |
| 2 | `UI/Sidebar.lua`, `KeySorter.toc`, `Core.lua` | New sidebar component with animation |
| 3 | `UI/MainFrame.lua` | Remove title bar, add sidebar + content area |
| 4 | `UI/Settings.lua` | Convert popup to inline scrollable panel |
| 5 | `UI/CharacterDetail.lua` | Fix overlay anchoring for sidebar layout |
| 6 | `Core.lua` | Update slash commands |
| 7 | — | Deploy and verify |
