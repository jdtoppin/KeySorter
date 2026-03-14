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
    for i, group in ipairs(KS.groups) do
        if group.locked then
            table.insert(lockedGroups, { index = i, group = group })
            if group.tank then lockedNames[group.tank.name] = true end
            if group.healer then lockedNames[group.healer.name] = true end
            for _, d in ipairs(group.dps) do
                lockedNames[d.name] = true
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

    -- Step 2: Sort each pool by score descending, then ilvl as tiebreaker
    local function byScore(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return (a.ilvl or 0) > (b.ilvl or 0)
    end
    table.sort(tanks, byScore)
    table.sort(healers, byScore)
    table.sort(dps, byScore)

    -- Step 3: Determine number of new groups from unlocked players
    local numNewGroups = math.floor(math.min(#tanks, #healers, #dps / 3))

    if numNewGroups == 0 and #lockedGroups == 0 then
        wipe(KS.groups)
        for _, t in ipairs(tanks) do table.insert(KS.unassigned, t) end
        for _, h in ipairs(healers) do table.insert(KS.unassigned, h) end
        for _, d in ipairs(dps) do table.insert(KS.unassigned, d) end
        print("|cff00ccffKeySorter|r: Not enough players to form a complete group.")
        if KS.UpdateGroupView then KS.UpdateGroupView() end
        return
    end

    -- Build new groups from unlocked players
    local newGroups = {}
    for i = 1, numNewGroups do
        newGroups[i] = { tank = nil, healer = nil, dps = {} }
    end

    -- Step 4: Skill-matched grouping
    for i = 1, numNewGroups do
        newGroups[i].tank = tanks[i]
        newGroups[i].healer = healers[i]
    end

    -- DPS: fill 3 per group first (core slots)
    local dpsNeeded = numNewGroups * 3
    local dpsToAssign = math.min(#dps, dpsNeeded)
    for i = 1, dpsToAssign do
        local groupIdx = math.ceil(i / 3)
        table.insert(newGroups[groupIdx].dps, dps[i])
    end

    -- Step 4b: Distribute extras across new groups
    local extras = {}
    for i = numNewGroups + 1, #tanks do
        table.insert(extras, tanks[i])
    end
    for i = numNewGroups + 1, #healers do
        table.insert(extras, healers[i])
    end
    for i = dpsToAssign + 1, #dps do
        table.insert(extras, dps[i])
    end

    table.sort(extras, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return (a.ilvl or 0) > (b.ilvl or 0)
    end)

    for _, extra in ipairs(extras) do
        table.insert(KS.unassigned, extra)
    end

    -- Merge: locked groups first (preserve their positions), then new groups
    wipe(KS.groups)
    -- Place locked groups back at their original indices
    for _, lg in ipairs(lockedGroups) do
        KS.groups[lg.index] = lg.group
    end
    -- Fill remaining slots with new groups
    local newIdx = 1
    for i = 1, #lockedGroups + numNewGroups do
        if not KS.groups[i] then
            if newIdx <= numNewGroups then
                KS.groups[i] = newGroups[newIdx]
                newIdx = newIdx + 1
            end
        end
    end

    -- Step 5: Utility balancing pass (only on unlocked groups)
    KS.BalanceUtilities()

    local numLocked = #lockedGroups
    local totalGroups = #KS.groups
    local lockMsg = numLocked > 0 and format(" (%d locked)", numLocked) or ""
    print(format("|cff00ccffKeySorter|r: Formed %d group(s)%s, %d unassigned.", totalGroups, lockMsg, #KS.unassigned))

    if KS.UpdateGroupView then KS.UpdateGroupView() end
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
