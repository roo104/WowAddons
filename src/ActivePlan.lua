-- ActivePlan: Standalone viewer for the currently active cooldown plan
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

local ActivePlan = {}

-- UI Elements
local viewerFrame = nil
local currentPlan = nil
local updateFrame = nil
local activeCooldowns = {}
local db = nil

-- Available spells for icon lookup with cooldown info
local AVAILABLE_SPELLS = {
    {id = 51052, name = "Anti-Magic Zone", duration = 10, cooldownDuration = 120},
    {id = 31842, name = "Devotion Aura", duration = 6, cooldownDuration = 180},
    {id = 64843, name = "Divine Hymn", duration = 8, cooldownDuration = 180},
    {id = 108280, name = "Healing Tide Totem", duration = 10, cooldownDuration = 180},
    {id = 62618, name = "Power Word: Barrier", duration = 10, cooldownDuration = 180},
    {id = 97462, name = "Rallying Cry", duration = 10, cooldownDuration = 180},
    {id = 115310, name = "Revival", duration = 0, cooldownDuration = 180},
    {id = 76577, name = "Smoke Bomb", duration = 5, cooldownDuration = 180},
    {id = 740, name = "Tranquility", duration = 8, cooldownDuration = 180},
}

-- Create spell ID to info lookup
local SPELL_ID_LOOKUP = {}
for _, spell in ipairs(AVAILABLE_SPELLS) do
    SPELL_ID_LOOKUP[spell.id] = spell
end

-- Initialize with database
function ActivePlan.Initialize(database)
    db = database
    -- Restore active cooldowns from saved variables
    if db and db.activeCooldowns then
        activeCooldowns = db.activeCooldowns
    end
end

-- Create plan viewer frame (standalone, like healer cooldowns)
function ActivePlan.CreateViewerFrame()
    if viewerFrame then
        return viewerFrame
    end

    viewerFrame = CreateFrame("Frame", "NordensParisActivePlanViewer", UIParent)
    viewerFrame:SetSize(200, 300)

    -- Restore saved position or use default
    if db and db.activePlanX and db.activePlanY then
        viewerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.activePlanX, db.activePlanY)
    else
        viewerFrame:SetPoint("LEFT", UIParent, "LEFT", 20, 0)
    end

    viewerFrame:SetMovable(true)
    viewerFrame:EnableMouse(true)
    viewerFrame:RegisterForDrag("LeftButton")
    viewerFrame:SetClampedToScreen(true)

    viewerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    viewerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if db then
            local point, _, _, x, y = self:GetPoint()
            db.activePlanX = x
            db.activePlanY = y
        end
    end)

    viewerFrame:Hide()

    -- Background
    local bg = viewerFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    viewerFrame.bg = bg

    -- Plan name title
    local titleText = viewerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", 0, -5)
    titleText:SetText("Active Plan")
    titleText:SetTextColor(0.5, 0.8, 1)
    viewerFrame.titleText = titleText

    -- Close button
    local closeButton = CreateFrame("Button", nil, viewerFrame, "UIPanelCloseButton")
    closeButton:SetSize(20, 20)
    closeButton:SetPoint("TOPRIGHT", 2, 2)
    closeButton:SetScript("OnClick", function()
        viewerFrame:Hide()
        if db then
            db.showActivePlan = false
            db.activePlan = nil
        end
    end)
    viewerFrame.closeButton = closeButton

    -- Scroll frame for steps
    local scrollFrame = CreateFrame("ScrollFrame", "NordensParisActivePlanScroll", viewerFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -25)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(160, 1)
    scrollFrame:SetScrollChild(scrollChild)

    viewerFrame.scrollFrame = scrollFrame
    viewerFrame.scrollChild = scrollChild
    viewerFrame.stepButtons = {}

    -- Create update frame for tracking cooldowns
    if not updateFrame then
        updateFrame = CreateFrame("Frame")
        updateFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        updateFrame:SetScript("OnEvent", function(self, event, unit, spellName, rank, lineID, spellId)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                -- In MoP Classic, spellId might be embedded in spellName
                if not spellId and spellName and type(spellName) == "string" and string.find(spellName, "Cast%-") then
                    local extractedId = string.match(spellName, "Cast%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
                    if extractedId then
                        spellId = tonumber(extractedId)
                    end
                end

                -- Check if this is a tracked spell
                local spellInfo = SPELL_ID_LOOKUP[spellId]
                if not spellInfo then
                    return
                end

                -- Only track player and group members
                local isPlayer = (unit == "player")
                local isInGroup = unit and (string.find(unit, "party") or string.find(unit, "raid"))

                if isPlayer or isInGroup then
                    local casterName = UnitName(unit)
                    local currentTime = GetTime()
                    local key = casterName .. "-" .. spellId

                    activeCooldowns[key] = {
                        spellId = spellId,
                        spellName = spellInfo.name,
                        casterName = casterName,
                        startTime = currentTime,
                        endTime = currentTime + spellInfo.cooldownDuration,
                        duration = spellInfo.cooldownDuration
                    }

                    ActivePlan.Refresh()
                end
            end
        end)

        -- Update timer
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            if viewerFrame and viewerFrame:IsShown() then
                ActivePlan.UpdateTimers()
            end
        end)
    end

    return viewerFrame
