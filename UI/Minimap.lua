local addonName, KS = ...

local BUTTON_SIZE = 28
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

    -- Background circle
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface/Minimap/UI-Minimap-Background")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- Border ring
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(BUTTON_SIZE + 6, BUTTON_SIZE + 6)
    border:SetPoint("CENTER")
    border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")

    -- "KS" text label
    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText("|cff00ccffKS|r")

    -- Hover highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    -- Position around minimap
    local function UpdatePosition()
        local angle = math.rad(KeySorterDB.minimapPos or 225)
        local x = math.cos(angle) * MINIMAP_RADIUS
        local y = math.sin(angle) * MINIMAP_RADIUS
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    -- Drag to reposition around minimap
    local isDragging = false
    btn:SetScript("OnDragStart", function(self)
        isDragging = true
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
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            SlashCmdList["KEYSORTER"]("")
        elseif button == "RightButton" then
            SlashCmdList["KEYSORTER"]("about")
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("KeySorter", 0, 0.8, 1)
        GameTooltip:AddLine("|cffccccccLeft-click|r to toggle window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffccccccRight-click|r for about/credits", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()
    KS.minimapButton = btn
end
