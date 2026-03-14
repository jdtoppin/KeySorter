local addonName, KS = ...

function KS.CreateAboutView(parent)
    local scrollFrame, scrollChild = KS.CreateScrollFrame(parent, "KeySorterAboutScroll")

    local y = -8

    local function AddHeading(text)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 8, y)
        fs:SetText(text)
        fs:SetTextColor(0, 0.8, 1)
        y = y - 20
    end

    local function AddText(text, r, g, b)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 8, y)
        fs:SetPoint("TOPRIGHT", -8, y)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
        fs:SetWordWrap(true)
        -- Estimate height from text length and width
        y = y - (fs:GetStringHeight() + 8)
    end

    local function AddSpacer()
        y = y - 8
    end

    -- Title
    local title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, y)
    title:SetText("KeySorter")
    title:SetTextColor(0, 0.8, 1)

    local version = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"))
    version:SetTextColor(0.6, 0.6, 0.6)
    y = y - 24
    AddSpacer()

    AddText("Automatically sort raid members into balanced M+ groups based on Mythic+ score, role, and class utility.")
    AddSpacer()

    ---------------------------------------------------------------------------
    AddHeading("Tabs")
    AddText("|cffffffffRoster|r — View all raid members with their M+ score, average key level, timed/untimed runs, item level, and class utilities. Click column headers to sort. Use the filter dropdowns to narrow by score range, role, utility, or minimum timed runs.")
    AddText("|cffffffffGroups|r — View and manage auto-generated 5-man groups. Sort forms the groups and moves players into raid subgroups, Announce posts assignments to raid chat, and Sync broadcasts to assistants. Drag and drop members between groups to manually adjust.")
    AddSpacer()

    ---------------------------------------------------------------------------
    AddHeading("Sort Logic")
    AddText("1. Players are separated into three pools: Tanks, Healers, and DPS.")
    AddText("2. Each pool is sorted by M+ score (descending), with item level as a tiebreaker.")
    AddText("3. The number of groups is determined by the scarcest role: the maximum number of complete groups that can be formed with 1 tank, 1 healer, and 3 DPS each.")
    AddText("4. Players are assigned by skill tier — the highest-scored tank, healer, and top 3 DPS form Group 1, the next best form Group 2, and so on. This keeps players of similar skill level together.")
    AddText("5. If the raid is not a perfect multiple of 5, extra players are distributed round-robin across groups as additional members rather than being left unassigned.")
    AddText("6. A utility balancing pass then checks each group for battle rez and bloodlust coverage. If a group is missing a utility, the algorithm tries to swap a DPS with another group that has a surplus — preferring swaps between adjacent groups (similar skill tier) and only allowing swaps within a score threshold to avoid disrupting skill balance.")
    AddSpacer()

    ---------------------------------------------------------------------------
    AddHeading("Data Sources")
    AddText("Uses Raider.IO addon data when available, which includes total timed/untimed runs and key level thresholds (+5, +10, +15, +20). Falls back to the native Blizzard API (C_PlayerInfo.GetPlayerMythicPlusRatingSummary) which provides best run per dungeon only.")
    AddText("Item level is collected via background inspect when players are in range. Your own item level is always available.")
    AddSpacer()

    ---------------------------------------------------------------------------
    AddHeading("Commands")
    AddText("|cff00ff00/ks|r  Toggle window")
    AddText("|cff00ff00/ks scan|r  Scan raid roster")
    AddText("|cff00ff00/ks sort|r  Sort into groups")
    AddText("|cff00ff00/ks apply|r  Move players to raid subgroups")
    AddText("|cff00ff00/ks announce|r  Post groups to raid chat")
    AddText("|cff00ff00/ks sync|r  Sync groups to assistants")
    AddText("|cff00ff00/ks preview|r  Open settings (preview mode)")
    AddText("|cff00ff00/ks about|r  Show this page")
    AddText("|cff00ff00/ks help|r  Print command list to chat")
    AddSpacer()

    ---------------------------------------------------------------------------
    AddHeading("Author")
    AddText("Josiah Toppin", 0.9, 0.9, 0.9)
    AddSpacer()

    AddHeading("License")
    AddText("GNU General Public License v3.0", 0.9, 0.9, 0.9)

    scrollChild:SetHeight(math.abs(y) + 16)
end

-- Keep ToggleAbout for the slash command; switches to the about tab
function KS.ToggleAbout()
    if KS.mainFrame and KS.SetTab then
        KS.mainFrame:Show()
        KS.SetTab("about")
    end
end
