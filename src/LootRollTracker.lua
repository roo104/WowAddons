-- LootRollTracker.lua
-- Tracks and displays players who roll need on loot

NordensParis_LootRollTracker = {}
local LootRollTracker = NordensParis_LootRollTracker

-- Active roll tracking
local activeRolls = {} -- { [rollID] = { itemLink, needRollers = {name1, name2}, greedRollers = {}, passedRollers = {} } }
local displayFrame = nil
local rollFrames = {} -- Individual frames for each active roll
local autoShowEnabled = true -- Whether to auto-show/hide based on active rolls
local rollTimeouts = {} -- Track when rolls started
local rollCompletionTimes = {} -- Track when rolls completed (to keep display for 5 sec)

-- Constants
local FRAME_WIDTH = 250
local ROLL_HEIGHT = 80
local PADDING = 5

-- Create the main container frame
local function CreateMainFrame()
    if displayFrame then return displayFrame end

    displayFrame = CreateFrame("Frame", "NordensParisLootRollFrame", UIParent)
    displayFrame:SetSize(FRAME_WIDTH, 100)
    displayFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    displayFrame:EnableMouse(true)
    displayFrame:SetMovable(true)
    displayFrame:RegisterForDrag("LeftButton")
    displayFrame:SetClampedToScreen(true)

    -- Background
    displayFrame.bg = displayFrame:CreateTexture(nil, "BACKGROUND")
    displayFrame.bg:SetAllPoints()
    displayFrame.bg:SetColorTexture(0, 0, 0, 0.8)

    -- Title bar background
    displayFrame.titleBg = displayFrame:CreateTexture(nil, "BORDER")
    displayFrame.titleBg:SetPoint("TOPLEFT", 0, 0)
    displayFrame.titleBg:SetPoint("TOPRIGHT", 0, 0)
    displayFrame.titleBg:SetHeight(25)
    displayFrame.titleBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

    -- Title text
    displayFrame.title = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayFrame.title:SetPoint("TOP", 0, -5)
    displayFrame.title:SetText("|cff00ff80Loot Rolls|r")

    -- Close button
    displayFrame.closeButton = CreateFrame("Button", nil, displayFrame, "UIPanelCloseButton")
    displayFrame.closeButton:SetSize(20, 20)
    displayFrame.closeButton:SetPoint("TOPRIGHT", -3, -3)
    displayFrame.closeButton:SetScript("OnClick", function()
        displayFrame:Hide()
        autoShowEnabled = true -- Re-enable auto-show when closed
    end)

    -- Drag handlers
    displayFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    displayFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    displayFrame:Hide()
    return displayFrame
end

-- Create a frame for an individual roll
local function CreateRollFrame(rollID, itemLink)
    if not displayFrame then
        CreateMainFrame()
    end

    local rollFrame = CreateFrame("Frame", nil, displayFrame)
    rollFrame:SetSize(FRAME_WIDTH - (PADDING * 2), ROLL_HEIGHT)

    -- Background
    rollFrame.bg = rollFrame:CreateTexture(nil, "BACKGROUND")
    rollFrame.bg:SetAllPoints()
    rollFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

    -- Item link (clickable)
    rollFrame.itemLink = rollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollFrame.itemLink:SetPoint("TOPLEFT", 5, -5)
    rollFrame.itemLink:SetJustifyH("LEFT")
    rollFrame.itemLink:SetWidth(FRAME_WIDTH - 20)
    rollFrame.itemLink:SetText(itemLink)

    -- Need rollers section
    rollFrame.needLabel = rollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollFrame.needLabel:SetPoint("TOPLEFT", 5, -25)
    rollFrame.needLabel:SetText("|cff00ff00Need:|r")

    rollFrame.needText = rollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollFrame.needText:SetPoint("TOPLEFT", 50, -25)
    rollFrame.needText:SetJustifyH("LEFT")
    rollFrame.needText:SetWidth(FRAME_WIDTH - 60)
    rollFrame.needText:SetText("-")

    -- Greed rollers section
    rollFrame.greedLabel = rollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollFrame.greedLabel:SetPoint("TOPLEFT", 5, -40)
    rollFrame.greedLabel:SetText("|cffffd700Greed:|r")

    rollFrame.greedText = rollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollFrame.greedText:SetPoint("TOPLEFT", 50, -40)
    rollFrame.greedText:SetJustifyH("LEFT")
    rollFrame.greedText:SetWidth(FRAME_WIDTH - 60)
    rollFrame.greedText:SetText("-")

    -- Pass section
    rollFrame.passLabel = rollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollFrame.passLabel:SetPoint("TOPLEFT", 5, -55)
    rollFrame.passLabel:SetText("|cffaaaaaaPass:|r")

    rollFrame.passText = rollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollFrame.passText:SetPoint("TOPLEFT", 50, -55)
    rollFrame.passText:SetJustifyH("LEFT")
    rollFrame.passText:SetWidth(FRAME_WIDTH - 60)
    rollFrame.passText:SetText("-")

    rollFrames[rollID] = rollFrame
    return rollFrame
