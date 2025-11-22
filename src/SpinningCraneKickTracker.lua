-- SpinningCraneKickTracker: SCK optimization tracker for Nordens Paris
-- Shows when 3+ injured targets are within 8 yards (optimal SCK usage)
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

-- Only load for Mistweaver monks
local _, class = UnitClass("player")
if class ~= "MONK" then return end

local SPINNING_CRANE_KICK_SPELL_ID = 101546 -- Spinning Crane Kick spell ID for MoP
local SCK_RANGE = 8 -- SCK has 8 yard radius

-- Frame variables
local sckFrame = nil
local sckIcon = nil
local sckCountText = nil
local sckStatusText = nil

-- Performance optimization: Cache for injured raid members
local injuredCache = {}
local cacheUpdateInterval = 0.5 -- Update cache every 0.5 seconds
local lastCacheUpdate = 0

-- Throttle for frame updates
local lastUpdate = 0
local updateInterval = 0.2

-- Helper function to calculate distance between two units
local function GetUnitDistance(unit1, unit2)
    local x1, y1 = UnitPosition(unit1)
    local x2, y2 = UnitPosition(unit2)

    if not x1 or not y1 or not x2 or not y2 then
        return nil
    end

    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Check if unit is injured (health < 100%)
local function IsUnitInjured(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) then
        return false
    end

    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)

    return health > 0 and health < maxHealth
end

-- Update the cache of injured raid members (performance optimization)
local function UpdateInjuredCache()
    local currentTime = GetTime()
    if currentTime - lastCacheUpdate < cacheUpdateInterval then
        return -- Use cached data
    end

    lastCacheUpdate = currentTime
    wipe(injuredCache)

    local unitPrefix, unitCount

    -- Determine if in raid or party
    if IsInRaid() then
        unitPrefix = "raid"
        unitCount = GetNumGroupMembers()
    elseif IsInGroup() then
        unitPrefix = "party"
        unitCount = GetNumSubgroupMembers()

        -- Check player first
        if IsUnitInjured("player") then
            table.insert(injuredCache, "player")
        end
    else
        -- Solo - only check player
        if IsUnitInjured("player") then
            table.insert(injuredCache, "player")
        end
        return
    end

    -- Only check injured players to reduce load
    for i = 1, unitCount do
        local unit = unitPrefix .. i
        if UnitExists(unit) and IsUnitInjured(unit) then
            table.insert(injuredCache, unit)
        end
    end
end

-- Count injured targets within SCK range
local function GetSCKTargetCount()
    UpdateInjuredCache()

    local count = 0

    -- Iterate only through injured players (optimization)
    for _, unit in ipairs(injuredCache) do
        if UnitExists(unit) then
            local distance = GetUnitDistance("player", unit)

            if distance and distance <= SCK_RANGE then
                count = count + 1
            end
        end
    end

    return count
end

-- Create SCK tracker frame
local function CreateSCKFrame(parentFrame, db)
    sckFrame = CreateFrame("Frame", "NordensParisSCKFrame", parentFrame)
    sckFrame:SetSize(200, 50)
    sckFrame:SetPoint("BOTTOM", parentFrame, "TOP", 0, 5)

    -- Create backdrop texture
    sckFrame.bg = sckFrame:CreateTexture(nil, "BACKGROUND")
    sckFrame.bg:SetAllPoints()
    sckFrame.bg:SetColorTexture(0, 0, 0, 0.8)

    -- SCK icon
    sckIcon = sckFrame:CreateTexture(nil, "ARTWORK")
    sckIcon:SetSize(32, 32)
    sckIcon:SetPoint("LEFT", 10, 0)
    sckIcon:SetTexture(GetSpellTexture(SPINNING_CRANE_KICK_SPELL_ID))

    -- Title text
    local titleText = sckFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 50, -8)
    titleText:SetText("Spinning Crane")
    titleText:SetTextColor(1, 0.8, 0.2)

    -- Count text (large, prominent)
    sckCountText = sckFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sckCountText:SetPoint("TOPLEFT", 50, -24)
    sckCountText:SetText("0 targets")
    sckCountText:SetTextColor(0.7, 0.7, 0.7)

    -- Status text (right side)
    sckStatusText = sckFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sckStatusText:SetPoint("RIGHT", -10, 0)
    sckStatusText:SetText("")
    sckStatusText:SetTextColor(1, 1, 1)

    if db.showSCK then
        sckFrame:Show()
    else
        sckFrame:Hide()
    end

    return sckFrame
end

-- Update SCK display
local function UpdateSCKDisplay(db)
    if not sckFrame or not db.showSCK then
        return
    end

    -- Throttle updates for performance
    local currentTime = GetTime()
    if currentTime - lastUpdate < updateInterval then
        return
    end
    lastUpdate = currentTime

    sckFrame:Show()

    local count = GetSCKTargetCount()

    -- Update count text
    if count >= 3 then
        sckCountText:SetText(count .. " targets")
        sckStatusText:SetText("USE!")

        -- Color coding based on target count
        if count >= 7 then
            -- Red for excellent (7+ targets)
            sckCountText:SetTextColor(1, 0.2, 0.2)
            sckFrame.bg:SetColorTexture(0.4, 0, 0, 0.8)

            -- Pulse effect for emphasis
            local alpha = 0.5 + 0.5 * math.abs(math.sin(currentTime * 4))
            sckIcon:SetAlpha(0.6 + alpha * 0.4)
        elseif count >= 5 then
            -- Yellow/Orange for very good (5-6 targets)
            sckCountText:SetTextColor(1, 0.8, 0)
            sckFrame.bg:SetColorTexture(0.3, 0.3, 0, 0.8)
            sckIcon:SetAlpha(1.0)
        else
            -- Green for good (3-4 targets)
            sckCountText:SetTextColor(0, 1, 0)
            sckFrame.bg:SetColorTexture(0, 0.3, 0, 0.8)
            sckIcon:SetAlpha(1.0)
        end
    else
        -- Not enough targets
        sckCountText:SetText(count .. " targets")
        sckCountText:SetTextColor(0.5, 0.5, 0.5)
        sckStatusText:SetText("")
        sckFrame.bg:SetColorTexture(0, 0, 0, 0.8)
        sckIcon:SetAlpha(0.5)
    end
end

-- Export functions
NordensParis_SCKTracker = {
    CreateSCKFrame = CreateSCKFrame,
    UpdateSCKDisplay = UpdateSCKDisplay,
    GetSCKTargetCount = GetSCKTargetCount
}
