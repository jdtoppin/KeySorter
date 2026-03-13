local addonName, KS = ...

local BUTTON_SIZE = 32
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

    -- Squared background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.85)

    -- Border
    local border = btn:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Inner bg (on top of border to create border effect)
    local inner = btn:CreateTexture(nil, "ARTWORK")
    inner:SetAllPoints()
    inner:SetColorTexture(0.1, 0.1, 0.1, 0.85)

    -- "KS" text label
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    label:SetText("|cff00ccffKS|r")

    -- Hover effect
    btn:SetScript("OnEnter", function(self)
        inner:SetColorTexture(0.15, 0.15, 0.15, 0.95)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("KeySorter", 0, 0.8, 1)
        GameTooltip:AddLine("|cffccccccLeft-click|r toggle window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffccccccRight-click|r about", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        inner:SetColorTexture(0.1, 0.1, 0.1, 0.85)
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
        self._dragging = true
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
        self._dragging = false
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
