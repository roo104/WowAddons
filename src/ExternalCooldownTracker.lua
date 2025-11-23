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

-- Raid-wide mana gaining spells to track (MoP spell IDs)
local TRACKED_MANA_BUFFS = {
    -- Shaman
    {spellId = 16190, name = "Mana Tide Totem", duration = 16, cooldownDuration = 180, class = "SHAMAN", trackType = "cast"},

    -- Priest (Hymn of Hope)
    {spellId = 64901, name = "Hymn of Hope", duration = 8, cooldownDuration = 360, class = "PRIEST", trackType = "cast"}
}

-- Combat resurrection spells to track (MoP spell IDs)
local TRACKED_COMBAT_RES = {
    -- Druid (Rebirth)
    {spellId = 20484, name = "Rebirth", duration = 0, cooldownDuration = 600, class = "DRUID", trackType = "cast"},

    -- Death Knight (Raise Ally)
    {spellId = 61999, name = "Raise Ally", duration = 0, cooldownDuration = 600, class = "DEATHKNIGHT", trackType = "cast"},

    -- Warlock (Soulstone - when used)
    {spellId = 20707, name = "Soulstone", duration = 0, cooldownDuration = 600, class = "WARLOCK", trackType = "cast"},

    -- Shaman (Reincarnation / Ankh)
    {spellId = 21169, name = "Reincarnation", duration = 0, cooldownDuration = 1800, class = "SHAMAN", trackType = "cast"}
}

-- Spell ID lookup for cast tracking
local CAST_TRACKED_SPELLS = {}
for _, cooldownInfo in ipairs(TRACKED_COOLDOWNS) do
    if cooldownInfo.trackType == "cast" then
        CAST_TRACKED_SPELLS[cooldownInfo.spellId] = {info = cooldownInfo, category = "healer"}
    end
end

-- Add mana buffs to cast tracking
local CAST_TRACKED_MANA_SPELLS = {}
for _, buffInfo in ipairs(TRACKED_MANA_BUFFS) do
    if buffInfo.trackType == "cast" then
        CAST_TRACKED_MANA_SPELLS[buffInfo.spellId] = buffInfo
        CAST_TRACKED_SPELLS[buffInfo.spellId] = {info = buffInfo, category = "mana"}
    end
end

-- Add combat res to cast tracking
for _, resInfo in ipairs(TRACKED_COMBAT_RES) do
    if resInfo.trackType == "cast" then
        CAST_TRACKED_SPELLS[resInfo.spellId] = {info = resInfo, category = "combatres"}
    end
end

-- Build unified lookup table for all tracked buffs
local BUFF_LOOKUP = {}

for _, cooldownInfo in ipairs(TRACKED_COOLDOWNS) do
    if cooldownInfo.trackType == "buff" then
        BUFF_LOOKUP[cooldownInfo.spellId] = {info = cooldownInfo, category = "healer"}
    end
end

for _, buffInfo in ipairs(TRACKED_DPS_BUFFS) do
    if buffInfo.trackType == "buff" then
        BUFF_LOOKUP[buffInfo.spellId] = {info = buffInfo, category = "dps"}
    end
end

for _, buffInfo in ipairs(TRACKED_MANA_BUFFS) do
    if buffInfo.trackType == "buff" then
        BUFF_LOOKUP[buffInfo.spellId] = {info = buffInfo, category = "mana"}
    end
end

-- Frame variables
local cooldownFrame = nil
local cooldownBars = {}
local dpsBuffBars = {}
local manaBuffBars = {}
local combatResBars = {}
local activeCooldowns = nil  -- Will be set to db.activeCooldowns
local activeDpsBuffs = nil  -- Will be set to db.activeDpsBuffs
local activeManaBuffs = nil  -- Will be set to db.activeManaBuffs
local activeCombatRes = nil  -- Will be set to db.activeCombatRes
local combatLogFrame = nil
local unitAuraFrame = nil
local needsFullScan = true  -- Flag to trigger full scan on roster changes

-- Handle combat log events for cast-based tracking (like Revival)
local function OnCombatLogEvent(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool)
    -- Only track SPELL_CAST_SUCCESS events
    if eventType ~= "SPELL_CAST_SUCCESS" then
        return
    end

    -- Check if this is a tracked cast spell
    local spellData = CAST_TRACKED_SPELLS[spellId]
    if not spellData then
        return
    end
    local cooldownInfo = spellData.info

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

