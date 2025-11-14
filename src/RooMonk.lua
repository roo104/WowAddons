---@diagnostic disable: unnecessary-if
-- RooMonk: Renewing Mist Tracker for Mistweaver Monks
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

local ADDON_NAME = "RooMonk"

-- Frame variables
local frame = CreateFrame("Frame", "RooMonkFrame", UIParent)
local renewingMistFrame = nil
local statueFrame = nil
local cooldownFrame = nil
local updateTimer = 0
local UPDATE_INTERVAL = 0.25 -- Update every 0.25 seconds

-- Saved variables (per-character)
RooMonkCharDB = RooMonkCharDB or {
    locked = false,
    showRenewingMist = true,
    showStatue = true,
    showCooldowns = true,
    x = 100,
    y = -100,
    cooldownX = nil,
    cooldownY = nil,
    activeCooldowns = {},
    plans = {}
}

-- Initialize the main frame
local function InitializeFrame()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", RooMonkCharDB.x, RooMonkCharDB.y)
    frame:SetSize(1, 1) -- Minimum size to ensure child frames can anchor properly

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    -- Drag handlers
    frame:SetScript("OnDragStart", function(self)
        if not RooMonkCharDB.locked then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        RooMonkCharDB.x = x
        RooMonkCharDB.y = y
    end)

    -- Create Renewing Mist tracking frame using external module
    if RooMonk_RenewingMistTracker then
        renewingMistFrame = RooMonk_RenewingMistTracker.CreateRenewingMistFrame(frame, RooMonkCharDB)
    end

    -- Create statue frame using external module
    if RooMonk_JadeSerpentTracker then
        statueFrame = RooMonk_JadeSerpentTracker.CreateStatueFrame(frame, RooMonkCharDB)
    end

    -- Create cooldown tracker frame using external module
    if RooMonk_ExternalCooldownTracker then
        cooldownFrame = RooMonk_ExternalCooldownTracker.CreateCooldownTrackerFrame(frame, RooMonkCharDB)
    end
end

