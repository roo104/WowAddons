-- RenewingMistTracker: Renewing Mist tracking module for RooMonk
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

local RENEWING_MIST_SPELL_ID = 119611 -- Renewing Mist spell ID for MoP
local UPLIFT_SPELL_ID = 116670 -- Uplift spell ID for MoP

-- Frame variables
local frame = nil
local countText = nil
local upliftText = nil
local listFrame = nil

-- Check if a unit has Renewing Mist buff
local function HasRenewingMist(unit)
    if not UnitExists(unit) then return false, 0 end

    -- Check all buffs on the unit
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
        if not name then break end

        if spellId == RENEWING_MIST_SPELL_ID then
            local _, _, _, _, _, expirationTime = UnitBuff(unit, i)
            local timeRemaining = expirationTime and (expirationTime - GetTime()) or 0
            return true, timeRemaining
        end
    end

    return false, 0
end

-- Get all party/raid members with Renewing Mist
local function GetRenewingMistTargets()
    local targets = {}
    local totalMembers = 0
    local unitPrefix, unitCount

    -- Determine if in raid or party
    if IsInRaid() then
        unitPrefix = "raid"
        unitCount = GetNumGroupMembers()
        totalMembers = unitCount
    elseif IsInGroup() then
        unitPrefix = "party"
        unitCount = GetNumSubgroupMembers()

        -- Check player too
        local hasIt, timeLeft = HasRenewingMist("player")
        if hasIt then
            local playerName = UnitName("player")
            table.insert(targets, {name = playerName, timeLeft = timeLeft})
        end
        totalMembers = unitCount + 1
    else
        -- Solo - only check player
        totalMembers = 1
        local hasIt, timeLeft = HasRenewingMist("player")
        if hasIt then
            local playerName = UnitName("player")
            table.insert(targets, {name = playerName, timeLeft = timeLeft})
        end
        return targets, totalMembers
    end

    -- Check all group members
    for i = 1, unitCount do
        local unit = unitPrefix .. i
        if UnitExists(unit) then
            local hasIt, timeLeft = HasRenewingMist(unit)
            if hasIt then
                local name = UnitName(unit)
                table.insert(targets, {name = name, timeLeft = timeLeft})
            end
        end
    end

    -- Sort by time remaining (descending)
    table.sort(targets, function(a, b)
        return a.timeLeft > b.timeLeft
    end)

    return targets, totalMembers
end

-- Create a frame to list players with Renewing Mist
local function CreateListFrame(parentFrame, db)
    listFrame = CreateFrame("Frame", "RooMonkListFrame", parentFrame)
    listFrame:SetSize(180, 200)
    listFrame:SetPoint("TOP", parentFrame, "BOTTOM", 0, -5)

    -- Create backdrop texture
    local bg = listFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)

    listFrame.fontStrings = {}

    -- Create font strings for player names
    for i = 1, 10 do
        local fs = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 15, -10 - (i - 1) * 18)
        fs:SetJustifyH("LEFT")
        fs:SetTextColor(1, 1, 1)
        listFrame.fontStrings[i] = fs
    end

    if db.showList then
        listFrame:Show()
    else
        listFrame:Hide()
    end

    return listFrame
end

-- Initialize the main frame
local function CreateRenewingMistFrame(parentFrame, db)
    frame = parentFrame

    frame:SetSize(200, 80)

    -- Create backdrop texture
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    frame.bg = bg

    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture(GetSpellTexture(RENEWING_MIST_SPELL_ID))

    -- Title text
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 50, -10)
    titleText:SetText("Renewing Mist")
    titleText:SetTextColor(0, 1, 0.5)

    -- Count text
    countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countText:SetPoint("TOPLEFT", 50, -28)
    countText:SetText("0/0")
    countText:SetTextColor(1, 1, 1)

    -- Uplift info text
    upliftText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    upliftText:SetPoint("TOPLEFT", 50, -50)
    upliftText:SetText("Uplift: 0 targets")
    upliftText:SetTextColor(0.7, 0.7, 0.7)

    -- Create list frame
    listFrame = CreateListFrame(frame, db)

    return frame
end

-- Update the display
local function UpdateDisplay(db)
    -- Don't update if frame isn't initialized yet
    if not countText then
        return
    end
    local targets, totalMembers = GetRenewingMistTargets()
    local count = #targets

    -- Update count text
    countText:SetText(count .. "/" .. totalMembers)

    -- Color code based on coverage
    if totalMembers == 0 then
        countText:SetTextColor(1, 1, 1)
    elseif count == 0 then
        countText:SetTextColor(0.5, 0.5, 0.5)
    elseif count / totalMembers >= 0.7 then
        countText:SetTextColor(0, 1, 0)
    elseif count / totalMembers >= 0.4 then
        countText:SetTextColor(1, 1, 0)
    else
        countText:SetTextColor(1, 0.5, 0)
    end

    -- Update Uplift info
    if upliftText then
        upliftText:SetText("Uplift: " .. count .. " targets")

        -- Highlight when 3+ targets (optimal Uplift time)
        if count >= 3 then
            upliftText:SetTextColor(0, 1, 0)  -- Green for optimal
            -- Flash effect for emphasis
            local alpha = 0.5 + 0.5 * math.abs(math.sin(GetTime() * 3))
            frame.bg = frame.bg or frame:CreateTexture(nil, "BACKGROUND")
            frame.bg:SetColorTexture(0, 0.3, 0, alpha * 0.3)
        else
            upliftText:SetTextColor(0.7, 0.7, 0.7)  -- Gray for suboptimal
            if frame.bg then
                frame.bg:SetColorTexture(0, 0, 0, 0.8)  -- Reset to default
            end
        end
    end

    -- Update list
    if listFrame and listFrame.fontStrings and db.showList then
        for i = 1, 10 do
            if listFrame.fontStrings[i] then
                if targets[i] then
                    local timeStr = string.format("%.1fs", targets[i].timeLeft)
                    listFrame.fontStrings[i]:SetText(targets[i].name .. " - " .. timeStr)

                    -- Color based on time remaining
                    if targets[i].timeLeft <= 3 then
                        listFrame.fontStrings[i]:SetTextColor(1, 0, 0)
                    elseif targets[i].timeLeft > 10 then
                        listFrame.fontStrings[i]:SetTextColor(0, 1, 0)
                    elseif targets[i].timeLeft > 5 then
                        listFrame.fontStrings[i]:SetTextColor(1, 1, 0)
                    else
                        listFrame.fontStrings[i]:SetTextColor(1, 0.5, 0)
                    end
                else
                    listFrame.fontStrings[i]:SetText("")
                end
            end
        end

        -- Adjust list frame height based on number of targets
        local height = math.max(40, math.min(count, 10) * 18 + 20)
        listFrame:SetHeight(height)
    end
end

-- Get list frame reference
local function GetListFrame()
    return listFrame
end

-- Export functions
RooMonk_RenewingMistTracker = {
    CreateRenewingMistFrame = CreateRenewingMistFrame,
    UpdateDisplay = UpdateDisplay,
    GetListFrame = GetListFrame,
    GetRenewingMistTargets = GetRenewingMistTargets
}
