local addonName, KS = ...

function KS.SortGroups()
    wipe(KS.unassigned)

    if #KS.roster == 0 then
        print("|cff00ccffKeySorter|r: No roster data. Scan first.")
        return
    end

    -- Collect locked groups and their members (by name for matching)
    local lockedGroups = {}
    local lockedNames = {}
    local lockedCount = 0
    for i, group in ipairs(KS.groups) do
        if group.locked then
            table.insert(lockedGroups, { index = i, group = group })
            if group.tank then lockedNames[group.tank.name] = true; lockedCount = lockedCount + 1 end
            if group.healer then lockedNames[group.healer.name] = true; lockedCount = lockedCount + 1 end
            for _, d in ipairs(group.dps) do
                lockedNames[d.name] = true; lockedCount = lockedCount + 1
            end
        end
    end

    -- Step 1: Separate unlocked roster members by role
    local tanks, healers, dps = {}, {}, {}
    for _, member in ipairs(KS.roster) do
        if not lockedNames[member.name] then
            if member.role == "TANK" then
                table.insert(tanks, member)
            elseif member.role == "HEALER" then
                table.insert(healers, member)
            else
                table.insert(dps, member)
            end
        end
    end

    local unlocked = #tanks + #healers + #dps

    -- Step 2: Sort each pool by the selected criteria
    local sortFunc
    if KS.sortMode == "gear" then
        sortFunc = function(a, b)
            local aIlvl = (a.ilvl and a.ilvl > 0) and a.ilvl or 0
            local bIlvl = (b.ilvl and b.ilvl > 0) and b.ilvl or 0
            if aIlvl ~= bIlvl then return aIlvl > bIlvl end
            return a.score > b.score
        end
    else
        sortFunc = function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return (a.ilvl or 0) > (b.ilvl or 0)
        end
    end
    table.sort(tanks, sortFunc)
    table.sort(healers, sortFunc)
    table.sort(dps, sortFunc)

    -- Step 3: Determine total groups needed based on total player count
    -- WoW raid subgroups hold 5 — create enough groups for everyone
    local totalPlayers = lockedCount + unlocked
    local totalGroupsNeeded = math.ceil(totalPlayers / 5)
    -- At minimum, enough for locked groups
    totalGroupsNeeded = math.max(totalGroupsNeeded, #lockedGroups)

    -- Number of complete groups we can form (1T+1H+3D)
    local numCompleteGroups = math.floor(math.min(#tanks, #healers, #dps / 3))
    -- Total new group slots (complete + incomplete/empty)
    local numNewSlots = totalGroupsNeeded - #lockedGroups

    -- Build all new groups
    local newGroups = {}
    for i = 1, numNewSlots do
        newGroups[i] = { tank = nil, healer = nil, dps = {} }
    end

    -- Step 4: Fill complete groups first (1T+1H+3D)
    for i = 1, math.min(numCompleteGroups, numNewSlots) do
        newGroups[i].tank = tanks[i]
        newGroups[i].healer = healers[i]
    end

    local dpsNeeded = math.min(numCompleteGroups, numNewSlots) * 3
    local dpsToAssign = math.min(#dps, dpsNeeded)

    if KS.sortMode == "balanced" and numCompleteGroups > 0 then
        local groupIdx = 1
        local direction = 1
        local maxG = math.min(numCompleteGroups, numNewSlots)
        for i = 1, dpsToAssign do
            table.insert(newGroups[groupIdx].dps, dps[i])
            if (direction == 1 and groupIdx == maxG) or (direction == -1 and groupIdx == 1) then
                direction = direction * -1
            else
                groupIdx = groupIdx + direction
            end
        end
    else
        for i = 1, dpsToAssign do
            local groupIdx = math.ceil(i / 3)
            if groupIdx <= numNewSlots then
                table.insert(newGroups[groupIdx].dps, dps[i])
            end
        end
    end

    -- Step 5: Distribute remaining players into remaining group slots (up to 5 each)
    local extraTanks = {}
    for i = math.min(numCompleteGroups, numNewSlots) + 1, #tanks do table.insert(extraTanks, tanks[i]) end
    local extraHealers = {}
    for i = math.min(numCompleteGroups, numNewSlots) + 1, #healers do table.insert(extraHealers, healers[i]) end
    local extraDps = {}
    for i = dpsToAssign + 1, #dps do table.insert(extraDps, dps[i]) end

    -- Fill remaining group slots with extras
    for i = math.min(numCompleteGroups, numNewSlots) + 1, numNewSlots do
        local count = 0
        if #extraTanks > 0 and count < 5 then
            newGroups[i].tank = table.remove(extraTanks, 1)
            count = count + 1
        end
        if #extraHealers > 0 and count < 5 then
            newGroups[i].healer = table.remove(extraHealers, 1)
            count = count + 1
        end
        while #extraDps > 0 and count < 5 do
            table.insert(newGroups[i].dps, table.remove(extraDps, 1))
            count = count + 1
        end
    end

    -- Any remaining extras that didn't fit (shouldn't happen with correct math)
    for _, t in ipairs(extraTanks) do table.insert(KS.unassigned, t) end
    for _, h in ipairs(extraHealers) do table.insert(KS.unassigned, h) end
    for _, d in ipairs(extraDps) do table.insert(KS.unassigned, d) end

    -- Merge: locked groups at their original positions, new groups fill the rest
    wipe(KS.groups)
    wipe(KS.incompleteGroups)

    -- Place locked groups back at their original indices
    for _, lg in ipairs(lockedGroups) do
        KS.groups[lg.index] = lg.group
    end

    -- Separate complete from incomplete new groups
    local completeNew = {}
    local incompleteNew = {}
    for _, g in ipairs(newGroups) do
        local count = 0
        if g.tank then count = count + 1 end
        if g.healer then count = count + 1 end
        count = count + #g.dps
        if count == 5 and g.tank and g.healer and #g.dps == 3 then
            table.insert(completeNew, g)
        elseif count > 0 then
            table.insert(incompleteNew, g)
        end
        -- Empty groups (count == 0) are dropped
    end

    -- Fill KS.groups with complete groups
    local newIdx = 1
    for i = 1, totalGroupsNeeded do
        if not KS.groups[i] then
            if newIdx <= #completeNew then
                KS.groups[i] = completeNew[newIdx]
                newIdx = newIdx + 1
            end
        end
    end

    -- Store incomplete groups separately (displayed after unassigned)
    for _, g in ipairs(incompleteNew) do
        table.insert(KS.incompleteGroups, g)
    end

    -- Step 5: Utility balancing pass (only on unlocked groups)
    KS.BalanceUtilities()

    local numLocked = #lockedGroups
    local totalGroups = #KS.groups
    local lockMsg = numLocked > 0 and format(" (%d locked)", numLocked) or ""
    print(format("|cff00ccffKeySorter|r: Formed %d group(s)%s, %d unassigned.", totalGroups, lockMsg, #KS.unassigned))

    if KS.UpdateGroupView then KS.UpdateGroupView() end
    KS.AutoSync()
end

---------------------------------------------------------------------------
-- Utility balancing: try to give each group brez and lust coverage
-- by swapping DPS between groups, preferring swaps between adjacent
-- groups (similar skill tiers) to minimize skill disruption.
-- Skips locked groups.
---------------------------------------------------------------------------
function KS.BalanceUtilities()
    local numGroups = #KS.groups
    if numGroups < 2 then return end

    for i = 1, numGroups do
        local group = KS.groups[i]
        if not group.locked then
            if not KS.GroupHasUtility(group, "hasBrez") then
                KS.TrySwapForUtility(i, "hasBrez")
            end
            if not KS.GroupHasUtility(group, "hasLust") then
                KS.TrySwapForUtility(i, "hasLust")
            end
        end
    end
end

function KS.GroupHasUtility(group, utilKey)
    if group.tank and group.tank[utilKey] then return true end
    if group.healer and group.healer[utilKey] then return true end
    for _, d in ipairs(group.dps) do
        if d[utilKey] then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Reconcile groups after roster changes (join/leave)
-- Removes members no longer in roster, adds new members to unassigned.
-- Does NOT re-sort — preserves existing group assignments.
---------------------------------------------------------------------------
function KS.ReconcileGroups()
    if #KS.groups == 0 then return end

    -- Build lookup of current roster names
    local rosterNames = {}
    for _, member in ipairs(KS.roster) do
        rosterNames[member.name] = member
    end

    -- Build lookup of all assigned member names
    local assignedNames = {}

    -- Remove departed members from groups, update member data for those still present
    for _, group in ipairs(KS.groups) do
        if group.tank then
            if rosterNames[group.tank.name] then
                group.tank = rosterNames[group.tank.name]
                assignedNames[group.tank.name] = true
            else
                group.tank = nil
            end
        end
        if group.healer then
            if rosterNames[group.healer.name] then
                group.healer = rosterNames[group.healer.name]
                assignedNames[group.healer.name] = true
            else
                group.healer = nil
            end
        end
        local newDps = {}
        for _, d in ipairs(group.dps) do
            if rosterNames[d.name] then
                table.insert(newDps, rosterNames[d.name])
                assignedNames[d.name] = true
            end
        end
        group.dps = newDps
    end

    -- Also update unassigned — remove departed, keep existing
    local newUnassigned = {}
    for _, member in ipairs(KS.unassigned) do
        if rosterNames[member.name] then
            table.insert(newUnassigned, rosterNames[member.name])
            assignedNames[member.name] = true
        end
    end

    -- Add new roster members (not in any group or unassigned) to unassigned
    for _, member in ipairs(KS.roster) do
        if not assignedNames[member.name] then
            table.insert(newUnassigned, member)
        end
    end

    KS.unassigned = newUnassigned
end

function KS.GroupScore(group)
    local total = 0
    local count = 0
    if group.tank then total = total + group.tank.score; count = count + 1 end
    if group.healer then total = total + group.healer.score; count = count + 1 end
    for _, d in ipairs(group.dps) do
        total = total + d.score
        count = count + 1
    end
    return count > 0 and (total / count) or 0
end

-- Swap DPS to cover a missing utility, preferring adjacent groups
-- (closer in skill tier) over distant ones. Skips locked groups.
function KS.TrySwapForUtility(needGroupIdx, utilKey)
    local needGroup = KS.groups[needGroupIdx]
    if needGroup.locked then return end

    local bestSwap = nil
    local bestPriority = math.huge

    for otherIdx = 1, #KS.groups do
        if otherIdx ~= needGroupIdx then
            local otherGroup = KS.groups[otherIdx]
            if not otherGroup.locked then
                local groupDistance = math.abs(otherIdx - needGroupIdx)

                for ni, needDPS in ipairs(needGroup.dps) do
                    if not needDPS[utilKey] then
                        for oi, otherDPS in ipairs(otherGroup.dps) do
                            if otherDPS[utilKey] then
                                local otherStillHas = false
                                if otherGroup.tank and otherGroup.tank[utilKey] then otherStillHas = true end
                                if otherGroup.healer and otherGroup.healer[utilKey] then otherStillHas = true end
                                for k, d in ipairs(otherGroup.dps) do
                                    if k ~= oi and d[utilKey] then otherStillHas = true end
                                end

                                if otherStillHas then
                                    local scoreDiff = math.abs(needDPS.score - otherDPS.score)
                                    local priority = groupDistance * 100 + scoreDiff
                                    if priority < bestPriority then
                                        bestPriority = priority
                                        bestSwap = {
                                            needGroupIdx = needGroupIdx, needDPSIdx = ni,
                                            otherGroupIdx = otherIdx, otherDPSIdx = oi,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if bestSwap then
        local needDPS = KS.groups[bestSwap.needGroupIdx].dps[bestSwap.needDPSIdx]
        local otherDPS = KS.groups[bestSwap.otherGroupIdx].dps[bestSwap.otherDPSIdx]
        local scoreDiff = math.abs(needDPS.score - otherDPS.score)

        local groupDist = math.abs(bestSwap.needGroupIdx - bestSwap.otherGroupIdx)
        local threshold = groupDist <= 1 and (KS.SWAP_THRESHOLD * 3) or KS.SWAP_THRESHOLD

        if scoreDiff <= threshold then
            KS.groups[bestSwap.needGroupIdx].dps[bestSwap.needDPSIdx] = otherDPS
            KS.groups[bestSwap.otherGroupIdx].dps[bestSwap.otherDPSIdx] = needDPS
        end
    end
end
