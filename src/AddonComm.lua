-- AddonComm: Addon communication system for sharing plans and data
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

-- Communication prefix (must be unique and <= 16 characters)
local ADDON_PREFIX = "NordensParis"
local MESSAGE_VERSION = 1

-- Message types
local MSG_TYPE = {
    PLAN_SHARE = "PLAN",
    COOLDOWN_USED = "CD_USE",
    PLAN_REQUEST = "REQ_PLAN",
}

-- Serialization helpers
local function SerializeMessage(msgType, data)
    -- Simple serialization: "VERSION:TYPE:DATA"
    local serialized = MESSAGE_VERSION .. ":" .. msgType .. ":"

    if msgType == MSG_TYPE.PLAN_SHARE then
        -- Format: planName|step1>spell1,caster1|step2>spell2,caster2|...
        serialized = serialized .. data.planName .. "|"
        for i, step in ipairs(data.steps) do
            if i > 1 then
                serialized = serialized .. "|"
            end
            serialized = serialized .. step.order .. ">" .. step.spellName .. "," .. (step.caster or "Any")
        end
    elseif msgType == MSG_TYPE.COOLDOWN_USED then
        -- Format: spellId,spellName,casterName
        serialized = serialized .. data.spellId .. "," .. data.spellName .. "," .. data.casterName
    elseif msgType == MSG_TYPE.PLAN_REQUEST then
        -- No additional data needed
        serialized = serialized .. "REQUEST"
    end

    return serialized
end

local function DeserializeMessage(message)
    -- Parse "VERSION:TYPE:DATA"
    local version, msgType, data = string.match(message, "^(%d+):([^:]+):(.+)$")

    if not version or tonumber(version) ~= MESSAGE_VERSION then
        return nil -- Unknown version
    end

    local result = {
        type = msgType,
        data = {}
    }

    if msgType == MSG_TYPE.PLAN_SHARE then
        -- Parse: planName|step1>spell1,caster1|step2>spell2,caster2|...
        local parts = {}
        for part in string.gmatch(data, "[^|]+") do
            table.insert(parts, part)
        end

        if #parts > 0 then
            result.data.planName = parts[1]
            result.data.steps = {}

            for i = 2, #parts do
                local order, rest = string.match(parts[i], "^(%d+)>(.+)$")
                if order and rest then
                    local spellName, caster = string.match(rest, "^([^,]+),(.+)$")
                    if spellName then
                        table.insert(result.data.steps, {
                            order = tonumber(order),
                            spellName = spellName,
                            caster = caster ~= "Any" and caster or nil
                        })
                    end
                end
            end
        end
    elseif msgType == MSG_TYPE.COOLDOWN_USED then
        -- Parse: spellId,spellName,casterName
        local spellId, spellName, casterName = string.match(data, "^(%d+),([^,]+),(.+)$")
        if spellId and spellName and casterName then
            result.data.spellId = tonumber(spellId)
            result.data.spellName = spellName
            result.data.casterName = casterName
        end
    elseif msgType == MSG_TYPE.PLAN_REQUEST then
        -- No data to parse
        result.data.request = true
    end

    return result
end

-- Communication module
local AddonComm = {}
local receivedPlans = {} -- Store plans received from others
local callbacks = {} -- Callback registry

-- Initialize the communication system
function AddonComm.Initialize()
    -- Register our addon prefix
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

    -- Create event frame
    local commFrame = CreateFrame("Frame")
    commFrame:RegisterEvent("CHAT_MSG_ADDON")
    commFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
        if event == "CHAT_MSG_ADDON" and prefix == ADDON_PREFIX then
            AddonComm.OnMessageReceived(message, channel, sender)
        end
    end)

    print("|cff00ff80Nordens Paris:|r Addon communication initialized")
end

