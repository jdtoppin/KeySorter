local addonName, KS = ...

local PREFIX = "KeySorter"
local SYNC_MSG = "SYNC"
local SYNC_PART_MSG = "SYNC_P"
local HELLO_MSG = "HELLO"

local MAX_MSG_LEN = 255

-- Buffer for reassembling multi-part messages, keyed by sender name
local chunkBuffers = {} -- { [sender] = { parts = {}, total = N } }

-- Simple serialization (no external libs needed for v1)
-- Format: "SYNC|groupCount|g1tank,g1healer,g1d1,g1d2,g1d3|g2...|unassigned:n1,n2,n3"

-- Create a stub member for synced names not found in the local roster.
-- Looks up KeySorterDB.knownChars for correct class, role, and utility flags.
local function CreateStubMember(name, role)
    local classFile = "PRIEST"
    local knownRole = role

    if KeySorterDB and KeySorterDB.knownChars and KeySorterDB.knownChars[name] then
        local info = KeySorterDB.knownChars[name]
        classFile = info.classFile or classFile
    end

    local hasBrez = KS.BREZ[classFile] or false
    local hasLust = KS.LUST[classFile] or false
    local hasShroud = KS.SHROUD[classFile] or false
    local utilityCount = (hasBrez and 1 or 0) + (hasLust and 1 or 0) + (hasShroud and 1 or 0)

    return {
        name = name,
        classFile = classFile,
        role = knownRole,
        score = 0,
        runs = {},
        avgKeyLevel = 0,
        numRuns = 0,
        numTimed = 0,
        numUntimed = 0,
        ilvl = 0,
        hasBrez = hasBrez,
        hasLust = hasLust,
        hasShroud = hasShroud,
        utilityCount = utilityCount,
        dataSource = "sync",
    }
end

-- Check if a sender has raid leader or assistant rank
local function IsSenderPermitted(sender)
    for i = 1, GetNumGroupMembers() do
        local name, rank = GetRaidRosterInfo(i)
        if name then
            local shortName = name:match("^([^-]+)") or name
            if shortName == sender then
                -- rank: 2 = leader, 1 = assistant, 0 = member
                return rank >= 1
            end
        end
    end
    return false
end

function KS.InitComm()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

    local commFrame = CreateFrame("Frame")
    commFrame:RegisterEvent("CHAT_MSG_ADDON")
    commFrame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
        if prefix ~= PREFIX then return end
        -- Don't process our own messages
        local myName = UnitName("player")
        if sender == myName or sender == myName .. "-" .. GetRealmName() then
            return
        end
        -- Strip realm from sender name for display
        local shortSender = sender:match("^([^-]+)") or sender
        KS.HandleCommMessage(msg, shortSender)
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

-- Split data into chunks and send as multi-part messages
local function SendChunked(data)
    -- Calculate overhead for the header: "SYNC_P|partNum|totalParts|"
    -- Max part number and total are at most 2 digits each, header max ~ 15 chars
    local headerReserve = 20 -- generous reserve for "SYNC_P|NN|NN|"
    local chunkSize = MAX_MSG_LEN - headerReserve

    local chunks = {}
    for i = 1, #data, chunkSize do
        table.insert(chunks, data:sub(i, i + chunkSize - 1))
    end

    local total = #chunks
    for i, chunk in ipairs(chunks) do
        local msg = SYNC_PART_MSG .. "|" .. i .. "|" .. total .. "|" .. chunk
        C_ChatInfo.SendAddonMessage(PREFIX, msg, "RAID")
    end
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
    if #data > MAX_MSG_LEN then
        SendChunked(data)
    else
        C_ChatInfo.SendAddonMessage(PREFIX, data, "RAID")
    end
    print("|cff00ccffKeySorter|r: Groups synced to raid.")
end

-- Auto-sync: silently send group data if in a raid with permission
function KS.AutoSync()
    if KS.previewMode then return end
    if not IsInRaid() then return end
    if not KS.IsPermitted() then return end
    if #KS.groups == 0 then return end

    local data = KS.SerializeGroups()
    if #data > MAX_MSG_LEN then
        SendChunked(data)
    else
        C_ChatInfo.SendAddonMessage(PREFIX, data, "RAID")
    end
end

local function IsNewerVersion(remote, localVer)
    local r1, r2, r3 = remote:match("^(%d+)%.(%d+)%.(%d+)$")
    local l1, l2, l3 = localVer:match("^(%d+)%.(%d+)%.(%d+)$")
    if not r1 or not l1 then return false end
    r1, r2, r3 = tonumber(r1), tonumber(r2), tonumber(r3)
    l1, l2, l3 = tonumber(l1), tonumber(l2), tonumber(l3)
    if r1 ~= l1 then return r1 > l1 end
    if r2 ~= l2 then return r2 > l2 end
    return r3 > l3
