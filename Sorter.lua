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

    -- Step 3: Form complete groups only (1T+1H+3D). Extras → unassigned.
    local numCompleteGroups = math.floor(math.min(#tanks, #healers, #dps / 3))

    local newGroups = {}
    for i = 1, numCompleteGroups do
        newGroups[i] = { tank = tanks[i], healer = healers[i], dps = {} }
    end

    -- DPS distribution
    local dpsToAssign = math.min(#dps, numCompleteGroups * 3)

    if KS.sortMode == "balanced" and numCompleteGroups > 0 then
        local groupIdx = 1
        local direction = 1
        for i = 1, dpsToAssign do
            table.insert(newGroups[groupIdx].dps, dps[i])
            if (direction == 1 and groupIdx == numCompleteGroups) or (direction == -1 and groupIdx == 1) then
                direction = direction * -1
            else
                groupIdx = groupIdx + direction
            end
        end
    else
        for i = 1, dpsToAssign do
            local groupIdx = math.ceil(i / 3)
            if groupIdx <= numCompleteGroups then
                table.insert(newGroups[groupIdx].dps, dps[i])
            end
        end
    end

    -- Extras → unassigned (raid lead drags them into empty group cards)
    for i = numCompleteGroups + 1, #tanks do table.insert(KS.unassigned, tanks[i]) end
    for i = numCompleteGroups + 1, #healers do table.insert(KS.unassigned, healers[i]) end
    for i = dpsToAssign + 1, #dps do table.insert(KS.unassigned, dps[i]) end

    -- Merge: locked groups at original positions, new complete groups fill the rest
    wipe(KS.groups)
    wipe(KS.incompleteGroups)

    for _, lg in ipairs(lockedGroups) do
        KS.groups[lg.index] = lg.group
    end

    local newIdx = 1
    for i = 1, #lockedGroups + numCompleteGroups do
        if not KS.groups[i] then
            if newIdx <= numCompleteGroups then
                KS.groups[i] = newGroups[newIdx]
                newIdx = newIdx + 1
            end
        end
    end

    -- Create empty group cards based on total raid size
    -- Total groups needed = ceil(totalPlayers / 5)
    local totalPlayers = #KS.roster
    local totalGroupsNeeded = math.ceil(totalPlayers / 5)
    local filledGroups = #KS.groups
    local emptyGroupsNeeded = math.max(0, totalGroupsNeeded - filledGroups)
    for i = 1, emptyGroupsNeeded do
        table.insert(KS.incompleteGroups, { tank = nil, healer = nil, dps = {} })
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

    -- Reconcile incomplete groups the same way
    if KS.incompleteGroups then
        for _, group in ipairs(KS.incompleteGroups) do
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

    -- Update empty group cards based on total raid size
    -- Groups appear at 5/10/15/20/25/30/35/40 player thresholds
    local totalPlayers = #KS.roster
    local totalGroupsNeeded = math.ceil(totalPlayers / 5)
    local filledGroups = #KS.groups

    -- Count non-empty incomplete groups (ones with members dragged in)
    local nonEmptyIncomplete = 0
    if KS.incompleteGroups then
        for _, g in ipairs(KS.incompleteGroups) do
            local count = 0
            if g.tank then count = count + 1 end
            if g.healer then count = count + 1 end
            count = count + #g.dps
            if count > 0 then nonEmptyIncomplete = nonEmptyIncomplete + 1 end
        end
    end

    -- Ensure we have enough empty group cards
    local emptyGroupsNeeded = math.max(0, totalGroupsNeeded - filledGroups - nonEmptyIncomplete)
    -- Preserve existing incomplete groups that have members
    local newIncomplete = {}
    if KS.incompleteGroups then
        for _, g in ipairs(KS.incompleteGroups) do
            local count = 0
            if g.tank then count = count + 1 end
            if g.healer then count = count + 1 end
            count = count + #g.dps
            if count > 0 then
                table.insert(newIncomplete, g)
            end
        end
    end
    -- Add empty cards to fill up to the needed count
    for i = 1, emptyGroupsNeeded do
        table.insert(newIncomplete, { tank = nil, healer = nil, dps = {} })
    end
    KS.incompleteGroups = newIncomplete
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