end

-- Create a step button in the viewer
local function CreateStepButton(index)
    local btn = CreateFrame("Frame", nil, viewerFrame.scrollChild)
    btn:SetSize(150, 40)
    btn:EnableMouse(true)

    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)

    -- Order number
    btn.orderText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.orderText:SetPoint("LEFT", 5, 10)
    btn.orderText:SetJustifyH("LEFT")
    btn.orderText:SetTextColor(1, 0.8, 0)

    -- Spell icon
    btn.spellIcon = btn:CreateTexture(nil, "OVERLAY")
    btn.spellIcon:SetSize(24, 24)
    btn.spellIcon:SetPoint("LEFT", 25, 0)
    btn.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Cooldown overlay
    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetPoint("CENTER", btn.spellIcon, "CENTER", 0, 0)
    btn.cooldown:SetSize(24, 24)
    btn.cooldown:SetDrawEdge(false)

    -- Caster name (top)
    btn.casterText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.casterText:SetPoint("LEFT", 52, 8)
    btn.casterText:SetJustifyH("LEFT")
    btn.casterText:SetTextColor(1, 1, 1)
    btn.casterText:SetWidth(90)

    -- Spell name (bottom)
    btn.spellText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.spellText:SetPoint("LEFT", 52, -8)
    btn.spellText:SetJustifyH("LEFT")
    btn.spellText:SetTextColor(0.7, 0.7, 0.7)
    btn.spellText:SetWidth(90)

    btn:Hide()
    return btn
end

-- Update timers on cooldowns
function ActivePlan.UpdateTimers()
    if not viewerFrame or not viewerFrame.stepButtons then
        return
    end

    local currentTime = GetTime()

    -- Clean up expired cooldowns
    for key, cd in pairs(activeCooldowns) do
        if currentTime >= cd.endTime then
            activeCooldowns[key] = nil
        end
    end
end

-- Get sorted steps (unused first, then used by cooldown remaining)
local function GetSortedSteps(plan)
    if not plan or not plan.steps then
        return {}
    end

    local steps = {}
    local currentTime = GetTime()

    for i, step in ipairs(plan.steps) do
        -- Find spell ID
        local spellId = nil
        for _, spell in ipairs(AVAILABLE_SPELLS) do
            if spell.name == step.spellName then
                spellId = spell.id
                break
            end
        end

        -- Check if this step is on cooldown
        local cooldownKey = (step.caster or "") .. "-" .. (spellId or 0)
        local cooldown = activeCooldowns[cooldownKey]

        table.insert(steps, {
            originalIndex = i,
            step = step,
            spellId = spellId,
            cooldown = cooldown,
            timeRemaining = cooldown and (cooldown.endTime - currentTime) or 0,
            isOnCooldown = cooldown ~= nil
        })
    end

    -- Sort: unused first (by original order), then used (by time remaining desc)
    table.sort(steps, function(a, b)
        if a.isOnCooldown ~= b.isOnCooldown then
            return not a.isOnCooldown  -- unused first
        end
        if a.isOnCooldown then
            return a.timeRemaining > b.timeRemaining  -- longer cooldowns first
        end
        return a.originalIndex < b.originalIndex  -- original order for unused
    end)

    return steps