-- Handle received messages
function AddonComm.OnMessageReceived(message, channel, sender)
    local parsed = DeserializeMessage(message)

    if not parsed then
        return -- Invalid or unknown message format
    end

    -- Store sender with the data
    parsed.sender = sender
    parsed.channel = channel

    -- Handle different message types
    if parsed.type == MSG_TYPE.PLAN_SHARE then
        AddonComm.OnPlanReceived(parsed)
    elseif parsed.type == MSG_TYPE.COOLDOWN_USED then
        AddonComm.OnCooldownUsed(parsed)
    elseif parsed.type == MSG_TYPE.PLAN_REQUEST then
        AddonComm.OnPlanRequested(parsed)
    end

    -- Call any registered callbacks
    if callbacks[parsed.type] then
        for _, callback in ipairs(callbacks[parsed.type]) do
            callback(parsed)
        end
    end
end

-- Handle received plan
function AddonComm.OnPlanReceived(parsed)
    local planName = parsed.data.planName
    local sender = parsed.sender

    -- Store the received plan
    receivedPlans[sender] = receivedPlans[sender] or {}
    receivedPlans[sender][planName] = {
        planName = planName,
        steps = parsed.data.steps,
        sender = sender,
        timestamp = GetTime()
    }

    print("|cff00ff80Nordens Paris:|r Received cooldown plan '" .. planName .. "' from " .. sender)
    print("  Use /np viewplan to see received plans")
end

-- Handle cooldown used notification
function AddonComm.OnCooldownUsed(parsed)
    local data = parsed.data
    print("|cff00ff80Nordens Paris:|r " .. data.casterName .. " used " .. data.spellName)

    -- You could integrate this with the cooldown tracker here
    -- For now, just notify
end

-- Handle plan request
function AddonComm.OnPlanRequested(parsed)
    local sender = parsed.sender
    print("|cff00ff80Nordens Paris:|r " .. sender .. " requested your cooldown plan")
    -- Auto-send current plan if one is active
    -- This can be implemented when we have plan storage
end

-- Send a plan to the group
function AddonComm.SharePlan(plan, channel)
    channel = channel or "RAID"

    -- Fallback to PARTY if not in raid
    if channel == "RAID" and not IsInRaid() then
        channel = "PARTY"
    end

    -- Don't send if not in a group
    if channel == "PARTY" and not IsInGroup() then
        print("|cff00ff80Nordens Paris:|r You must be in a group to share plans")
        return false
    end

    local message = SerializeMessage(MSG_TYPE.PLAN_SHARE, plan)
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel)

    print("|cff00ff80Nordens Paris:|r Shared plan '" .. plan.planName .. "' to " .. string.lower(channel))
    return true
end

-- Notify group when you use a cooldown
function AddonComm.NotifyCooldownUsed(spellId, spellName, casterName)
    local channel = IsInRaid() and "RAID" or "PARTY"

    if not IsInGroup() and not IsInRaid() then
        return -- Don't send if not in a group
    end

    local data = {
        spellId = spellId,
        spellName = spellName,
        casterName = casterName
    }

    local message = SerializeMessage(MSG_TYPE.COOLDOWN_USED, data)
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel)
end

-- Request plans from the group
function AddonComm.RequestPlans()
    local channel = IsInRaid() and "RAID" or "PARTY"

    if not IsInGroup() and not IsInRaid() then
        print("|cff00ff80Nordens Paris:|r You must be in a group to request plans")
        return false
    end

    local message = SerializeMessage(MSG_TYPE.PLAN_REQUEST, {})
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel)

    print("|cff00ff80Nordens Paris:|r Requested cooldown plans from group")
    return true
end

-- Get all received plans
function AddonComm.GetReceivedPlans()
    return receivedPlans
end

-- Register a callback for a specific message type
function AddonComm.RegisterCallback(msgType, callback)
    callbacks[msgType] = callbacks[msgType] or {}
    table.insert(callbacks[msgType], callback)
end

-- Export the module
NordensParis_AddonComm = AddonComm