-- Create Mana buff bar
local function CreateManaBuffBar(index, yOffset)
    local bar = CreateFrame("Frame", "NordensParisManaBar"..index, cooldownFrame)
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
    progress:SetColorTexture(0.2, 0.5, 0.9, 0.7)
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

-- Create Combat Res bar
local function CreateCombatResBar(index, yOffset)
    local bar = CreateFrame("Frame", "NordensParisCombatResBar"..index, cooldownFrame)
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
    progress:SetColorTexture(0.8, 0.2, 0.8, 0.7)
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

-- Clean up expired cooldowns and transition buff cooldowns to actual cooldowns
local function CleanupExpiredCooldowns()
    local currentTime = GetTime()

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

    -- Clean up expired Mana buffs and transition to cooldown tracking
    for key, buff in pairs(activeManaBuffs) do
        if currentTime >= buff.endTime then
            -- If this was a buff and has a cooldown phase, transition to cooldown tracking
            if buff.isBuffPhase and buff.cooldownDuration and buff.cooldownDuration > 0 then
                buff.isBuffPhase = false
                -- Cooldown started when spell was cast, so endTime = startTime + cooldownDuration
                buff.endTime = buff.startTime + buff.cooldownDuration
                buff.duration = buff.cooldownDuration
            else
                -- Cooldown fully expired, remove it
                activeManaBuffs[key] = nil
            end
        end
    end

    -- Clean up expired Combat Res and transition to cooldown tracking
    for key, res in pairs(activeCombatRes) do
        if currentTime >= res.endTime then
            -- Remove expired combat res
            activeCombatRes[key] = nil
        end
    end
end

-- Event-driven: Handle UNIT_AURA for specific unit
local function OnUnitAura(unit)
    if not unit or not UnitExists(unit) then return end

    local currentTime = GetTime()
    local isInGroup = IsInRaid() or IsInGroup()

    -- Single loop through unit's buffs, check against all tracked spells
    for buffIndex = 1, 40 do
        local name, _, _, _, _, expirationTime, caster, _, _, buffSpellId = UnitBuff(unit, buffIndex)
        if not name then break end

        -- Check if this buff matches any tracked spell
        local buffData = BUFF_LOOKUP[buffSpellId]
        if buffData then
            local buffInfo = buffData.info
            local category = buffData.category

            -- Skip non-healer buffs if not in group
            if isInGroup or category == "healer" then
                local casterName = caster and UnitName(caster) or "Unknown"
                local _, casterClass = UnitClass(caster)
                local key = casterName .. "-" .. buffSpellId

                local spellRecord = {
                    spellId = buffSpellId,
                    spellName = buffInfo.name,
                    casterName = casterName,
                    class = casterClass or buffInfo.class,
                    startTime = currentTime,
                    endTime = expirationTime,
                    duration = buffInfo.duration > 0 and buffInfo.duration or (expirationTime - currentTime),
                    cooldownDuration = buffInfo.cooldownDuration,
                    buffEndTime = expirationTime,
                    isBuffPhase = true
                }

                -- Route to appropriate table based on category
                if category == "healer" then
                    if not activeCooldowns[key] then
                        activeCooldowns[key] = spellRecord
                    end
                elseif category == "dps" then
                    if not activeDpsBuffs[key] then
                        activeDpsBuffs[key] = spellRecord
                    end
                elseif category == "mana" then
                    if not activeManaBuffs[key] then
                        activeManaBuffs[key] = spellRecord
                    end
                end
            end
        end
    end
end

