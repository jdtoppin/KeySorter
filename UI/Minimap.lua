local addonName, KS = ...

local BUTTON_SIZE = 31

-- Calculate edge position for both circular and square minimaps
local function GetMinimapEdgePosition(angle)
    local rad = math.rad(angle)
    local cos, sin = math.cos(rad), math.sin(rad)

    -- Get minimap dimensions (half-size)
    local hw = Minimap:GetWidth() / 2
    local hh = Minimap:GetHeight() / 2

    -- Check if minimap is square (GetMaskTexture or shape detection)
    local isSquare = GetMinimapShape and GetMinimapShape() ~= "ROUND"

    if isSquare then
        -- For square/rectangular minimaps: clamp to the rectangle edge
        -- Find where the angle ray intersects the rectangle boundary
        local x, y
        if math.abs(cos) * hh > math.abs(sin) * hw then
            -- Hits left or right edge
            x = (cos > 0) and hw or -hw
            y = x * sin / cos
        else
            -- Hits top or bottom edge
            y = (sin > 0) and hh or -hh
            x = y * cos / sin
        end
        return x, y
    else
        -- Circular minimap: use the smaller dimension as radius
        local radius = math.min(hw, hh)
        return cos * radius, sin * radius
    end
end

function KS.CreateMinimapButton()
    local btn = CreateFrame("Button", "KeySorterMinimapButton", Minimap)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Icon background (circular area behind the label)
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 6, -6)
    icon:SetColorTexture(0.08, 0.08, 0.08, 1)

    -- "KS" text label as the icon
    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 6, -6)
    label:SetPoint("BOTTOMRIGHT", -5, 5)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText("|cff00ccffKS|r")

    -- Standard circular minimap border overlay
    -- The border texture visual circle is offset within the image;
    -- anchoring at TOPLEFT with size 53x53 aligns it with the button
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight texture (standard minimap button glow on hover)
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(24, 24)
    highlight:SetPoint("TOPLEFT", 4, -4)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    -- Tooltip
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

    -- Position around minimap edge (works with circular and square minimaps)
    local function UpdatePosition()
        local angle = KeySorterDB.minimapPos or 225
        local x, y = GetMinimapEdgePosition(angle)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    -- Drag to reposition around minimap
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            KeySorterDB.minimapPos = angle
            local x, y = GetMinimapEdgePosition(angle)
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            SlashCmdList["KEYSORTER"]("")
        elseif button == "RightButton" then
            SlashCmdList["KEYSORTER"]("about")
        end
    end)

    UpdatePosition()
    KS.minimapButton = btn
end
