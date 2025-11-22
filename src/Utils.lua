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

-- Get addon memory usage in KB
function Utils.GetMemoryUsage()
    UpdateAddOnMemoryUsage()
    local memory = GetAddOnMemoryUsage("NordensParis")
    return memory
end

-- Format memory size for display
function Utils.FormatMemory(kb)
    if kb < 1024 then
        return string.format("%.1f KB", kb)
    else
        return string.format("%.2f MB", kb / 1024)
    end
end

-- Export the module
NordensParis_Utils = Utils
