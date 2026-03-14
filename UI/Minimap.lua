local addonName, KS = ...

local BUTTON_SIZE = 31
local MINIMAP_RADIUS = 80

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
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("KeySorter", 0, 0.8, 1)
        GameTooltip:AddLine("|cffccccccLeft-click|r toggle window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffccccccRight-click|r about", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Position around minimap
    local function UpdatePosition()
        local angle = math.rad(KeySorterDB.minimapPos or 225)
        local x = math.cos(angle) * MINIMAP_RADIUS
        local y = math.sin(angle) * MINIMAP_RADIUS
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
            self:ClearAllPoints()
            local rad = math.rad(angle)
            self:SetPoint("CENTER", Minimap, "CENTER",
                math.cos(rad) * MINIMAP_RADIUS,
                math.sin(rad) * MINIMAP_RADIUS)
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
