-- Utils: Utility functions for Nordens Paris addon
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

local Utils = {}

-- Get list of group members (player, party, raid) plus "Anyone" option
function Utils.GetGroupMembers()
    local members = {"Anyone"}

    -- Add player
    local playerName = UnitName("player")
    if playerName then
        table.insert(members, playerName)
    end

    -- Check if in raid
    if IsInRaid() then
        -- Add raid members
        for i = 1, GetNumGroupMembers() do
            local name = UnitName("raid"..i)
            if name and name ~= playerName then
                table.insert(members, name)
            end
        end
    elseif IsInGroup() then
        -- Add party members
        for i = 1, GetNumSubgroupMembers() do
            local name = UnitName("party"..i)
            if name then
                table.insert(members, name)
            end
        end
    end

    return members
end

-- Check if player is Mistweaver monk
function Utils.IsMistweaver()
    local spec = GetSpecialization()
    return spec == 2 -- 2 = Mistweaver in MoP
end

-- Export the module
NordensParis_Utils = Utils