end

-- Refresh plan viewer display
function ActivePlan.Refresh()
    if not viewerFrame or not currentPlan or not NordensParis_PlanManager then
        return
    end

    local plan = NordensParis_PlanManager.GetPlan(currentPlan)
    if not plan then
        return
    end

    local scrollChild = viewerFrame.scrollChild
    local stepButtons = viewerFrame.stepButtons

    -- Clear existing buttons
    for _, btn in ipairs(stepButtons) do
        btn:Hide()
    end

    -- Get sorted steps
    local sortedSteps = GetSortedSteps(plan)
    local currentTime = GetTime()

    -- Create/update step buttons
    local yOffset = 0
    for i, stepData in ipairs(sortedSteps) do
        local step = stepData.step
        local btn = stepButtons[i]

        if not btn then
            btn = CreateStepButton(i)
            table.insert(stepButtons, btn)
        end

        btn:SetPoint("TOPLEFT", 5, -yOffset)
        btn:Show()

        btn.orderText:SetText(step.order .. ".")
        btn.spellText:SetText(step.spellName)
        btn.casterText:SetText(step.caster or "Anyone")

        -- Set spell icon
        if stepData.spellId then
            local texture = GetSpellTexture(stepData.spellId)
            if texture then
                btn.spellIcon:SetTexture(texture)
            end
        end

        -- Update cooldown display
        if stepData.cooldown then
            local timeRemaining = stepData.cooldown.endTime - currentTime
            if timeRemaining > 0 then
                btn.cooldown:SetCooldown(stepData.cooldown.startTime, stepData.cooldown.duration)
                btn.bg:SetColorTexture(0.3, 0.1, 0.1, 0.7)  -- Darker red tint for on cooldown
            else
                btn.cooldown:Clear()
                btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)
            end
        else
            btn.cooldown:Clear()
            btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)
        end

        yOffset = yOffset + 45
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset, 1))

    -- Resize frame to fit content (with padding for title and borders)
    local numSteps = #sortedSteps
    local frameHeight = math.max(80, 30 + (numSteps * 45) + 10)  -- 30 for title, 45 per step, 10 for bottom padding
    viewerFrame:SetHeight(frameHeight)

    -- Hide scrollbar if content fits
    local scrollBar = viewerFrame.scrollFrame.ScrollBar
    if scrollBar then
        if yOffset <= viewerFrame.scrollFrame:GetHeight() then
            scrollBar:Hide()
        else
            scrollBar:Show()
        end
    end
end

-- Activate a plan (show viewer)
function ActivePlan.Activate(planName, isRestore)
    if not NordensParis_PlanManager then
        return
    end

    local plan = NordensParis_PlanManager.GetPlan(planName)
    if not plan then
        print("|cff00ff80Nordens Paris:|r Plan not found: " .. planName)
        return
    end

    currentPlan = planName

    -- Only reset cooldowns when manually activating, not when restoring from saved state
    if not isRestore then
        activeCooldowns = {}
    end

    if not viewerFrame then
        ActivePlan.CreateViewerFrame()
    end

    viewerFrame:Show()
    viewerFrame.titleText:SetText(planName)

    -- Save state to database
    if db then
        db.activePlan = planName
        db.showActivePlan = true
    end

    ActivePlan.Refresh()
end

-- Toggle viewer visibility
function ActivePlan.Toggle()
    if not viewerFrame then
        return
    end

    if viewerFrame:IsShown() then
        viewerFrame:Hide()
        if db then
            db.showActivePlan = false
        end
    else
        viewerFrame:Show()
        if db then
            db.showActivePlan = true
        end
    end
end

-- Export the module
NordensParis_ActivePlan = ActivePlan
