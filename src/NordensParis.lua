---@diagnostic disable: unnecessary-if
-- Nordens Paris: Renewing Mist Tracker for Mistweaver Monks
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

local ADDON_NAME = "NordensParis"

-- Default position constants
local DEFAULT_X = 10
local DEFAULT_Y = -250

-- Frame variables
local frame = CreateFrame("Frame", "NordensParisFrame", UIParent)
local renewingMistFrame = nil
local statueFrame = nil
local cooldownFrame = nil
local updateTimer = 0
local UPDATE_INTERVAL = 1.0 -- Update every 1 second

-- Saved variables (per-character)
NordensParisCharDB = NordensParisCharDB or {
    locked = false,
    showRenewingMist = true,
    showStatue = true,
    showCooldowns = true,
    x = DEFAULT_X,
    y = DEFAULT_Y,
    cooldownX = nil,
    cooldownY = nil,
    activeCooldowns = {},
    plans = {},
    activePlan = nil,
    showActivePlan = false,
    activePlanX = nil,
    activePlanY = nil
}

-- Initialize the main frame
local function InitializeFrame()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", NordensParisCharDB.x, NordensParisCharDB.y)
    frame:SetSize(1, 1) -- Minimum size to ensure child frames can anchor properly

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    -- Drag handlers
    frame:SetScript("OnDragStart", function(self)
        if not NordensParisCharDB.locked then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        NordensParisCharDB.x = x
        NordensParisCharDB.y = y
    end)

    -- Create Renewing Mist tracking frame using external module
    if NordensParis_RenewingMistTracker then
        renewingMistFrame = NordensParis_RenewingMistTracker.CreateRenewingMistFrame(frame, NordensParisCharDB)
    end

    -- Create cooldown tracker frame using external module
    if NordensParis_ExternalCooldownTracker then
        cooldownFrame = NordensParis_ExternalCooldownTracker.CreateCooldownTrackerFrame(frame, NordensParisCharDB)
    end

    -- Create statue frame using external module
    if NordensParis_JadeSerpentTracker then
        statueFrame = NordensParis_JadeSerpentTracker.CreateStatueFrame(frame, NordensParisCharDB)
    end

    -- Initialize PlanManager before ActivePlan
    if NordensParis_PlanManager then
        NordensParis_PlanManager.Initialize(NordensParisCharDB)
    end

    -- Restore active plan if it was shown
    if NordensParis_ActivePlan and NordensParisCharDB.showActivePlan and NordensParisCharDB.activePlan then
        NordensParis_ActivePlan.Initialize(NordensParisCharDB)
        NordensParis_ActivePlan.Activate(NordensParisCharDB.activePlan, true)  -- Pass true to indicate restoration
    end
end

-- Update the display
local function UpdateDisplay()
    -- Update Renewing Mist display using external module
    if NordensParis_RenewingMistTracker then
        NordensParis_RenewingMistTracker.UpdateDisplay(NordensParisCharDB)
    end

    -- Update statue display using external module
    if NordensParis_JadeSerpentTracker then
        NordensParis_JadeSerpentTracker.UpdateStatueDisplay(NordensParisCharDB)
    end

    -- Update cooldown tracker using external module
    if NordensParis_ExternalCooldownTracker then
        NordensParis_ExternalCooldownTracker.UpdateCooldownDisplay(NordensParisCharDB)
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Initialize plan manager and addon communication FIRST
        if NordensParis_PlanManager then
            NordensParis_PlanManager.Initialize(NordensParisCharDB)
        end

        if NordensParis_AddonComm then
            NordensParis_AddonComm.Initialize()
        end

        -- Then initialize frames (which may restore active plan)
        InitializeFrame()
        UpdateDisplay()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        -- Only update on major events, UNIT_AURA is handled by individual modules now
        UpdateDisplay()
    end
end

