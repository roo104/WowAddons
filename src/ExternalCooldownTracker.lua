-- ExternalCooldownTracker: Track major healing cooldowns from other healers
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

-- Major healing cooldowns to track (MoP spell IDs)
-- duration = buff/channel duration, cooldownDuration = actual cooldown time
local TRACKED_COOLDOWNS = {
    -- Druid (Restoration)
    {spellId = 740, name = "Tranquility", duration = 8, cooldownDuration = 180, class = "DRUID", trackType = "cast"},
    {spellId = 106898, name = "Stampeding Roar", duration = 8, cooldownDuration = 120, class = "DRUID", trackType = "cast"},
    {spellId = 102342, name = "Ironbark", duration = 12, cooldownDuration = 60, class = "DRUID", trackType = "buff"},

    -- Paladin (Holy)
    {spellId = 31821, name = "Devotion Aura", duration = 6, cooldownDuration = 180, class = "PALADIN", trackType = "buff"},
    {spellId = 6940, name = "Hand of Sacrifice", duration = 12, cooldownDuration = 120, class = "PALADIN", trackType = "buff"},
    {spellId = 1022, name = "Hand of Protection", duration = 10, cooldownDuration = 300, class = "PALADIN", trackType = "buff"},

    -- Priest (Holy/Disc)
    {spellId = 62618, name = "Power Word: Barrier", duration = 10, cooldownDuration = 180, class = "PRIEST", trackType = "cast"},
    {spellId = 64843, name = "Divine Hymn", duration = 8, cooldownDuration = 180, class = "PRIEST", trackType = "cast"},
    {spellId = 47788, name = "Guardian Spirit", duration = 10, cooldownDuration = 180, class = "PRIEST", trackType = "buff"},
    {spellId = 33206, name = "Pain Suppression", duration = 8, cooldownDuration = 180, class = "PRIEST", trackType = "buff"},

    -- Shaman (Restoration)
    {spellId = 108280, name = "Healing Tide Totem", duration = 10, cooldownDuration = 180, class = "SHAMAN", trackType = "cast"},
    {spellId = 98008, name = "Spirit Link Totem", duration = 6, cooldownDuration = 180, class = "SHAMAN", trackType = "cast"},
    {spellId = 16190, name = "Mana Tide Totem", duration = 16, cooldownDuration = 180, class = "SHAMAN", trackType = "cast"},

    -- Monk (Mistweaver)
    {spellId = 115310, name = "Revival", duration = 180, cooldownDuration = 180, class = "MONK", trackType = "cast"},
    {spellId = 116849, name = "Life Cocoon", duration = 12, cooldownDuration = 120, class = "MONK", trackType = "buff"},
}

-- DPS raid buffs to track (MoP spell IDs)
local TRACKED_DPS_BUFFS = {
    -- Shaman
    {spellId = 120668, name = "Stormlash Totem", duration = 10, cooldownDuration = 300, class = "SHAMAN", trackType = "buff"},

    -- Warrior
    {spellId = 114207, name = "Skull Banner", duration = 10, cooldownDuration = 180, class = "WARRIOR", trackType = "buff"},

    -- Mage
    {spellId = 80353, name = "Time Warp", duration = 40, cooldownDuration = 600, class = "MAGE", trackType = "buff"}
}

-- Spell ID lookup for cast tracking
local CAST_TRACKED_SPELLS = {}
for _, cooldownInfo in ipairs(TRACKED_COOLDOWNS) do
    if cooldownInfo.trackType == "cast" then
        CAST_TRACKED_SPELLS[cooldownInfo.spellId] = cooldownInfo
    end
end

-- Frame variables
local cooldownFrame = nil
local cooldownBars = {}
local dpsBuffBars = {}
local activeCooldowns = nil  -- Will be set to db.activeCooldowns
local activeDpsBuffs = nil  -- Will be set to db.activeDpsBuffs
local combatLogFrame = nil

