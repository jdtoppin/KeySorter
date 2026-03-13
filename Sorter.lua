local addonName, KS = ...

function KS.SortGroups()
    wipe(KS.groups)
    wipe(KS.unassigned)

    if #KS.roster == 0 then
        print("|cff00ccffKeySorter|r: No roster data. Scan first.")
        return
    end

    -- Separate by role
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

    -- Sort each pool by score descending
    local function byScore(a, b) return a.score > b.score end
    table.sort(tanks, byScore)
    table.sort(healers, byScore)
    table.sort(dps, byScore)

    -- Determine number of groups
    local numGroups = math.floor(math.min(#tanks, #healers, #dps / 3))
    if numGroups == 0 then
        -- Can't form any complete groups
        for _, t in ipairs(tanks) do table.insert(KS.unassigned, t) end
        for _, h in ipairs(healers) do table.insert(KS.unassigned, h) end
        for _, d in ipairs(dps) do table.insert(KS.unassigned, d) end
        print("|cff00ccffKeySorter|r: Not enough players to form a complete group.")
        if KS.UpdateGroupView then KS.UpdateGroupView() end
        return
    end

    -- Initialize groups
    for i = 1, numGroups do
        KS.groups[i] = {
            tank = nil,
            healer = nil,
            dps = {},
        }
    end

    -- Assign tanks and healers (highest score to group 1, etc.)
    for i = 1, numGroups do
        KS.groups[i].tank = tanks[i]
        KS.groups[i].healer = healers[i]
    end

    -- Leftover tanks/healers
    for i = numGroups + 1, #tanks do
        table.insert(KS.unassigned, tanks[i])
    end
    for i = numGroups + 1, #healers do
        table.insert(KS.unassigned, healers[i])
    end

    -- Snake draft for DPS
    local dpsNeeded = numGroups * 3
    local dpsToAssign = math.min(#dps, dpsNeeded)
    local groupIdx = 1
    local direction = 1 -- 1 = forward, -1 = backward

    for i = 1, dpsToAssign do
        table.insert(KS.groups[groupIdx].dps, dps[i])
        -- Snake: forward then backward
        if direction == 1 then
            if groupIdx == numGroups then
                direction = -1
            else
                groupIdx = groupIdx + 1
            end
        else
            if groupIdx == 1 then
                direction = 1
            else
                groupIdx = groupIdx - 1
            end
        end
    end

    -- Leftover DPS
    for i = dpsToAssign + 1, #dps do
        table.insert(KS.unassigned, dps[i])
    end

    -- Utility balancing pass
    KS.BalanceUtilities()

    print(format("|cff00ccffKeySorter|r: Formed %d group(s), %d unassigned.", numGroups, #KS.unassigned))

    if KS.UpdateGroupView then KS.UpdateGroupView() end
end

function KS.BalanceUtilities()
    local numGroups = #KS.groups
    if numGroups < 2 then return end

    -- Check each group for brez and lust
    for i = 1, numGroups do
        local group = KS.groups[i]
        local hasBrez = KS.GroupHasUtility(group, "hasBrez")
        local hasLust = KS.GroupHasUtility(group, "hasLust")

        if not hasBrez then
            KS.TrySwapForUtility(i, "hasBrez")
        end
        if not hasLust then
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

function KS.TrySwapForUtility(needGroupIdx, utilKey)
    local needGroup = KS.groups[needGroupIdx]
    local bestSwap = nil
    local bestImbalance = math.huge

    for otherIdx = 1, #KS.groups do
        if otherIdx ~= needGroupIdx then
            local otherGroup = KS.groups[otherIdx]
            -- Only consider swapping DPS
            for ni, needDPS in ipairs(needGroup.dps) do
                if not needDPS[utilKey] then
                    for oi, otherDPS in ipairs(otherGroup.dps) do
                        if otherDPS[utilKey] then
                            -- Check if the other group still has the utility after swap
                            local otherStillHas = false
                            if otherGroup.tank and otherGroup.tank[utilKey] then otherStillHas = true end
                            if otherGroup.healer and otherGroup.healer[utilKey] then otherStillHas = true end
                            for k, d in ipairs(otherGroup.dps) do
                                if k ~= oi and d[utilKey] then otherStillHas = true end
                            end

                            if otherStillHas or true then -- swap even if other loses it (net gain if they have redundancy)
                                local scoreDiff = math.abs(needDPS.score - otherDPS.score)
                                if scoreDiff < bestImbalance then
                                    bestImbalance = scoreDiff
                                    bestSwap = { needGroupIdx = needGroupIdx, needDPSIdx = ni,
                                                 otherGroupIdx = otherIdx, otherDPSIdx = oi,
                                                 otherStillHas = otherStillHas }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Only swap if imbalance is within threshold and the other group retains the utility
    if bestSwap and bestImbalance <= KS.SWAP_THRESHOLD and bestSwap.otherStillHas then
        local temp = KS.groups[bestSwap.needGroupIdx].dps[bestSwap.needDPSIdx]
        KS.groups[bestSwap.needGroupIdx].dps[bestSwap.needDPSIdx] = KS.groups[bestSwap.otherGroupIdx].dps[bestSwap.otherDPSIdx]
        KS.groups[bestSwap.otherGroupIdx].dps[bestSwap.otherDPSIdx] = temp
    end
end