end

-- Update the display of all roll frames
local function UpdateRollFramesLayout()
    if not displayFrame then return end

    local yOffset = -30
    local visibleCount = 0

    for rollID, rollFrame in pairs(rollFrames) do
        if activeRolls[rollID] then
            rollFrame:ClearAllPoints()
            rollFrame:SetPoint("TOPLEFT", displayFrame, "TOPLEFT", PADDING, yOffset)
            rollFrame:Show()
            yOffset = yOffset - (ROLL_HEIGHT + PADDING)
            visibleCount = visibleCount + 1
        else
            rollFrame:Hide()
        end
    end

    if visibleCount > 0 then
        displayFrame:SetHeight(40 + (visibleCount * (ROLL_HEIGHT + PADDING)))
        if autoShowEnabled then
            displayFrame:Show()
        end
    else
        if autoShowEnabled then
            displayFrame:Hide()
        else
            -- Keep frame visible but just resize to show title only
            displayFrame:SetHeight(40)
        end
    end
end

-- Update a specific roll frame's text
local function UpdateRollFrame(rollID)
    local rollData = activeRolls[rollID]
    local rollFrame = rollFrames[rollID]

    if not rollData or not rollFrame then return end

    -- Update need rollers
    if #rollData.needRollers > 0 then
        rollFrame.needText:SetText(table.concat(rollData.needRollers, ", "))
    else
        rollFrame.needText:SetText("-")
    end

    -- Update greed rollers
    if #rollData.greedRollers > 0 then
        rollFrame.greedText:SetText(table.concat(rollData.greedRollers, ", "))
    else
        rollFrame.greedText:SetText("-")
    end

    -- Update pass
    if #rollData.passedRollers > 0 then
        rollFrame.passText:SetText(table.concat(rollData.passedRollers, ", "))
    else
        rollFrame.passText:SetText("-")
    end
end

-- Event: START_LOOT_ROLL
local function OnStartLootRoll(rollID, rollTime)
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollID)

    if not name then return end

    local itemLink = GetLootRollItemLink(rollID)

    -- Initialize tracking for this roll
    activeRolls[rollID] = {
        itemLink = itemLink,
        itemName = name,
        needRollers = {},
        greedRollers = {},
        passedRollers = {}
    }

    -- Track when this roll will timeout (rollTime is in seconds)
    rollTimeouts[rollID] = GetTime() + (rollTime or 100)

    -- Create UI frame for this roll
    CreateRollFrame(rollID, itemLink)
    UpdateRollFramesLayout()

    -- Start a timer to watch for chat messages about this roll
    local frame = CreateFrame("Frame")
    frame.rollID = rollID
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:SetScript("OnEvent", function(self, event, message, sender)
        local rollData = activeRolls[self.rollID]
        if not rollData then
            self:UnregisterEvent("CHAT_MSG_LOOT")
            return
        end

        -- Parse chat for roll information
        -- Look for patterns like "PlayerName has selected Need for: [Item]"
        local playerName, rollType = message:match("(.+) has selected (%a+) for")
        if playerName and rollType and message:find(rollData.itemName, 1, true) then
            -- Remove realm name if present
            playerName = playerName:match("([^-]+)") or playerName

            -- Check if already tracked
            local found = false
            for _, n in ipairs(rollData.needRollers) do
                if n == playerName then found = true break end
            end
            if not found then
                for _, n in ipairs(rollData.greedRollers) do
                    if n == playerName then found = true break end
                end
            end
            if not found then
                for _, n in ipairs(rollData.passedRollers) do
                    if n == playerName then found = true break end
                end
            end

            if not found then
                if rollType == "Need" then
                    table.insert(rollData.needRollers, playerName)
                    UpdateRollFrame(self.rollID)
                elseif rollType == "Greed" then
                    table.insert(rollData.greedRollers, playerName)
                    UpdateRollFrame(self.rollID)
                elseif rollType == "Pass" then
                    table.insert(rollData.passedRollers, playerName)
                    UpdateRollFrame(self.rollID)
                end
            end
        end
    end)
