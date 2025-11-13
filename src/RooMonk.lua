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

-- Saved variables (per-character)
RooMonkCharDB = RooMonkCharDB or {
    locked = false,
    showRenewingMist = true,
    showStatue = true,
    showCooldowns = true,
    x = 100,
    y = -100
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
        listFrame = RooMonk_RenewingMistTracker.GetListFrame()
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
        RooMonkCharDB.locked = true
        print("|cff00ff80RooMonk:|r Frame locked")
    elseif msg == "unlock" then
        RooMonkCharDB.locked = false
        print("|cff00ff80RooMonk:|r Frame unlocked")
    elseif msg == "mist" or msg == "renewing" then
        RooMonkCharDB.showRenewingMist = not RooMonkCharDB.showRenewingMist
        if renewingMistFrame and listFrame then
            if RooMonkCharDB.showRenewingMist then
                renewingMistFrame:Show()
                listFrame:Show()
                print("|cff00ff80RooMonk:|r Renewing Mist tracker shown")
            else
                renewingMistFrame:Hide()
                listFrame:Hide()
                print("|cff00ff80RooMonk:|r Renewing Mist tracker hidden")
            end
        else
            print("|cff00ff80RooMonk:|r Renewing Mist tracker not available for this class")
        end
    elseif msg == "statue" then
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
    elseif msg == "cooldowns" or msg == "cds" then
        RooMonkCharDB.showCooldowns = not RooMonkCharDB.showCooldowns
        if RooMonk_ExternalCooldownTracker then
            local shown = RooMonk_ExternalCooldownTracker.ToggleFrame()
            if shown then
                print("|cff00ff80RooMonk:|r Cooldown tracker shown")
            else
                print("|cff00ff80RooMonk:|r Cooldown tracker hidden")
            end
        end
    elseif msg == "reset" then
        RooMonkCharDB.x = 100
        RooMonkCharDB.y = -100
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", RooMonkCharDB.x, RooMonkCharDB.y)
        print("|cff00ff80RooMonk:|r Position reset")
    elseif msg == "help" or msg == "" then
        print("|cff00ff80RooMonk Commands:|r")
        print("  /rm lock - Lock the frame")
        print("  /rm unlock - Unlock the frame")
        print("  /rm mist (or renewing) - Toggle Renewing Mist tracker")
        print("  /rm statue - Toggle statue tracker")
        print("  /rm cooldowns (or cds) - Toggle cooldown tracker")
        print("  /rm reset - Reset position")
        print("  /rm help - Show this help")
    else
        print("|cff00ff80RooMonk:|r Unknown command. Type /rm help for commands.")
    end
end

print("|cff00ff80RooMonk|r loaded! Type /rm help for commands.")