-- Handle combat log events for cast-based tracking (like Revival)
local function OnCombatLogEvent(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool)
    -- Only track SPELL_CAST_SUCCESS events
    if eventType ~= "SPELL_CAST_SUCCESS" then
        return
    end

    -- Check if this is a tracked cast spell
    local cooldownInfo = CAST_TRACKED_SPELLS[spellId]
    if not cooldownInfo then
        return
    end

    -- Only track if the caster is in our group or is the player
    local isPlayer = (sourceGUID == UnitGUID("player"))
    local isInGroup = false

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if sourceGUID == UnitGUID("raid" .. i) then
                isInGroup = true
                break
            end
        end
    elseif IsInGroup() then
        if sourceGUID == UnitGUID("player") then
            isInGroup = true
        else
            for i = 1, GetNumSubgroupMembers() do
                if sourceGUID == UnitGUID("party" .. i) then
                    isInGroup = true
                    break
                end
            end
        end
    end

    -- When solo, we should still track player spells
    if not isPlayer and not isInGroup then
        return
    end

    -- Add the cooldown to active tracking
    local currentTime = GetTime()
    local key = sourceName .. "-" .. spellId

    if not activeCooldowns[key] then
        -- Get caster's class
        local _, class
        if isPlayer then
            _, class = UnitClass("player")
        else
            -- Try to find the unit to get their class
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    if sourceGUID == UnitGUID("raid" .. i) then
                        _, class = UnitClass("raid" .. i)
                        break
                    end
                end
            elseif IsInGroup() then
                for i = 1, GetNumSubgroupMembers() do
                    if sourceGUID == UnitGUID("party" .. i) then
                        _, class = UnitClass("party" .. i)
                        break
                    end
                end
            end
        end

        -- Use the actual cooldown duration from the spell info
        local duration = cooldownInfo.duration

        activeCooldowns[key] = {
            spellId = spellId,
            spellName = cooldownInfo.name,
            casterName = sourceName,
            class = class or cooldownInfo.class,
            startTime = currentTime,
            endTime = currentTime + duration,
            duration = duration
        }
    end
end

-- Create cooldown bar
local function CreateCooldownBar(index)
    local bar = CreateFrame("Frame", "NordensParisCooldownBar"..index, cooldownFrame)
    bar:SetSize(180, 20)
    bar:SetPoint("TOPLEFT", 10, -30 - (index - 1) * 25)

    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    bar.bg = bg

    -- Progress bar
    local progress = bar:CreateTexture(nil, "ARTWORK")
    progress:SetPoint("LEFT", 0, 0)
    progress:SetHeight(20)
    progress:SetWidth(180)
    progress:SetColorTexture(0.2, 0.6, 0.8, 0.7)
    bar.progress = progress

    -- Icon
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 2, 0)
    bar.icon = icon

    -- Spell name text
    local nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", 22, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetTextColor(1, 1, 1)
    bar.nameText = nameText

    -- Timer text
    local timerText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("RIGHT", -5, 0)
    timerText:SetJustifyH("RIGHT")
    timerText:SetTextColor(1, 1, 0)
    bar.timerText = timerText

    bar:Hide()
    return bar
end

-- Create DPS buff bar
local function CreateDpsBuffBar(index, yOffset)
    local bar = CreateFrame("Frame", "NordensParisBuffBar"..index, cooldownFrame)
    bar:SetSize(180, 20)
    bar:SetPoint("TOPLEFT", 10, yOffset - (index - 1) * 25)

    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    bar.bg = bg

    -- Progress bar
    local progress = bar:CreateTexture(nil, "ARTWORK")
    progress:SetPoint("LEFT", 0, 0)
    progress:SetHeight(20)
    progress:SetWidth(180)
    progress:SetColorTexture(0.8, 0.4, 0.1, 0.7)
    bar.progress = progress

    -- Icon
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 2, 0)
    bar.icon = icon

    -- Spell name text
    local nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", 22, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetTextColor(1, 1, 1)
    bar.nameText = nameText

    -- Timer text
    local timerText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("RIGHT", -5, 0)
    timerText:SetJustifyH("RIGHT")
    timerText:SetTextColor(1, 1, 0)
    bar.timerText = timerText

    bar:Hide()
    return bar
end