end

-- Polling timer to check roll status and detect finished rolls
local pollingTimer = 0
local POLLING_INTERVAL = 0.5

local function OnUpdate(self, elapsed)
    pollingTimer = pollingTimer + elapsed
    if pollingTimer >= POLLING_INTERVAL then
        pollingTimer = 0
        local currentTime = GetTime()

        -- Check each active roll for updates
        for rollID, rollData in pairs(activeRolls) do
            -- Check if roll has timed out (default roll time is typically 100 seconds, but can be less)
            if rollTimeouts[rollID] and currentTime > rollTimeouts[rollID] then
                -- Roll finished, mark completion time if not already marked
                if not rollCompletionTimes[rollID] then
                    rollCompletionTimes[rollID] = currentTime
                end
            else
                -- Try to get updated roll info
                local texture, name = GetLootRollItemInfo(rollID)
                if not name then
                    -- Roll no longer exists, mark completion time if not already marked
                    if not rollCompletionTimes[rollID] then
                        rollCompletionTimes[rollID] = currentTime
                    end
                end
            end
        end

        -- Check if any completed rolls can be removed (after 5 second delay)
        for rollID, completionTime in pairs(rollCompletionTimes) do
            if currentTime > completionTime + 5 then
                -- Remove roll after 5 second delay
                activeRolls[rollID] = nil
                rollTimeouts[rollID] = nil
                rollCompletionTimes[rollID] = nil
                if rollFrames[rollID] then
                    rollFrames[rollID]:Hide()
                    rollFrames[rollID] = nil
                end
                UpdateRollFramesLayout()
            end
        end
    end
end

-- Event: CANCEL_LOOT_ROLL
local function OnCancelLootRoll(rollID)
    if activeRolls[rollID] then
        -- Mark completion time instead of immediately removing
        if not rollCompletionTimes[rollID] then
            rollCompletionTimes[rollID] = GetTime()
        end
    end
end

-- Initialize the tracker
function LootRollTracker.Initialize()
    CreateMainFrame()

    -- Register events (only the ones that exist in Classic MoP)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("START_LOOT_ROLL")
    eventFrame:RegisterEvent("CANCEL_LOOT_ROLL")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "START_LOOT_ROLL" then
            OnStartLootRoll(...)
        elseif event == "CANCEL_LOOT_ROLL" then
            OnCancelLootRoll(...)
        end
    end)

    -- Set up polling to detect finished rolls
    eventFrame:SetScript("OnUpdate", OnUpdate)
end

-- Toggle visibility
function LootRollTracker.Toggle()
    if not displayFrame then
        CreateMainFrame()
    end

    if displayFrame:IsShown() then
        displayFrame:Hide()
        autoShowEnabled = true -- Re-enable auto-show when manually hidden
        return false
    else
        autoShowEnabled = false -- Disable auto-hide when manually shown
        displayFrame:Show()
        UpdateRollFramesLayout() -- Update to current state
        return true
    end
end

-- Check if visible
function LootRollTracker.IsVisible()
    return displayFrame and displayFrame:IsShown()
end
