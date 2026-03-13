local addonName, KS = ...

function KS.SortGroups()
    wipe(KS.groups)
    wipe(KS.unassigned)

    if #KS.roster == 0 then
        print("|cff00ccffKeySorter|r: No roster data. Scan first.")
        return
    end

    -- Step 1: Separate by role
    local tanks, healers, dps = {}, {}, {}
    for _, member in ipairs(KS.roster) do
        if member.role == "TANK" then
            table.insert(tanks, member)
        elseif member.role == "HEALER" then
            table.insert(healers, member)
        else
            table.insert(dps, member)
        end
    end

    -- Step 2: Sort each pool by score descending
    local function byScore(a, b) return a.score > b.score end
    table.sort(tanks, byScore)
    table.sort(healers, byScore)
    table.sort(dps, byScore)

    -- Step 3: Determine number of groups (limited by scarcest role)
    local numGroups = math.floor(math.min(#tanks, #healers, #dps / 3))
    if numGroups == 0 then
        for _, t in ipairs(tanks) do table.insert(KS.unassigned, t) end
        for _, h in ipairs(healers) do table.insert(KS.unassigned, h) end
        for _, d in ipairs(dps) do table.insert(KS.unassigned, d) end
        print("|cff00ccffKeySorter|r: Not enough players to form a complete group.")
        if KS.UpdateGroupView then KS.UpdateGroupView() end
        return
    end

    -- Initialize groups
    for i = 1, numGroups do
        KS.groups[i] = { tank = nil, healer = nil, dps = {} }
    end

    -- Step 4: Skill-matched grouping
    -- Assign the best tank + healer + top 3 DPS together (group 1 = highest skill),
    -- next best together (group 2), etc. Players of similar score stay together.
    for i = 1, numGroups do
        KS.groups[i].tank = tanks[i]
        KS.groups[i].healer = healers[i]
    end

    -- DPS: sequential fill (top 3 DPS → group 1, next 3 → group 2, etc.)
    local dpsNeeded = numGroups * 3
    local dpsToAssign = math.min(#dps, dpsNeeded)
    for i = 1, dpsToAssign do
        local groupIdx = math.ceil(i / 3)
        table.insert(KS.groups[groupIdx].dps, dps[i])
    end

    -- Leftover tanks/healers/DPS
    for i = numGroups + 1, #tanks do
        table.insert(KS.unassigned, tanks[i])
    end
    for i = numGroups + 1, #healers do
        table.insert(KS.unassigned, healers[i])
    end
    for i = dpsToAssign + 1, #dps do
        table.insert(KS.unassigned, dps[i])
    end

    -- Step 5: Utility balancing pass (swap DPS between groups to cover BR/BL)
    -- Only swap within similar score tiers to preserve skill grouping
    KS.BalanceUtilities()

    print(format("|cff00ccffKeySorter|r: Formed %d group(s), %d unassigned.", numGroups, #KS.unassigned))

    if KS.UpdateGroupView then KS.UpdateGroupView() end
end

---------------------------------------------------------------------------
-- Utility balancing: try to give each group brez and lust coverage
-- by swapping DPS between groups, preferring swaps between adjacent
-- groups (similar skill tiers) to minimize skill disruption
---------------------------------------------------------------------------
function KS.BalanceUtilities()
    local numGroups = #KS.groups
    if numGroups < 2 then return end

    for i = 1, numGroups do
        local group = KS.groups[i]
        if not KS.GroupHasUtility(group, "hasBrez") then
            KS.TrySwapForUtility(i, "hasBrez")
        end
        if not KS.GroupHasUtility(group, "hasLust") then
            KS.TrySwapForUtility(i, "hasLust")
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
-- (closer in skill tier) over distant ones
function KS.TrySwapForUtility(needGroupIdx, utilKey)
    local needGroup = KS.groups[needGroupIdx]
    local bestSwap = nil
    local bestPriority = math.huge -- lower = better (distance + score diff)

    for otherIdx = 1, #KS.groups do
        if otherIdx ~= needGroupIdx then
            local otherGroup = KS.groups[otherIdx]
            -- Prefer swapping with adjacent groups (similar skill tier)
            local groupDistance = math.abs(otherIdx - needGroupIdx)

            for ni, needDPS in ipairs(needGroup.dps) do
                if not needDPS[utilKey] then
                    for oi, otherDPS in ipairs(otherGroup.dps) do
                        if otherDPS[utilKey] then
                            -- Check if the other group retains the utility after swap
                            local otherStillHas = false
                            if otherGroup.tank and otherGroup.tank[utilKey] then otherStillHas = true end
                            if otherGroup.healer and otherGroup.healer[utilKey] then otherStillHas = true end
                            for k, d in ipairs(otherGroup.dps) do
                                if k ~= oi and d[utilKey] then otherStillHas = true end
                            end

                            if otherStillHas then
                                -- Priority: prefer adjacent groups, then minimize score disruption
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

    -- Only swap if score disruption is reasonable
    if bestSwap then
        local needDPS = KS.groups[bestSwap.needGroupIdx].dps[bestSwap.needDPSIdx]
        local otherDPS = KS.groups[bestSwap.otherGroupIdx].dps[bestSwap.otherDPSIdx]
        local scoreDiff = math.abs(needDPS.score - otherDPS.score)

        -- Allow wider threshold for adjacent groups, tighter for distant
        local groupDist = math.abs(bestSwap.needGroupIdx - bestSwap.otherGroupIdx)
        local threshold = groupDist <= 1 and (KS.SWAP_THRESHOLD * 3) or KS.SWAP_THRESHOLD

        if scoreDiff <= threshold then
            KS.groups[bestSwap.needGroupIdx].dps[bestSwap.needDPSIdx] = otherDPS
            KS.groups[bestSwap.otherGroupIdx].dps[bestSwap.otherDPSIdx] = needDPS
        end
    end
end