end

-- Process a fully reassembled SYNC message
local function ProcessSyncMessage(msg, sender)
    local parts = { strsplit("|", msg) }

    if parts[1] ~= SYNC_MSG then return end

    -- Validate sender has leader/assistant rank
    if not IsSenderPermitted(sender) then
        return
    end

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
                tank = byName[names[1]] or (names[1] ~= "" and CreateStubMember(names[1], "TANK") or nil),
                healer = byName[names[2]] or (names[2] ~= "" and CreateStubMember(names[2], "HEALER") or nil),
                dps = {},
            }
            for j = 3, #names do
                local member = byName[names[j]] or CreateStubMember(names[j], "DAMAGER")
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
                local member = byName[uname] or CreateStubMember(uname, "DAMAGER")
                table.insert(KS.unassigned, member)
            end
        end
    end

    print(format("|cff00ccffKeySorter|r: Received %d group(s) from %s.", numGroups, sender))

    if KS.UpdateGroupView then KS.UpdateGroupView() end
end

function KS.HandleCommMessage(msg, sender)
    local parts = { strsplit("|", msg) }

    -- Handle presence handshake
    if parts[1] == HELLO_MSG then
        local version = parts[2] or "?"
        local role = parts[3] or "member"
        -- Only show sync message for raid members, not guild-only
        if role ~= "guild member" then
            print(format("|cff00ccffKeySorter|r: Synced with %s (v%s, %s). Addon communication active.", sender, version, role))
        end
        -- Check for newer version (show for both guild and raid)
        local myVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0"
        if version ~= "?" and IsNewerVersion(version, myVersion) then
            if not KS._updateNotified then
                KS._updateNotified = true
                print(format("|cff00ccffKeySorter|r: |cffff8800Update available!|r %s has v%s (you have v%s). Please update.", sender, version, myVersion))
            end
        end
        -- Send hello back
        if not KS._helloSent then
            KS._helloSent = true
            KS.SendHello()
        end
        return
    end

    -- Handle multi-part sync messages
    if parts[1] == SYNC_PART_MSG then
        local partNum = tonumber(parts[2])
        local totalParts = tonumber(parts[3])
        -- Rejoin remaining parts (the data chunk may contain "|" characters)
        local chunk = msg:match("^" .. SYNC_PART_MSG .. "|%d+|%d+|(.+)$")
        if not partNum or not totalParts or not chunk then return end

        if not chunkBuffers[sender] then
            chunkBuffers[sender] = { parts = {}, total = totalParts }
        end
        local buf = chunkBuffers[sender]
        buf.parts[partNum] = chunk
        buf.total = totalParts

        -- Check if all parts received
        local complete = true
        for i = 1, buf.total do
            if not buf.parts[i] then
                complete = false
                break
            end
        end

        if complete then
            local fullData = table.concat(buf.parts)
            chunkBuffers[sender] = nil

            -- Permission gate: only leaders/assistants process group sync data
            if not KS.IsPermitted() then return end

            ProcessSyncMessage(fullData, sender)
        end
        return
    end

    -- Permission gate: only leaders/assistants process group sync data
    if not KS.IsPermitted() then return end

    -- Handle single-message SYNC (fits within 255 bytes)
    if parts[1] == SYNC_MSG then
        ProcessSyncMessage(msg, sender)
    end
end

-- Broadcast presence to raid and/or guild
function KS.SendHello()
    if KS.previewMode then return end
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
    local role = "member"
    if IsInRaid() then
        if UnitIsGroupLeader("player") then
            role = "raid leader"
        elseif KS.IsPermitted() then
            role = "assistant"
        end
        C_ChatInfo.SendAddonMessage(PREFIX, HELLO_MSG .. "|" .. version .. "|" .. role, "RAID")
    end
    -- Also broadcast on guild channel for version checking
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(PREFIX, HELLO_MSG .. "|" .. version .. "|guild member", "GUILD")
    end
end

-- Guild-only version check on login
function KS.SendGuildVersionCheck()
    if KS.previewMode then return end
    if not IsInGuild() then return end
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
    C_ChatInfo.SendAddonMessage(PREFIX, HELLO_MSG .. "|" .. version .. "|guild member", "GUILD")
end

-- Initialize comms on load
KS.InitComm()
