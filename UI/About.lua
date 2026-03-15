local addonName, KS = ...

function KS.CreateAboutView(parent)
    local scrollFrame, scrollChild = KS.CreateScrollFrame(parent, "KeySorterAboutScroll")

    local y = -8
    local INDENT = 16
    local CARD_INSET = 12

    ---------------------------------------------------------------------------
    -- Helpers
    ---------------------------------------------------------------------------
    local function AddHeading(text)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 8, y)
        fs:SetText(text)
        fs:SetTextColor(0, 0.8, 1)
        y = y - 20
    end

    local function AddText(text, r, g, b, indent)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", (indent or 8), y)
        fs:SetPoint("TOPRIGHT", -8, y)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
        fs:SetWordWrap(true)
        y = y - (fs:GetStringHeight() + 6)
    end

    local function AddSmallText(text, r, g, b, indent)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", (indent or 8), y)
        fs:SetPoint("TOPRIGHT", -8, y)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(r or 0.7, g or 0.7, b or 0.7)
        fs:SetWordWrap(true)
        y = y - (fs:GetStringHeight() + 4)
    end

    local function AddSpacer(h)
        y = y - (h or 8)
    end

    local function AddDivider()
        local line = scrollChild:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", 8, y)
        line:SetPoint("TOPRIGHT", -8, y)
        line:SetHeight(1)
        line:SetColorTexture(0.2, 0.2, 0.2, 1)
        y = y - 12
    end

    -- Feature card: bordered section with icon-like header
    local function AddFeatureCard(title, desc, details)
        local cardTop = y
        y = y - 4

        -- Title
        local titleFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFs:SetPoint("TOPLEFT", INDENT, y)
        titleFs:SetText("|cff00ccff" .. title .. "|r")
        y = y - 16

        -- Description
        local descFs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descFs:SetPoint("TOPLEFT", INDENT + 4, y)
        descFs:SetPoint("TOPRIGHT", -INDENT, y)
        descFs:SetJustifyH("LEFT")
        descFs:SetText(desc)
        descFs:SetTextColor(0.75, 0.75, 0.75)
        descFs:SetWordWrap(true)
        y = y - (descFs:GetStringHeight() + 4)

        -- Detail bullets
        if details then
            for _, d in ipairs(details) do
                local df = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                df:SetPoint("TOPLEFT", INDENT + 8, y)
                df:SetPoint("TOPRIGHT", -INDENT, y)
                df:SetJustifyH("LEFT")
                df:SetText("|cff888888-|r " .. d)
                df:SetTextColor(0.65, 0.65, 0.65)
                df:SetWordWrap(true)
                y = y - (df:GetStringHeight() + 2)
            end
        end

        y = y - 6
    end

    ---------------------------------------------------------------------------
    -- Hero Header
    ---------------------------------------------------------------------------
    local title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 8, y)
    title:SetText("KeySorter")
    title:SetTextColor(0, 0.8, 1)

    local version = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"))
    version:SetTextColor(0.5, 0.5, 0.5)
    y = y - 28

    AddText("Automatically sort raid members into balanced Mythic+ groups based on score, role, and class utility.", 0.7, 0.7, 0.7)
    AddSpacer(4)
    AddDivider()

    ---------------------------------------------------------------------------
    -- Features
    ---------------------------------------------------------------------------
    AddHeading("Features")
    AddSpacer(4)

    AddFeatureCard("Roster View", "Browse all raid members at a glance with sortable columns and quick filters.", {
        "Sort by name, score, iLvl, avg key, timed runs, role, or utility count",
        "Filter by score range, role, utility type, or minimum timed runs",
        "Shift-hover any member for a detailed dungeon breakdown tooltip",
        "Click any member to open their full character profile",
    })

    AddFeatureCard("Group Builder", "Form balanced 5-man groups with one click, then fine-tune with drag and drop.", {
        "Two sort modes: |cffffffffSkill Matched|r (similar skill together) or |cffffffffBalanced|r (snake draft for even distribution)",
        "Battle Rez and Bloodlust coverage balanced automatically across groups",
        "Drag and drop members between groups to manually adjust",
        "Lock groups to preserve them during re-sorts",
        "New players joining go to Unassigned — sort when you're ready",
    })

    AddFeatureCard("Smart Data", "Pulls M+ data from Raider.IO when available, falls back to Blizzard's API.", {
        "Score, dungeon runs, timed/untimed counts, key level thresholds",
        "Item level collected via background inspect (automatic)",
        "Syncs group assignments to raid assistants automatically",
    })

    AddDivider()

    ---------------------------------------------------------------------------
    -- Sort Modes Explained
    ---------------------------------------------------------------------------
    AddHeading("How Sorting Works")
    AddSpacer(4)

    AddSmallText("1.  Players are split into Tanks, Healers, and DPS pools, each sorted by M+ score.", 0.75, 0.75, 0.75, INDENT)
    AddSmallText("2.  Groups are formed: 1 tank + 1 healer + 3 DPS each. Group count = scarcest role.", 0.75, 0.75, 0.75, INDENT)
    AddSmallText("3.  DPS distribution depends on the selected mode:", 0.75, 0.75, 0.75, INDENT)
    AddSmallText("|cffffffffSkill Matched|r — Top DPS to Group 1, next best to Group 2, etc.", 0.65, 0.65, 0.65, INDENT + 12)
    AddSmallText("|cffffffffBalanced|r — Snake draft (1→N, N→1) for even score distribution.", 0.65, 0.65, 0.65, INDENT + 12)
    AddSmallText("4.  A utility pass swaps DPS between groups to cover Battle Rez and Bloodlust gaps.", 0.75, 0.75, 0.75, INDENT)
    AddSmallText("5.  Locked groups are fully excluded from sorting and utility balancing.", 0.75, 0.75, 0.75, INDENT)
    AddSmallText("6.  Extra players (raid not a multiple of 5) go to Unassigned.", 0.75, 0.75, 0.75, INDENT)
    AddSpacer(4)
    AddDivider()

    ---------------------------------------------------------------------------
    -- Commands
    ---------------------------------------------------------------------------
    AddHeading("Slash Commands")
    AddSpacer(4)

    local commands = {
        { "/ks",             "Toggle the KeySorter window" },
        { "/ks sort",        "Sort roster into groups" },
        { "/ks apply",       "Move players to raid subgroups" },
        { "/ks announce",    "Post all groups to raid chat" },
        { "/ks announce N",  "Post group N to raid chat" },
        { "/ks sync",        "Force sync groups to assistants" },
        { "/ks settings",    "Open settings" },
        { "/ks about",       "Show this page" },
        { "/ks help",        "Print commands to chat" },
    }

    for _, cmd in ipairs(commands) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetPoint("TOPLEFT", INDENT, y)
        row:SetPoint("TOPRIGHT", -8, y)
        row:SetHeight(16)

        local cmdFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cmdFs:SetPoint("LEFT", 0, 0)
        cmdFs:SetText("|cff00ff00" .. cmd[1] .. "|r")

        local descFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descFs:SetPoint("LEFT", 120, 0)
        descFs:SetText(cmd[2])
        descFs:SetTextColor(0.6, 0.6, 0.6)

        y = y - 16
    end

    AddSpacer(4)
    AddDivider()

    ---------------------------------------------------------------------------
    -- Credits
    ---------------------------------------------------------------------------
    AddHeading("Credits")
    AddSpacer(4)
    AddSmallText("Created by |cffffffffJosiah Toppin|r", 0.7, 0.7, 0.7, INDENT)
    AddSmallText("UI inspired by |cffffffffAbstractFramework|r by enderneko (GPLv3)", 0.7, 0.7, 0.7, INDENT)
    AddSmallText("Licensed under |cffffffffGNU General Public License v3.0|r", 0.7, 0.7, 0.7, INDENT)

    scrollChild:SetHeight(math.abs(y) + 16)
end