-- Create the main cooldown tracker frame
local function CreateCooldownTrackerFrame(parentFrame, db)
    -- Initialize activeCooldowns from saved data
    activeCooldowns = db.activeCooldowns or {}
    db.activeCooldowns = activeCooldowns

    activeDpsBuffs = db.activeDpsBuffs or {}
    db.activeDpsBuffs = activeDpsBuffs

    cooldownFrame = CreateFrame("Frame", "NordensParisCooldownFrame", UIParent)
    cooldownFrame:SetSize(200, 300)

    -- Restore saved position or use default position relative to parent
    if db.cooldownX and db.cooldownY then
        cooldownFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.cooldownX, db.cooldownY)
    else
        cooldownFrame:SetPoint("TOPLEFT", parentFrame, "TOPRIGHT", 10, 0)
    end

    -- Make it movable
    cooldownFrame:EnableMouse(true)
    cooldownFrame:SetMovable(true)
    cooldownFrame:RegisterForDrag("LeftButton")
    cooldownFrame:SetClampedToScreen(true)

    cooldownFrame:SetScript("OnDragStart", function(self)
        if not db.locked then
            self:StartMoving()
        end
    end)

    cooldownFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.cooldownX = x
        db.cooldownY = y
    end)

    -- Background
    local bg = cooldownFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)

    -- Title for Healer Cooldowns
    local titleText = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", 0, -5)
    titleText:SetText("Healer Cooldowns")
    titleText:SetTextColor(0.5, 0.8, 1)
    cooldownFrame.healerTitle = titleText

    -- Create cooldown bars
    for i = 1, 10 do
        cooldownBars[i] = CreateCooldownBar(i)
    end

    -- Title for DPS Cooldowns (will be positioned dynamically)
    local dpsTitle = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dpsTitle:SetText("DPS Cooldowns")
    dpsTitle:SetTextColor(1, 0.7, 0.2)
    cooldownFrame.dpsTitle = dpsTitle

    -- Create DPS buff bars (position will be set dynamically)
    for i = 1, 5 do
        dpsBuffBars[i] = CreateDpsBuffBar(i, 0)  -- yOffset will be updated dynamically
    end

    -- Create independent spell cast listener frame
    -- Use UNIT_SPELLCAST_SUCCEEDED instead of COMBAT_LOG since it's more reliable
    if not combatLogFrame then
        combatLogFrame = CreateFrame("Frame")
        combatLogFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        combatLogFrame:SetScript("OnEvent", function(self, event, unit, spellName, rank, lineID, spellId)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                -- In MoP Classic, spellId might be nil but embedded in spellName as a Cast string
                -- Format: "Cast-3-4468-870-5679-115310-0004163A0A"
                if not spellId and spellName and type(spellName) == "string" and string.find(spellName, "Cast%-") then
                    -- Extract spell ID from the cast string
                    local extractedId = string.match(spellName, "Cast%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
                    if extractedId then
                        spellId = tonumber(extractedId)
                    end
                end

                -- Check if this is a tracked cast spell
                local cooldownInfo = CAST_TRACKED_SPELLS[spellId]
                if not cooldownInfo then
                    return
                end

                -- Only track player and group members
                local isPlayer = (unit == "player")
                local isInGroup = unit and (string.find(unit, "party") or string.find(unit, "raid"))

                if isPlayer or isInGroup then
                    local casterName = UnitName(unit)
                    local _, class = UnitClass(unit)
                    local currentTime = GetTime()
                    local duration = cooldownInfo.duration
                    local key = casterName .. "-" .. spellId

                    activeCooldowns[key] = {
                        spellId = spellId,
                        spellName = cooldownInfo.name,
                        casterName = casterName,
                        class = class or cooldownInfo.class,
                        startTime = currentTime,
                        endTime = currentTime + duration,
                        duration = duration,
                        cooldownDuration = cooldownInfo.cooldownDuration,
                        buffEndTime = currentTime + duration,
                        isBuffPhase = true  -- Show active/channel phase first
                    }
                end
            end
        end)
    end

    if db.showCooldowns then
        cooldownFrame:Show()
    else
        cooldownFrame:Hide()
    end

    return cooldownFrame
end

-- Get class color
local function GetClassColor(class)
    local colors = {
        DRUID = {1, 0.49, 0.04},
        PALADIN = {0.96, 0.55, 0.73},
        PRIEST = {1, 1, 1},
        SHAMAN = {0, 0.44, 0.87},
        MONK = {0, 1, 0.59},
        WARRIOR = {0.78, 0.61, 0.43},
        WARLOCK = {0.58, 0.51, 0.79},
        HUNTER = {0.67, 0.83, 0.45},
        MAGE = {0.41, 0.8, 0.94},
        DEATHKNIGHT = {0.77, 0.12, 0.23},
    }
    return colors[class] or {0.5, 0.5, 0.5}
end

-- Helper function to scan a single unit for cooldowns (buff-based tracking)
local function ScanUnitForCooldowns(unit, targetUnits, currentTime)
    if not UnitExists(unit) then return end

    local _, class = UnitClass(unit)
    local unitName = UnitName(unit)

    -- Check for tracked cooldowns that use buff tracking
    for _, cooldownInfo in ipairs(TRACKED_COOLDOWNS) do
        if class == cooldownInfo.class and cooldownInfo.trackType == "buff" then
            -- Check if buff is active on any target
            for _, targetUnit in ipairs(targetUnits) do
                if UnitExists(targetUnit) then
                    for buffIndex = 1, 40 do
                        local name, _, _, _, _, expirationTime, caster, _, _, spellId = UnitBuff(targetUnit, buffIndex)
                        if not name then break end

                        if spellId == cooldownInfo.spellId then
                            local casterName = caster and UnitName(caster) or "Unknown"
                            local key = casterName .. "-" .. spellId

                            if not activeCooldowns[key] then
                                activeCooldowns[key] = {
                                    spellId = spellId,
                                    spellName = cooldownInfo.name,
                                    casterName = casterName,
                                    class = class,
                                    startTime = currentTime,
                                    endTime = expirationTime,
                                    duration = cooldownInfo.duration > 0 and cooldownInfo.duration or (expirationTime - currentTime),
                                    cooldownDuration = cooldownInfo.cooldownDuration,
                                    buffEndTime = expirationTime,
                                    isBuffPhase = true
                                }
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Helper function to scan for DPS buffs
local function ScanUnitForDpsBuffs(unit, targetUnits, currentTime)
    if not UnitExists(unit) then return end

    local _, class = UnitClass(unit)
    local unitName = UnitName(unit)

    -- Check for tracked DPS buffs
    for _, buffInfo in ipairs(TRACKED_DPS_BUFFS) do
        if class == buffInfo.class and buffInfo.trackType == "buff" then
            -- Check if buff is active on any target (usually raid-wide buffs)
            for _, targetUnit in ipairs(targetUnits) do
                if UnitExists(targetUnit) then
                    for buffIndex = 1, 40 do
                        local name, _, _, _, _, expirationTime, caster, _, _, spellId = UnitBuff(targetUnit, buffIndex)
                        if not name then break end

                        if spellId == buffInfo.spellId then
                            local casterName = caster and UnitName(caster) or "Unknown"
                            local key = casterName .. "-" .. spellId

                            if not activeDpsBuffs[key] then
                                activeDpsBuffs[key] = {
                                    spellId = spellId,
                                    spellName = buffInfo.name,
                                    casterName = casterName,
                                    class = class,
                                    startTime = currentTime,
                                    endTime = expirationTime,
                                    duration = buffInfo.duration > 0 and buffInfo.duration or (expirationTime - currentTime),
                                    cooldownDuration = buffInfo.cooldownDuration,
                                    buffEndTime = expirationTime,
                                    isBuffPhase = true
                                }
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Check if a unit has a tracked cooldown active
local function ScanForCooldowns()
    local currentTime = GetTime()
    local unitsToScan = {}
    local targetUnits = {}

    -- Determine units to scan based on group type
    if IsInRaid() then
        -- In raid: scan all raid members (includes player)
        local unitCount = GetNumGroupMembers()
        for i = 1, unitCount do
            table.insert(unitsToScan, "raid" .. i)
            table.insert(targetUnits, "raid" .. i)
        end
    elseif IsInGroup() then
        -- In party: scan player + party members
        table.insert(unitsToScan, "player")
        table.insert(targetUnits, "player")

        local unitCount = GetNumSubgroupMembers()
        for i = 1, unitCount do
            table.insert(unitsToScan, "party" .. i)
            table.insert(targetUnits, "party" .. i)
        end
    else
        -- Solo: only scan player
        table.insert(unitsToScan, "player")
        table.insert(targetUnits, "player")
    end

    -- Scan all units for healer cooldowns
    for _, unit in ipairs(unitsToScan) do
        ScanUnitForCooldowns(unit, targetUnits, currentTime)
    end

    -- Scan all units for DPS buffs (only in party or raid, not solo)
    if IsInRaid() or IsInGroup() then
        for _, unit in ipairs(unitsToScan) do
            ScanUnitForDpsBuffs(unit, targetUnits, currentTime)
        end
    end

    -- Clean up expired cooldowns and transition buff cooldowns to actual cooldowns
    for key, cd in pairs(activeCooldowns) do
        if currentTime >= cd.endTime then
            -- If this was a buff and has a cooldown phase, transition to cooldown tracking
            if cd.isBuffPhase and cd.cooldownDuration and cd.cooldownDuration > 0 then
                cd.isBuffPhase = false
                -- Cooldown started when spell was cast, so endTime = startTime + cooldownDuration
                cd.endTime = cd.startTime + cd.cooldownDuration
                cd.duration = cd.cooldownDuration
            else
                -- Cooldown fully expired, remove it
                activeCooldowns[key] = nil
            end
        end
    end

    -- Clean up expired DPS buffs and transition to cooldown tracking
    for key, buff in pairs(activeDpsBuffs) do
        if currentTime >= buff.endTime then
            -- If this was a buff and has a cooldown phase, transition to cooldown tracking
            if buff.isBuffPhase and buff.cooldownDuration and buff.cooldownDuration > 0 then
                buff.isBuffPhase = false
                -- Cooldown started when spell was cast, so endTime = startTime + cooldownDuration
                buff.endTime = buff.startTime + buff.cooldownDuration
                buff.duration = buff.cooldownDuration
            else
                -- Cooldown fully expired, remove it
                activeDpsBuffs[key] = nil
            end
        end
    end
end

-- Update cooldown display
local function UpdateCooldownDisplay(db)
    if not cooldownFrame or not db.showCooldowns then
        return
    end

    ScanForCooldowns()

    -- Sort active healer cooldowns by time remaining
    local sortedCooldowns = {}
    for _, cd in pairs(activeCooldowns) do
        table.insert(sortedCooldowns, cd)
    end

    table.sort(sortedCooldowns, function(a, b)
        return (a.endTime - GetTime()) > (b.endTime - GetTime())
    end)

    -- Sort active DPS buffs by time remaining
    local sortedBuffs = {}
    for _, buff in pairs(activeDpsBuffs) do
        table.insert(sortedBuffs, buff)
    end

    table.sort(sortedBuffs, function(a, b)
        return (a.endTime - GetTime()) > (b.endTime - GetTime())
    end)

    -- Hide entire frame if no cooldowns are active
    if #sortedCooldowns == 0 and #sortedBuffs == 0 then
        cooldownFrame:Hide()
        return
    end

    cooldownFrame:Show()

    -- Update healer cooldown bars
    local currentTime = GetTime()
    local visibleHealerCds = 0
    for i = 1, 10 do
        local bar = cooldownBars[i]
        local cd = sortedCooldowns[i]

        if cd then
            bar:Show()
            visibleHealerCds = visibleHealerCds + 1

            -- Update icon
            local texture = GetSpellTexture(cd.spellId)
            bar.icon:SetTexture(texture)

            -- Update name text with caster
            local classColor = GetClassColor(cd.class)
            local displayText = cd.casterName .. ": " .. cd.spellName
            if cd.isBuffPhase then
                displayText = displayText .. " (ACTIVE)"
            end
            bar.nameText:SetText(displayText)
            bar.nameText:SetTextColor(classColor[1], classColor[2], classColor[3])

            -- Update timer
            local timeRemaining = cd.endTime - currentTime
            if timeRemaining > 0 then
                -- Format timer without decimals
                local minutes = math.floor(timeRemaining / 60)
                local seconds = math.floor(timeRemaining % 60)

                if minutes > 0 then
                    bar.timerText:SetText(string.format("%dm %ds", minutes, seconds))
                else
                    bar.timerText:SetText(string.format("%ds", seconds))
                end

                -- Update progress bar
                local progress = timeRemaining / cd.duration
                bar.progress:SetWidth(180 * progress)

                -- Color based on phase
                if cd.isBuffPhase then
                    -- Buff is active - use bright colors
                    if timeRemaining > cd.duration * 0.5 then
                        bar.progress:SetColorTexture(0.2, 0.8, 0.2, 0.7)
                    elseif timeRemaining > cd.duration * 0.25 then
                        bar.progress:SetColorTexture(0.8, 0.8, 0.2, 0.7)
                    else
                        bar.progress:SetColorTexture(0.8, 0.2, 0.2, 0.7)
                    end
                else
                    -- On cooldown - use blue/gray
                    bar.progress:SetColorTexture(0.3, 0.3, 0.8, 0.7)
                end
            else
                bar.timerText:SetText("0s")
                bar.progress:SetWidth(0)
            end
        else
            bar:Hide()
        end
    end

    -- Show/hide healer title based on whether we have healer cooldowns
    if visibleHealerCds > 0 then
        cooldownFrame.healerTitle:Show()
    else
        cooldownFrame.healerTitle:Hide()
    end

    -- Calculate DPS buff section offset
    local dpsSectionOffset
    if visibleHealerCds > 0 then
        dpsSectionOffset = -30 - (visibleHealerCds * 25) - 30  -- Title offset - healer bars - spacing
    else
        dpsSectionOffset = -30  -- No healer CDs, start right below top
    end

    -- Show/hide DPS title based on whether we have DPS buffs
    if #sortedBuffs > 0 then
        cooldownFrame.dpsTitle:Show()
        cooldownFrame.dpsTitle:SetPoint("TOPLEFT", 10, dpsSectionOffset + 5)
    else
        cooldownFrame.dpsTitle:Hide()
    end

    -- Update DPS buff bars
    local visibleDpsBuffs = 0
    for i = 1, 5 do
        local bar = dpsBuffBars[i]
        local buff = sortedBuffs[i]

        -- Update bar position
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", 10, dpsSectionOffset - 20 - (i - 1) * 25)

        if buff then
            bar:Show()
            visibleDpsBuffs = visibleDpsBuffs + 1

            -- Update icon
            local texture = GetSpellTexture(buff.spellId)
            bar.icon:SetTexture(texture)

            -- Update name text with caster
            local classColor = GetClassColor(buff.class)
            local displayText = buff.casterName .. ": " .. buff.spellName
            if buff.isBuffPhase then
                displayText = displayText .. " (ACTIVE)"
            end
            bar.nameText:SetText(displayText)
            bar.nameText:SetTextColor(classColor[1], classColor[2], classColor[3])

            -- Update timer
            local timeRemaining = buff.endTime - currentTime
            if timeRemaining > 0 then
                -- Format timer without decimals
                local minutes = math.floor(timeRemaining / 60)
                local seconds = math.floor(timeRemaining % 60)

                if minutes > 0 then
                    bar.timerText:SetText(string.format("%dm %ds", minutes, seconds))
                else
                    bar.timerText:SetText(string.format("%ds", seconds))
                end

                -- Update progress bar
                local progress = timeRemaining / buff.duration
                bar.progress:SetWidth(180 * progress)

                -- Color based on phase
                if buff.isBuffPhase then
                    -- Buff is active - use orange colors
                    if timeRemaining > buff.duration * 0.5 then
                        bar.progress:SetColorTexture(1, 0.6, 0, 0.7)
                    elseif timeRemaining > buff.duration * 0.25 then
                        bar.progress:SetColorTexture(1, 0.8, 0, 0.7)
                    else
                        bar.progress:SetColorTexture(1, 0.3, 0, 0.7)
                    end
                else
                    -- On cooldown - use darker orange/brown
                    bar.progress:SetColorTexture(0.6, 0.3, 0.1, 0.7)
                end
            else
                bar.timerText:SetText("0s")
                bar.progress:SetWidth(0)
            end
        else
            bar:Hide()
        end
    end

    -- Adjust frame height based on active cooldowns and buffs
    local totalHeight
    if visibleHealerCds > 0 then
        totalHeight = 30 + (visibleHealerCds * 25)  -- Title + healer bars
        if visibleDpsBuffs > 0 then
            totalHeight = totalHeight + 30 + (visibleDpsBuffs * 25) + 10  -- Spacing + DPS title + DPS bars + bottom padding
        end
    else
        -- Only DPS buffs, no healer section
        if visibleDpsBuffs > 0 then
            totalHeight = 30 + (visibleDpsBuffs * 25) + 10  -- DPS title + DPS bars + bottom padding
        else
            totalHeight = 50  -- Minimum height
        end
    end
    cooldownFrame:SetHeight(math.max(50, totalHeight + 10))
end

-- Toggle frame visibility
local function ToggleFrame()
    if cooldownFrame then
        if cooldownFrame:IsShown() then
            cooldownFrame:Hide()
            return false
        else
            cooldownFrame:Show()
            return true
        end
    end
    return false
end

-- Export functions
NordensParis_ExternalCooldownTracker = {
    CreateCooldownTrackerFrame = CreateCooldownTrackerFrame,
    UpdateCooldownDisplay = UpdateCooldownDisplay,
    ToggleFrame = ToggleFrame
}
