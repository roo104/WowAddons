---@diagnostic disable: unnecessary-if
-- RooMonk: Renewing Mist Tracker for Mistweaver Monks
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

local ADDON_NAME = "RooMonk"

-- Frame variables
local frame = CreateFrame("Frame", "RooMonkFrame", UIParent)
local renewingMistFrame = nil
local listFrame = nil
local statueFrame = nil
local cooldownFrame = nil
local updateTimer = 0
local UPDATE_INTERVAL = 0.25 -- Update every 0.25 seconds

-- Saved variables
RooMonkDB = RooMonkDB or {
    locked = false,
    showList = true,
    showStatue = true,
    showCooldowns = true,
    x = 100,
    y = -100
}

-- Initialize the main frame
local function InitializeFrame()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", RooMonkDB.x, RooMonkDB.y)

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    -- Drag handlers
    frame:SetScript("OnDragStart", function(self)
        if not RooMonkDB.locked then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        RooMonkDB.x = x
        RooMonkDB.y = y
    end)

    -- Create Renewing Mist tracking frame using external module
    if RooMonk_RenewingMistTracker then
        renewingMistFrame = RooMonk_RenewingMistTracker.CreateRenewingMistFrame(frame, RooMonkDB)
        listFrame = RooMonk_RenewingMistTracker.GetListFrame()
    end

    -- Create statue frame using external module
    if RooMonk_JadeSerpentTracker then
        statueFrame = RooMonk_JadeSerpentTracker.CreateStatueFrame(frame, RooMonkDB)
    end

    -- Create cooldown tracker frame using external module
    if RooMonk_ExternalCooldownTracker then
        cooldownFrame = RooMonk_ExternalCooldownTracker.CreateCooldownTrackerFrame(frame, RooMonkDB)
    end
end

-- Update the display
local function UpdateDisplay()
    -- Update Renewing Mist display using external module
    if RooMonk_RenewingMistTracker then
        RooMonk_RenewingMistTracker.UpdateDisplay(RooMonkDB)
    end

    -- Update statue display using external module
    if RooMonk_JadeSerpentTracker then
        RooMonk_JadeSerpentTracker.UpdateStatueDisplay(RooMonkDB)
    end

    -- Update cooldown tracker using external module
    if RooMonk_ExternalCooldownTracker then
        RooMonk_ExternalCooldownTracker.UpdateCooldownDisplay(RooMonkDB)
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitializeFrame()
        UpdateDisplay()
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

-- Slash commands
SLASH_ROOMONK1 = "/roomonk"
SLASH_ROOMONK2 = "/rm"
SlashCmdList["ROOMONK"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "lock" then
        RooMonkDB.locked = true
        print("|cff00ff80RooMonk:|r Frame locked")
    elseif msg == "unlock" then
        RooMonkDB.locked = false
        print("|cff00ff80RooMonk:|r Frame unlocked")
    elseif msg == "list" then
        RooMonkDB.showList = not RooMonkDB.showList
        if RooMonkDB.showList then
            listFrame:Show()
            print("|cff00ff80RooMonk:|r List shown")
        else
            listFrame:Hide()
            print("|cff00ff80RooMonk:|r List hidden")
        end
    elseif msg == "statue" then
        RooMonkDB.showStatue = not RooMonkDB.showStatue
        if RooMonkDB.showStatue then
            statueFrame:Show()
            print("|cff00ff80RooMonk:|r Statue tracker shown")
        else
            statueFrame:Hide()
            print("|cff00ff80RooMonk:|r Statue tracker hidden")
        end
    elseif msg == "cooldowns" or msg == "cds" then
        RooMonkDB.showCooldowns = not RooMonkDB.showCooldowns
        if RooMonk_ExternalCooldownTracker then
            local shown = RooMonk_ExternalCooldownTracker.ToggleFrame()
            if shown then
                print("|cff00ff80RooMonk:|r Cooldown tracker shown")
            else
                print("|cff00ff80RooMonk:|r Cooldown tracker hidden")
            end
        end
    elseif msg == "reset" then
        RooMonkDB.x = 100
        RooMonkDB.y = -100
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", RooMonkDB.x, RooMonkDB.y)
        print("|cff00ff80RooMonk:|r Position reset")
    elseif msg == "help" or msg == "" then
        print("|cff00ff80RooMonk Commands:|r")
        print("  /rm lock - Lock the frame")
        print("  /rm unlock - Unlock the frame")
        print("  /rm list - Toggle player list")
        print("  /rm statue - Toggle statue tracker")
        print("  /rm cooldowns (or cds) - Toggle cooldown tracker")
        print("  /rm reset - Reset position")
        print("  /rm help - Show this help")
    else
        print("|cff00ff80RooMonk:|r Unknown command. Type /rm help for commands.")
    end
end

print("|cff00ff80RooMonk|r loaded! Type /rm help for commands.")
