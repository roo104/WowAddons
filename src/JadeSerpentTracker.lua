-- JadeSerpentTracker: Jade Serpent Statue tracking module for Nordens Paris
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

-- Only load for Mistweaver monks
local _, class = UnitClass("player")
if class ~= "MONK" then return end

local JADE_SERPENT_STATUE_SPELL_ID = 115313 -- Summon Jade Serpent Statue spell ID

-- Frame variables
local statueFrame = nil
local statueIcon = nil
local statueDurationText = nil
local statueRangeText = nil

-- Create a frame to show Jade Serpent Statue status
local function CreateStatueFrame(parentFrame, db, anchorFrame)
    statueFrame = CreateFrame("Frame", "NordensParisStatueFrame", parentFrame)
    statueFrame:SetSize(200, 50)

    -- Anchor above SCK frame if available, otherwise to parent frame
    if anchorFrame then
        statueFrame:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 5)
    else
        statueFrame:SetPoint("BOTTOM", parentFrame, "TOP", 0, 5)
    end

    -- Create backdrop texture
    statueFrame.bg = statueFrame:CreateTexture(nil, "BACKGROUND")
    statueFrame.bg:SetAllPoints()
    statueFrame.bg:SetColorTexture(0, 0.3, 0.3, 0.8)

    -- Statue icon
    statueIcon = statueFrame:CreateTexture(nil, "ARTWORK")
    statueIcon:SetSize(32, 32)
    statueIcon:SetPoint("LEFT", 10, 0)
    statueIcon:SetTexture(GetSpellTexture(JADE_SERPENT_STATUE_SPELL_ID))

    -- Title text
    local titleText = statueFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 50, -8)
    titleText:SetText("Jade Serpent")
    titleText:SetTextColor(0, 1, 0.8)

    -- Duration text
    statueDurationText = statueFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statueDurationText:SetPoint("TOPLEFT", 50, -24)
    statueDurationText:SetText("Not Active")
    statueDurationText:SetTextColor(0.5, 0.5, 0.5)

    -- Range text
    statueRangeText = statueFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statueRangeText:SetPoint("RIGHT", -10, 0)
    statueRangeText:SetText("")
    statueRangeText:SetTextColor(1, 1, 1)

    if db.showStatue then
        statueFrame:Show()
    else
        statueFrame:Hide()
    end

    return statueFrame
end

-- Check if Jade Serpent Statue is active
local function GetStatueInfo()
    -- Check for the statue totem/pet
    -- In MoP, the statue appears as a totem
    for i = 1, 4 do
        local haveTotem, name, startTime, duration, icon = GetTotemInfo(i)
        if haveTotem and icon == GetSpellTexture(JADE_SERPENT_STATUE_SPELL_ID) then
            local timeRemaining = (startTime + duration) - GetTime()
            return true, timeRemaining, duration
        end
    end

    return false, 0, 0
end

-- Get statue range category using spell range checking
-- Returns: "close" (< 30 yards), "medium" (30-40 yards), "far" (> 40 yards), or nil if no statue
local function GetStatueRangeCategory()
    -- First check if statue exists
    local statueExists = false
    for i = 1, 4 do
        local haveTotem, name, startTime, duration = GetTotemInfo(i)
        if haveTotem and GetSpellTexture(JADE_SERPENT_STATUE_SPELL_ID) then
            statueExists = true
            break
        end
    end

    if not statueExists then
        return nil
    end

    -- Use spell range checking to determine approximate distance
    -- We'll use common monk spells with known ranges
    -- Renewing Mist: 40 yards
    -- Tiger Palm: 5 yards (melee)
    -- Crackling Jade Lightning: 40 yards

    -- Check if we have a 40-yard range spell available
    local RENEWING_MIST_SPELL_ID = 119611
    local inRange40 = IsSpellInRange(GetSpellInfo(RENEWING_MIST_SPELL_ID), "player")

    -- Since we can't directly check 30 yards with available APIs in Classic MoP,
    -- we'll use CheckInteractDistance as a proxy
    -- distIndex 4 (Follow) is approximately 28 yards
    local inRange28 = CheckInteractDistance("player", 4)

    -- Determine range category
    -- Note: This is an approximation since we can't get exact distance in Classic MoP
    if inRange28 then
        -- Within approximately 28 yards - definitely in good range
        return "close"
    elseif inRange40 == 1 then
        -- Beyond 28 yards but within 40 yards
        return "medium"
    else
        -- Beyond 40 yards
        return "far"
    end
end

-- Update statue display
local function UpdateStatueDisplay(db)
    if not statueFrame or not db.showStatue then
        return
    end

    local isActive, timeRemaining, duration = GetStatueInfo()

    statueFrame:Show()

    if isActive then
        local minutes = math.floor(timeRemaining / 60)
        local seconds = timeRemaining % 60

        if minutes > 0 then
            statueDurationText:SetText(string.format("%dm %.0fs", minutes, seconds))
        else
            statueDurationText:SetText(string.format("%.1fs", timeRemaining))
        end

        -- Color based on time remaining
        if timeRemaining > 60 then
            statueDurationText:SetTextColor(0, 1, 0)
        elseif timeRemaining > 30 then
            statueDurationText:SetTextColor(1, 1, 0)
        else
            statueDurationText:SetTextColor(1, 0.5, 0)
        end

        -- Clear range text
        statueRangeText:SetText("")

        -- Active background
        statueFrame.bg:SetColorTexture(0, 0.3, 0.3, 0.8)
        statueIcon:SetAlpha(1.0)
    else
        -- Statue not active
        statueDurationText:SetText("Not Summoned")
        statueDurationText:SetTextColor(0.5, 0.5, 0.5)
        statueRangeText:SetText("")

        -- Dimmed background
        statueFrame.bg:SetColorTexture(0, 0.15, 0.15, 0.8)
        statueIcon:SetAlpha(0.4)
    end
end

-- Export functions
NordensParis_JadeSerpentTracker = {
    CreateStatueFrame = CreateStatueFrame,
    UpdateStatueDisplay = UpdateStatueDisplay,
    GetStatueInfo = GetStatueInfo,
    GetStatueRangeCategory = GetStatueRangeCategory
}
