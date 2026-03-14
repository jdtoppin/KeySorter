local addonName, KS = ...

local PREFIX = "KeySorter"
local SYNC_MSG = "SYNC"

-- Simple serialization (no external libs needed for v1)
-- Format: "SYNC|groupCount|g1tank,g1healer,g1d1,g1d2,g1d3|g2...|unassigned:n1,n2,n3"

function KS.InitComm()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

    local commFrame = CreateFrame("Frame")
    commFrame:RegisterEvent("CHAT_MSG_ADDON")
    commFrame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
        if prefix ~= PREFIX then return end
        if not KS.IsPermitted() then return end
        -- Don't process our own messages
        if sender == UnitName("player") or sender == UnitName("player") .. "-" .. GetRealmName() then
            return
        end
        KS.HandleCommMessage(msg, sender)
    end)
end

function KS.SerializeGroups()
    local parts = { SYNC_MSG, tostring(#KS.groups) }

    for _, group in ipairs(KS.groups) do
        local members = {}
        table.insert(members, group.tank and group.tank.name or "")
        table.insert(members, group.healer and group.healer.name or "")
        for _, d in ipairs(group.dps) do
            table.insert(members, d.name)
        end
        table.insert(parts, table.concat(members, ","))
    end

    -- Unassigned
    local unNames = {}
    for _, u in ipairs(KS.unassigned) do
        table.insert(unNames, u.name)
    end
    table.insert(parts, "U:" .. table.concat(unNames, ","))

    return table.concat(parts, "|")
end

function KS.SendSync()
    if not IsInRaid() then
        print("|cff00ccffKeySorter|r: Must be in a raid to sync.")
        return
    end
    if not KS.IsPermitted() then
        print("|cff00ccffKeySorter|r: Only raid leader/assistants can sync.")
        return
    end
    if #KS.groups == 0 then
        print("|cff00ccffKeySorter|r: No groups to sync. Sort first.")
        return
    end

    local data = KS.SerializeGroups()
    C_ChatInfo.SendAddonMessage(PREFIX, data, "RAID")
    print("|cff00ccffKeySorter|r: Groups synced to raid.")
end

-- Auto-sync: silently send group data if in a raid with permission
function KS.AutoSync()
    if KS.previewMode then return end
    if not IsInRaid() then return end
    if not KS.IsPermitted() then return end
    if #KS.groups == 0 then return end

    local data = KS.SerializeGroups()
    C_ChatInfo.SendAddonMessage(PREFIX, data, "RAID")
end

function KS.HandleCommMessage(msg, sender)
    local parts = { strsplit("|", msg) }
    if parts[1] ~= SYNC_MSG then return end

    local numGroups = tonumber(parts[2]) or 0
    if numGroups == 0 then return end

    -- Rebuild groups from names by matching against local roster
    -- First ensure we have roster data
    if #KS.roster == 0 then
        print(format("|cff00ccffKeySorter|r: Received groups from %s but no roster data. Scanning...", sender))
        KS.ScanRoster()
    end

    -- Build name lookup
    local byName = {}
    for _, member in ipairs(KS.roster) do
        byName[member.name] = member
    end

    wipe(KS.groups)
    wipe(KS.unassigned)

    for i = 1, numGroups do
        local groupData = parts[i + 2]
        if groupData then
            local names = { strsplit(",", groupData) }
            KS.groups[i] = {
                tank = byName[names[1]] or (names[1] ~= "" and { name = names[1], classFile = "PRIEST", role = "TANK", score = 0 } or nil),
                healer = byName[names[2]] or (names[2] ~= "" and { name = names[2], classFile = "PRIEST", role = "HEALER", score = 0 } or nil),
                dps = {},
            }
            for j = 3, #names do
                local member = byName[names[j]] or { name = names[j], classFile = "PRIEST", role = "DAMAGER", score = 0 }
                table.insert(KS.groups[i].dps, member)
            end
        end
    end

    -- Unassigned
    local unPart = parts[numGroups + 3]
    if unPart and unPart:sub(1, 2) == "U:" then
        local unNames = { strsplit(",", unPart:sub(3)) }
        for _, uname in ipairs(unNames) do
            if uname ~= "" then
                local member = byName[uname] or { name = uname, classFile = "PRIEST", role = "DAMAGER", score = 0 }
                table.insert(KS.unassigned, member)
            end
        end
    end

    print(format("|cff00ccffKeySorter|r: Received %d group(s) from %s.", numGroups, sender))

    if KS.UpdateGroupView then KS.UpdateGroupView() end
end

-- Initialize comms on load
KS.InitComm()
