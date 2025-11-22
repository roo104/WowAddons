-- RenewingMistTracker: Renewing Mist tracking module for Nordens Paris
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

-- Only load for Mistweaver monks
local _, class = UnitClass("player")
if class ~= "MONK" then return end

local RENEWING_MIST_SPELL_ID = 119611 -- Renewing Mist spell ID for MoP
local UPLIFT_SPELL_ID = 116670 -- Uplift spell ID for MoP

-- Frame variables
local frame = nil
local upliftText = nil

-- Check if a unit has Renewing Mist buff
local function HasRenewingMist(unit)
    if not UnitExists(unit) then return false, 0 end

    -- Check all buffs on the unit
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime, _, _, _, spellId = UnitBuff(unit, i)
        if not name then break end

        if spellId == RENEWING_MIST_SPELL_ID then
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

-- Initialize the main frame
local function CreateRenewingMistFrame(parentFrame, db)
    frame = parentFrame

    frame:SetSize(200, 50)

    -- Create backdrop texture
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    frame.bg = bg

    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", 10, -10)
    icon:SetTexture(GetSpellTexture(RENEWING_MIST_SPELL_ID))

    -- Title text (headline at top)
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 50, -8)
    titleText:SetText("Renewing Mist")
    titleText:SetTextColor(1, 0.8, 0.2)

    -- Uplift info text (aligned with icon)
    upliftText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    upliftText:SetPoint("LEFT", icon, "RIGHT", 8, -5)
    upliftText:SetText("0 targets")
    upliftText:SetTextColor(0.7, 0.7, 0.7)

    -- Create list items with progress bars (integrated into main frame)
    frame.listFontStrings = {}
    frame.listBars = {}
    for i = 1, 10 do
        -- Create bar background
        local barBg = frame:CreateTexture(nil, "BACKGROUND")
        barBg:SetSize(180, 16)
        barBg:SetPoint("TOPLEFT", 10, -70 - (i - 1) * 18)
        barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

        -- Create progress bar
        local bar = frame:CreateTexture(nil, "ARTWORK")
        bar:SetSize(180, 16)
        bar:SetPoint("TOPLEFT", 10, -70 - (i - 1) * 18)
        bar:SetColorTexture(0, 1, 0, 0.5)
        frame.listBars[i] = {bg = barBg, progress = bar}

        -- Create text overlay
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", barBg, "LEFT", 5, 0)
        fs:SetJustifyH("LEFT")
        fs:SetTextColor(1, 1, 1)
        frame.listFontStrings[i] = fs
    end

    return frame
end

-- Update the display
local function UpdateDisplay(db)
    -- Don't update if frame isn't initialized yet
    if not upliftText then
        return
    end
    local targets, totalMembers = GetRenewingMistTargets()
    local count = #targets

    -- Update Uplift info
    if upliftText then
        upliftText:SetText(count .. " targets")

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

    -- Update integrated list
    if frame and frame.listFontStrings and frame.listBars and db.showRenewingMist then
        local maxDuration = 18 -- Renewing Mist duration in MoP
        for i = 1, 10 do
            if frame.listFontStrings[i] and frame.listBars[i] then
                if targets[i] then
                    local timeStr = string.format("%.1fs", targets[i].timeLeft)
                    frame.listFontStrings[i]:SetText(targets[i].name .. " - " .. timeStr)

                    -- Show bars
                    frame.listBars[i].bg:Show()
                    frame.listBars[i].progress:Show()

                    -- Update progress bar width based on time remaining
                    local progress = math.max(0, math.min(1, targets[i].timeLeft / maxDuration))
                    frame.listBars[i].progress:SetWidth(180 * progress)

                    -- Color bar based on time remaining
                    if targets[i].timeLeft <= 3 then
                        frame.listBars[i].progress:SetColorTexture(1, 0, 0, 0.6)
                        frame.listFontStrings[i]:SetTextColor(1, 1, 1)
                    elseif targets[i].timeLeft > 10 then
                        frame.listBars[i].progress:SetColorTexture(0, 1, 0, 0.6)
                        frame.listFontStrings[i]:SetTextColor(1, 1, 1)
                    elseif targets[i].timeLeft > 5 then
                        frame.listBars[i].progress:SetColorTexture(1, 1, 0, 0.6)
                        frame.listFontStrings[i]:SetTextColor(1, 1, 1)
                    else
                        frame.listBars[i].progress:SetColorTexture(1, 0.5, 0, 0.6)
                        frame.listFontStrings[i]:SetTextColor(1, 1, 1)
                    end
                else
                    frame.listFontStrings[i]:SetText("")
                    frame.listBars[i].bg:Hide()
                    frame.listBars[i].progress:Hide()
                end
            end
        end

        -- Adjust main frame height based on number of targets
        local baseHeight = 80
        local listHeight = math.min(count, 10) * 18
        frame:SetHeight(baseHeight + listHeight)
    else
        -- Hide list entries when not showing
        if frame and frame.listFontStrings and frame.listBars then
            for i = 1, 10 do
                if frame.listFontStrings[i] then
                    frame.listFontStrings[i]:SetText("")
                end
                if frame.listBars[i] then
                    frame.listBars[i].bg:Hide()
                    frame.listBars[i].progress:Hide()
                end
            end
        end
        -- Reset to base height
        if frame then
            frame:SetHeight(80)
        end
    end
end

-- Export functions
NordensParis_RenewingMistTracker = {
    CreateRenewingMistFrame = CreateRenewingMistFrame,
    UpdateDisplay = UpdateDisplay,
    GetRenewingMistTargets = GetRenewingMistTargets
}