-- Update the display
local function UpdateDisplay()
    -- Update Renewing Mist display using external module
    if RooMonk_RenewingMistTracker then
        RooMonk_RenewingMistTracker.UpdateDisplay(RooMonkCharDB)
    end

    -- Update statue display using external module
    if RooMonk_JadeSerpentTracker then
        RooMonk_JadeSerpentTracker.UpdateStatueDisplay(RooMonkCharDB)
    end

    -- Update cooldown tracker using external module
    if RooMonk_ExternalCooldownTracker then
        RooMonk_ExternalCooldownTracker.UpdateCooldownDisplay(RooMonkCharDB)
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitializeFrame()
        UpdateDisplay()

        -- Initialize addon communication and plan manager
        if RooMonk_AddonComm then
            RooMonk_AddonComm.Initialize()
        end

        if RooMonk_PlanManager then
            RooMonk_PlanManager.Initialize(RooMonkCharDB)
        end
    elseif event == "UNIT_AURA" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
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
frame:RegisterEvent("UNIT_AURA")
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
SLASH_ROOMONK1 = "/roomonk"
SLASH_ROOMONK2 = "/rm"
SlashCmdList["ROOMONK"] = function(msg)
    local args = ParseArgs(msg)
    local cmd = args[1] and string.lower(args[1]) or ""

    if cmd == "lock" then
        RooMonkCharDB.locked = true
        print("|cff00ff80RooMonk:|r Frame locked")
    elseif cmd == "unlock" then
        RooMonkCharDB.locked = false
        print("|cff00ff80RooMonk:|r Frame unlocked")
    elseif cmd == "mist" or cmd == "renewing" then
        RooMonkCharDB.showRenewingMist = not RooMonkCharDB.showRenewingMist
        if renewingMistFrame then
            if RooMonkCharDB.showRenewingMist then
                renewingMistFrame:Show()
                print("|cff00ff80RooMonk:|r Renewing Mist tracker shown")
            else
                renewingMistFrame:Hide()
                print("|cff00ff80RooMonk:|r Renewing Mist tracker hidden")
            end
        else
            print("|cff00ff80RooMonk:|r Renewing Mist tracker not available for this class")
        end
    elseif cmd == "statue" then
        RooMonkCharDB.showStatue = not RooMonkCharDB.showStatue
        if statueFrame then
            if RooMonkCharDB.showStatue then
                statueFrame:Show()
                print("|cff00ff80RooMonk:|r Statue tracker shown")
            else
                statueFrame:Hide()
                print("|cff00ff80RooMonk:|r Statue tracker hidden")
            end
        else
            print("|cff00ff80RooMonk:|r Statue tracker not available for this class")
        end
    elseif cmd == "cooldowns" or cmd == "cds" then
        RooMonkCharDB.showCooldowns = not RooMonkCharDB.showCooldowns
        if RooMonk_ExternalCooldownTracker then
            local shown = RooMonk_ExternalCooldownTracker.ToggleFrame()
            if shown then
                print("|cff00ff80RooMonk:|r Cooldown tracker shown")
            else
                print("|cff00ff80RooMonk:|r Cooldown tracker hidden")
            end
        end
    elseif cmd == "reset" then
        RooMonkCharDB.x = 100
        RooMonkCharDB.y = -100
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", RooMonkCharDB.x, RooMonkCharDB.y)
        print("|cff00ff80RooMonk:|r Position reset")

    -- Plan management commands
    elseif cmd == "plan" or cmd == "plans" then
        if RooMonk_PlanUI then
            RooMonk_PlanUI.Toggle()
        else
            print("|cff00ff80RooMonk:|r Plan UI not available")
        end
    elseif cmd == "newplan" then
        local planName = table.concat(args, " ", 2)
        if planName and planName ~= "" and RooMonk_PlanManager then
            local plan, err = RooMonk_PlanManager.CreatePlan(planName)
            if plan then
                print("|cff00ff80RooMonk:|r Created plan: " .. planName)
            else
                print("|cff00ff80RooMonk:|r " .. err)
            end
        else
            print("|cff00ff80RooMonk:|r Usage: /rm newplan <planName>")
        end
    elseif cmd == "addstep" then
        -- /rm addstep <planName> <order> <spellName> [caster]
        if #args >= 4 and RooMonk_PlanManager then
            local planName = args[2]
            local order = tonumber(args[3])
            local spellName = args[4]
            local caster = args[5]

            if RooMonk_PlanManager.AddStep(planName, order, spellName, caster) then
                print("|cff00ff80RooMonk:|r Added step to plan: " .. planName)
            else
                print("|cff00ff80RooMonk:|r Failed to add step")
            end
        else
            print("|cff00ff80RooMonk:|r Usage: /rm addstep <planName> <order> <spellName> [caster]")
        end
    elseif cmd == "shareplan" then
        local planName = table.concat(args, " ", 2)
        if planName and planName ~= "" and RooMonk_PlanManager and RooMonk_AddonComm then
            local exportData = RooMonk_PlanManager.ExportPlan(planName)
            if exportData then
                RooMonk_AddonComm.SharePlan(exportData)
            else
                print("|cff00ff80RooMonk:|r Plan not found: " .. planName)
            end
        else
            print("|cff00ff80RooMonk:|r Usage: /rm shareplan <planName>")
        end
    elseif cmd == "requestplans" then
        if RooMonk_AddonComm then
            RooMonk_AddonComm.RequestPlans()
        else
            print("|cff00ff80RooMonk:|r Addon communication not available")
        end
    elseif cmd == "viewplan" or cmd == "received" then
        if RooMonk_AddonComm then
            local receivedPlans = RooMonk_AddonComm.GetReceivedPlans()
            if next(receivedPlans) then
                print("|cff00ff80RooMonk - Received Plans:|r")
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
                print("|cff00ff80RooMonk:|r No plans received yet")
            end
        else
            print("|cff00ff80RooMonk:|r Addon communication not available")
        end
    elseif cmd == "listplans" then
        if RooMonk_PlanManager then
            local plans = RooMonk_PlanManager.GetAllPlans()
            if next(plans) then
                print("|cff00ff80RooMonk - My Plans:|r")
                for planName, plan in pairs(plans) do
                    local summary = RooMonk_PlanManager.GetPlanSummary(planName)
                    print("  " .. planName .. " (" .. summary.stepCount .. " steps)")
                    for i, step in ipairs(plan.steps) do
                        local casterText = step.caster and (" by " .. step.caster) or ""
                        local status = step.completed and "[X]" or "[ ]"
                        print("    " .. status .. " " .. step.order .. ". " .. step.spellName .. casterText)
                    end
                end
            else
                print("|cff00ff80RooMonk:|r No plans created yet")
            end
        else
            print("|cff00ff80RooMonk:|r Plan manager not available")
        end
    elseif cmd == "help" or cmd == "" then
        print("|cff00ff80RooMonk Commands:|r")
        print("  /rm lock - Lock the frame")
        print("  /rm unlock - Unlock the frame")
        print("  /rm mist (or renewing) - Toggle Renewing Mist tracker")
        print("  /rm statue - Toggle statue tracker")
        print("  /rm cooldowns (or cds) - Toggle cooldown tracker")
        print("  /rm reset - Reset position")
        print("  ")
        print("|cff00ff80Plan Management:|r")
        print("  /rm plan - Open plan manager UI")
        print("  /rm newplan <name> - Create a new plan")
        print("  /rm listplans - List all your plans")
        print("  /rm addstep <plan> <order> <spell> [caster] - Add step to plan")
        print("  /rm shareplan <name> - Share plan with group")
        print("  /rm requestplans - Request plans from group")
        print("  /rm viewplan - View received plans")
        print("  /rm help - Show this help")
    else
        print("|cff00ff80RooMonk:|r Unknown command. Type /rm help for commands.")
    end
end

print("|cff00ff80RooMonk|r loaded! Type /rm help for commands.")