-- OnUpdate handler for periodic updates
local function OnUpdate(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer >= UPDATE_INTERVAL then
        updateTimer = 0
        UpdateDisplay()
    end
end

-- Register events
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", OnEvent)
frame:SetScript("OnUpdate", OnUpdate)

-- Helper function to parse slash command arguments
local function ParseArgs(msg)
    local args = {}
    for word in string.gmatch(msg, "[^%s]+") do
        table.insert(args, word)
    end
    return args
end

-- Slash commands
SLASH_NORDENSPARIS1 = "/nordensparis"
SLASH_NORDENSPARIS2 = "/np"
SlashCmdList["NORDENSPARIS"] = function(msg)
    local args = ParseArgs(msg)
    local cmd = args[1] and string.lower(args[1]) or ""

    if cmd == "lock" then
        NordensParisCharDB.locked = true
        print("|cff00ff80Nordens Paris:|r Frame locked")
    elseif cmd == "unlock" then
        NordensParisCharDB.locked = false
        print("|cff00ff80Nordens Paris:|r Frame unlocked")
    elseif cmd == "mist" or cmd == "renewing" then
        NordensParisCharDB.showRenewingMist = not NordensParisCharDB.showRenewingMist
        if renewingMistFrame then
            if NordensParisCharDB.showRenewingMist then
                renewingMistFrame:Show()
                print("|cff00ff80Nordens Paris:|r Renewing Mist tracker shown")
            else
                renewingMistFrame:Hide()
                print("|cff00ff80Nordens Paris:|r Renewing Mist tracker hidden")
            end
        else
            print("|cff00ff80Nordens Paris:|r Renewing Mist tracker not available for this class")
        end
    elseif cmd == "statue" then
        NordensParisCharDB.showStatue = not NordensParisCharDB.showStatue
        if statueFrame then
            if NordensParisCharDB.showStatue then
                statueFrame:Show()
                print("|cff00ff80Nordens Paris:|r Statue tracker shown")
            else
                statueFrame:Hide()
                print("|cff00ff80Nordens Paris:|r Statue tracker hidden")
            end
        else
            print("|cff00ff80Nordens Paris:|r Statue tracker not available for this class")
        end
    elseif cmd == "cooldowns" or cmd == "cds" then
        NordensParisCharDB.showCooldowns = not NordensParisCharDB.showCooldowns
        if NordensParis_ExternalCooldownTracker then
            local shown = NordensParis_ExternalCooldownTracker.ToggleFrame()
            if shown then
                print("|cff00ff80Nordens Paris:|r Cooldown tracker shown")
            else
                print("|cff00ff80Nordens Paris:|r Cooldown tracker hidden")
            end
        end
    elseif cmd == "reset" then
        NordensParisCharDB.x = DEFAULT_X
        NordensParisCharDB.y = DEFAULT_Y
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", NordensParisCharDB.x, NordensParisCharDB.y)
        print("|cff00ff80Nordens Paris:|r Position reset")

    -- Plan management commands
    elseif cmd == "plan" or cmd == "plans" then
        if NordensParis_PlanUI then
            NordensParis_PlanUI.Toggle()
        else
            print("|cff00ff80Nordens Paris:|r Plan UI not available")
        end
    elseif cmd == "newplan" then
        local planName = table.concat(args, " ", 2)
        if planName and planName ~= "" and NordensParis_PlanManager then
            local plan, err = NordensParis_PlanManager.CreatePlan(planName)
            if plan then
                print("|cff00ff80Nordens Paris:|r Created plan: " .. planName)
            else
                print("|cff00ff80Nordens Paris:|r " .. err)
            end
        else
            print("|cff00ff80Nordens Paris:|r Usage: /np newplan <planName>")
        end
    elseif cmd == "addstep" then
        -- /npaddstep <planName> <order> <spellName> [caster]
        if #args >= 4 and NordensParis_PlanManager then
            local planName = args[2]
            local order = tonumber(args[3])
            local spellName = args[4]
            local caster = args[5]

            if NordensParis_PlanManager.AddStep(planName, order, spellName, caster) then
                print("|cff00ff80Nordens Paris:|r Added step to plan: " .. planName)
            else
                print("|cff00ff80Nordens Paris:|r Failed to add step")
            end
        else
            print("|cff00ff80Nordens Paris:|r Usage: /npaddstep <planName> <order> <spellName> [caster]")
        end
    elseif cmd == "shareplan" then
        local planName = table.concat(args, " ", 2)
        if planName and planName ~= "" and NordensParis_PlanManager and NordensParis_AddonComm then
            local exportData = NordensParis_PlanManager.ExportPlan(planName)
            if exportData then
                NordensParis_AddonComm.SharePlan(exportData)
            else
                print("|cff00ff80Nordens Paris:|r Plan not found: " .. planName)
            end
        else
            print("|cff00ff80Nordens Paris:|r Usage: /npshareplan <planName>")
        end
    elseif cmd == "requestplans" then
        if NordensParis_AddonComm then
            NordensParis_AddonComm.RequestPlans()
        else
            print("|cff00ff80Nordens Paris:|r Addon communication not available")
        end
    elseif cmd == "viewplan" or cmd == "received" then
        if NordensParis_AddonComm then
            local receivedPlans = NordensParis_AddonComm.GetReceivedPlans()
            if next(receivedPlans) then
                print("|cff00ff80Nordens Paris - Received Plans:|r")
                for sender, plans in pairs(receivedPlans) do
                    print("  From " .. sender .. ":")
                    for planName, plan in pairs(plans) do
                        print("    - " .. planName .. " (" .. #plan.steps .. " steps)")
                        for i, step in ipairs(plan.steps) do
                            local casterText = step.caster and (" by " .. step.caster) or ""
                            print("      " .. step.order .. ". " .. step.spellName .. casterText)
                        end
                    end
                end
            else
                print("|cff00ff80Nordens Paris:|r No plans received yet")
            end
        else
            print("|cff00ff80Nordens Paris:|r Addon communication not available")
        end
    elseif cmd == "listplans" then
        if NordensParis_PlanManager then
            local plans = NordensParis_PlanManager.GetAllPlans()
            if next(plans) then
                print("|cff00ff80Nordens Paris - My Plans:|r")
                for planName, plan in pairs(plans) do
                    local summary = NordensParis_PlanManager.GetPlanSummary(planName)
                    print("  " .. planName .. " (" .. summary.stepCount .. " steps)")
                    for i, step in ipairs(plan.steps) do
                        local casterText = step.caster and (" by " .. step.caster) or ""
                        local status = step.completed and "[X]" or "[ ]"
                        print("    " .. status .. " " .. step.order .. ". " .. step.spellName .. casterText)
                    end
                end
            else
                print("|cff00ff80Nordens Paris:|r No plans created yet")
            end
        else
            print("|cff00ff80Nordens Paris:|r Plan manager not available")
        end
    elseif cmd == "help" or cmd == "" then
        print("|cff00ff80Nordens Paris Commands:|r")
        print("  /np lock - Lock the frame")
        print("  /np unlock - Unlock the frame")
        print("  /np mist (or renewing) - Toggle Renewing Mist tracker")
        print("  /np statue - Toggle statue tracker")
        print("  /np cooldowns (or cds) - Toggle cooldown tracker")
        print("  /np sck (or crane) - Toggle Spinning Crane Kick tracker")
        print("  /np reset - Reset position")
        print("  ")
        print("|cff00ff80Plan Management:|r")
        print("  /np plan - Open plan manager UI")
        print("  /np newplan <name> - Create a new plan")
        print("  /np listplans - List all your plans")
        print("  /np addstep <plan> <order> <spell> [caster] - Add step to plan")
        print("  /np shareplan <name> - Share plan with group")
        print("  /np requestplans - Request plans from group")
        print("  /np viewplan - View received plans")
        print("  /np help - Show this help")
    else
        print("|cff00ff80Nordens Paris:|r Unknown command. Type /np help for commands.")
    end
end

print("|cff00ff80Nordens Paris|r loaded! Type /np help for commands.")
