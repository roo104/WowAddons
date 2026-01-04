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
    local _, class = UnitClass("player")
    if class ~= "MONK" then
        return false
    end

    -- In Classic, check if GetSpecialization exists (retail API)
    if GetSpecialization then
        local spec = GetSpecialization()
        return spec == 2 -- 2 = Mistweaver
    end

    -- For Classic without spec system, always return true for monks
    -- (or you can add talent-based detection if needed)
    return true
end

-- Export the module
NordensParis_Utils = Utils