-- Create the main cooldown tracker frame
local function CreateCooldownTrackerFrame(parentFrame, db)
    -- Initialize activeCooldowns from saved data
    activeCooldowns = db.activeCooldowns or {}
    db.activeCooldowns = activeCooldowns

    activeDpsBuffs = db.activeDpsBuffs or {}
    db.activeDpsBuffs = activeDpsBuffs

    activeManaBuffs = db.activeManaBuffs or {}
    db.activeManaBuffs = activeManaBuffs

    activeCombatRes = db.activeCombatRes or {}
    db.activeCombatRes = activeCombatRes

    cooldownFrame = CreateFrame("Frame", "NordensParisCooldownFrame", UIParent)
    cooldownFrame:SetSize(200, 50)  -- Start with minimum height, will adjust dynamically

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

    -- Title for Mana Cooldowns (will be positioned dynamically)
    local manaTitle = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manaTitle:SetText("Mana Cooldowns")
    manaTitle:SetTextColor(0.4, 0.7, 1)
    cooldownFrame.manaTitle = manaTitle

    -- Create Mana buff bars (position will be set dynamically)
    for i = 1, 5 do
        manaBuffBars[i] = CreateManaBuffBar(i, 0)  -- yOffset will be updated dynamically
    end

    -- Title for Combat Res (will be positioned dynamically)
    local combatResTitle = cooldownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    combatResTitle:SetText("Combat Res")
    combatResTitle:SetTextColor(0.9, 0.3, 0.9)
    cooldownFrame.combatResTitle = combatResTitle

    -- Create Combat Res bars (position will be set dynamically)
    for i = 1, 5 do
        combatResBars[i] = CreateCombatResBar(i, 0)  -- yOffset will be updated dynamically
    end

    -- Create UNIT_AURA listener frame for event-driven buff tracking
    if not unitAuraFrame then
        unitAuraFrame = CreateFrame("Frame")
        unitAuraFrame:RegisterEvent("UNIT_AURA")
        unitAuraFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        unitAuraFrame:SetScript("OnEvent", function(self, event, unit)
            if event == "UNIT_AURA" then
                OnUnitAura(unit)
            elseif event == "GROUP_ROSTER_UPDATE" then
                needsFullScan = true
            end
        end)
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
                local spellData = CAST_TRACKED_SPELLS[spellId]
                if not spellData then
                    return
                end

                -- Only track player and group members
                local isPlayer = (unit == "player")
                local isInGroup = unit and (string.find(unit, "party") or string.find(unit, "raid"))

                if isPlayer or isInGroup then
                    local casterName = UnitName(unit)
                    local _, class = UnitClass(unit)
                    local currentTime = GetTime()
                    local cooldownInfo = spellData.info
                    local duration = cooldownInfo.duration
                    local key = casterName .. "-" .. spellId

                    local spellRecord = {
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

                    -- Route to appropriate table based on category
                    if spellData.category == "mana" then
                        activeManaBuffs[key] = spellRecord
                    elseif spellData.category == "combatres" then
                        activeCombatRes[key] = spellRecord
                    else
                        activeCooldowns[key] = spellRecord
                    end
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

-- Update cooldown display
local function UpdateCooldownDisplay(db)
    if not cooldownFrame or not db.showCooldowns then
        return
    end

    -- Only clean up expired cooldowns, don't scan all units
    CleanupExpiredCooldowns()

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

    -- Sort active Mana buffs by time remaining
    local sortedManaBuffs = {}
    for _, buff in pairs(activeManaBuffs) do
        table.insert(sortedManaBuffs, buff)
    end

    table.sort(sortedManaBuffs, function(a, b)
        return (a.endTime - GetTime()) > (b.endTime - GetTime())
    end)

    -- Sort active Combat Res by time remaining
    local sortedCombatRes = {}
    for _, res in pairs(activeCombatRes) do
        table.insert(sortedCombatRes, res)
    end

    table.sort(sortedCombatRes, function(a, b)
        return (a.endTime - GetTime()) > (b.endTime - GetTime())
    end)

    -- Hide entire frame if no cooldowns are active
    if #sortedCooldowns == 0 and #sortedBuffs == 0 and #sortedManaBuffs == 0 and #sortedCombatRes == 0 then
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

    -- Calculate Mana buff section offset
    local manaSectionOffset
    if visibleHealerCds > 0 then
        if visibleDpsBuffs > 0 then
            manaSectionOffset = -30 - (visibleHealerCds * 25) - 30 - (visibleDpsBuffs * 25) - 30  -- Title - healer bars - DPS section - spacing
        else
            manaSectionOffset = -30 - (visibleHealerCds * 25) - 30  -- Title - healer bars - spacing
        end
    else
        if visibleDpsBuffs > 0 then
            manaSectionOffset = -30 - (visibleDpsBuffs * 25) - 30  -- DPS section - spacing
        else
            manaSectionOffset = -30  -- No other sections, start right below top
        end
    end

    -- Show/hide Mana title based on whether we have Mana buffs
    if #sortedManaBuffs > 0 then
        cooldownFrame.manaTitle:Show()
        cooldownFrame.manaTitle:SetPoint("TOPLEFT", 10, manaSectionOffset + 5)
    else
        cooldownFrame.manaTitle:Hide()
    end

    -- Update Mana buff bars
    local visibleManaBuffs = 0
    for i = 1, 5 do
        local bar = manaBuffBars[i]
        local buff = sortedManaBuffs[i]

        -- Update bar position
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", 10, manaSectionOffset - 20 - (i - 1) * 25)

        if buff then
            bar:Show()
            visibleManaBuffs = visibleManaBuffs + 1

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
                    -- Buff is active - use blue colors
                    if timeRemaining > buff.duration * 0.5 then
                        bar.progress:SetColorTexture(0.2, 0.5, 0.9, 0.7)
                    elseif timeRemaining > buff.duration * 0.25 then
                        bar.progress:SetColorTexture(0.3, 0.6, 1, 0.7)
                    else
                        bar.progress:SetColorTexture(0.5, 0.7, 1, 0.7)
                    end
                else
                    -- On cooldown - use darker blue
                    bar.progress:SetColorTexture(0.2, 0.3, 0.6, 0.7)
                end
            else
                bar.timerText:SetText("0s")
                bar.progress:SetWidth(0)
            end
        else
            bar:Hide()
        end
    end

    -- Calculate Combat Res section offset
    local combatResSectionOffset
    if visibleHealerCds > 0 then
        if visibleDpsBuffs > 0 then
            if visibleManaBuffs > 0 then
                combatResSectionOffset = -30 - (visibleHealerCds * 25) - 30 - (visibleDpsBuffs * 25) - 30 - (visibleManaBuffs * 25) - 30
            else
                combatResSectionOffset = -30 - (visibleHealerCds * 25) - 30 - (visibleDpsBuffs * 25) - 30
            end
        else
            if visibleManaBuffs > 0 then
                combatResSectionOffset = -30 - (visibleHealerCds * 25) - 30 - (visibleManaBuffs * 25) - 30
            else
                combatResSectionOffset = -30 - (visibleHealerCds * 25) - 30
            end
        end
    else
        if visibleDpsBuffs > 0 then
            if visibleManaBuffs > 0 then
                combatResSectionOffset = -30 - (visibleDpsBuffs * 25) - 30 - (visibleManaBuffs * 25) - 30
            else
                combatResSectionOffset = -30 - (visibleDpsBuffs * 25) - 30
            end
        else
            if visibleManaBuffs > 0 then
                combatResSectionOffset = -30 - (visibleManaBuffs * 25) - 30
            else
                combatResSectionOffset = -30
            end
        end
    end

    -- Show/hide Combat Res title based on whether we have combat res
    if #sortedCombatRes > 0 then
        cooldownFrame.combatResTitle:Show()
        cooldownFrame.combatResTitle:SetPoint("TOPLEFT", 10, combatResSectionOffset + 5)
    else
        cooldownFrame.combatResTitle:Hide()
    end

    -- Update Combat Res bars
    local visibleCombatRes = 0
    for i = 1, 5 do
        local bar = combatResBars[i]
        local res = sortedCombatRes[i]

        -- Update bar position
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", 10, combatResSectionOffset - 20 - (i - 1) * 25)

        if res then
            bar:Show()
            visibleCombatRes = visibleCombatRes + 1

            -- Update icon
            local texture = GetSpellTexture(res.spellId)
            bar.icon:SetTexture(texture)

            -- Update name text with caster
            local classColor = GetClassColor(res.class)
            local displayText = res.casterName .. ": " .. res.spellName
            bar.nameText:SetText(displayText)
            bar.nameText:SetTextColor(classColor[1], classColor[2], classColor[3])

            -- Update timer
            local timeRemaining = res.endTime - currentTime
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
                local progress = timeRemaining / res.duration
                bar.progress:SetWidth(180 * progress)

                -- Use purple color for combat res cooldown
                bar.progress:SetColorTexture(0.6, 0.2, 0.6, 0.7)
            else
                bar.timerText:SetText("0s")
                bar.progress:SetWidth(0)
            end
        else
            bar:Hide()
        end
    end

    -- Adjust frame height based on active cooldowns and buffs
    local totalHeight = 30  -- Start with title space

    if visibleHealerCds > 0 then
        totalHeight = totalHeight + (visibleHealerCds * 25)  -- Healer bars
    end

    if visibleDpsBuffs > 0 then
        totalHeight = totalHeight + 30 + (visibleDpsBuffs * 25)  -- DPS title + bars
    end

    if visibleManaBuffs > 0 then
        totalHeight = totalHeight + 30 + (visibleManaBuffs * 25)  -- Mana title + bars
    end

    if visibleCombatRes > 0 then
        totalHeight = totalHeight + 30 + (visibleCombatRes * 25)  -- Combat Res title + bars
    end

    -- Add bottom padding
    totalHeight = totalHeight + 10

    cooldownFrame:SetHeight(math.max(50, totalHeight))
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
