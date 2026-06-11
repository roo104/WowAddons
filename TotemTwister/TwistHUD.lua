-- TotemTwister: Timing HUD
-- Compatible with WoW TBC Classic (2.5.x)
--
-- The HUD does not cast anything. It tells the player WHEN to tap the twist
-- key by combining three signals:
--   * the lingering "Windfury Totem" buff remaining on the player,
--   * which air totem is currently down (GetTotemInfo),
--   * whether the global cooldown is free (GetSpellCooldown).

---@diagnostic disable: undefined-global

local HUD = {}

local FRAME_WIDTH = 200
local FRAME_HEIGHT = 110

-- Refresh the lingering Windfury buff once it drops below this many seconds.
local WF_REFRESH_THRESHOLD = 2.0
-- A totem GCD is ~1.5s; treat anything longer as a real cooldown, not the GCD.
local GCD_MAX = 1.5

-- Colors
local COLOR_WF = { 0.30, 0.60, 1.00 }   -- blue-ish (Windfury)
local COLOR_GOA = { 0.30, 1.00, 0.40 }  -- green (Grace of Air / agility)
local COLOR_IDLE = { 0.70, 0.70, 0.70 }

local hudFrame = nil
local flashElapsed = 0

-- Find a buff on the player by (partial) name. Returns remaining seconds, or 0.
local function GetBuffRemaining(name)
    if AuraUtil and AuraUtil.FindAuraByName then
        -- Returns the UnitAura tuple: name(1) icon(2) count(3) dispelType(4)
        -- duration(5) expirationTime(6) ...
        local found = { AuraUtil.FindAuraByName(name, "player", "HELPFUL") }
        local expirationTime = found[6]
        if expirationTime and expirationTime > 0 then
            return expirationTime - GetTime()
        end
        return 0
    end

    -- Fallback manual scan (older Classic builds).
    for i = 1, 40 do
        local buffName, _, _, _, _, expirationTime = UnitBuff("player", i)
        if not buffName then
            break
        end
        if buffName == name then
            if expirationTime and expirationTime > 0 then
                return expirationTime - GetTime()
            end
            return 0
        end
    end
    return 0
end

-- Scan the four totem slots for an air totem. Returns "wf"|"goa"|nil and the
-- remaining seconds. Slot-agnostic so we don't depend on slot ordering.
local function GetAirTotem()
    local wf = TotemTwister_TwistButton.WINDFURY_TOTEM
    local goa = TotemTwister_TwistButton.GRACE_OF_AIR_TOTEM
    for slot = 1, 4 do
        local haveTotem, totemName, startTime, duration = GetTotemInfo(slot)
        if haveTotem and totemName and totemName ~= "" then
            local remaining = 0
            if startTime and duration and duration > 0 then
                remaining = (startTime + duration) - GetTime()
            end
            if string.find(totemName, "Windfury", 1, true) then
                return "wf", remaining, totemName
            elseif string.find(totemName, "Grace of Air", 1, true) then
                return "goa", remaining, totemName
            end
        end
    end
    return nil, 0, nil
end

-- Is the global cooldown free right now?
local function IsGCDFree()
    local start, duration = GetSpellCooldown(TotemTwister_TwistButton.WINDFURY_TOTEM)
    if not start or start == 0 then
        return true
    end
    if duration and duration > GCD_MAX then
        -- A genuine cooldown, not the GCD (shouldn't happen for these totems).
        return false
    end
    return (start + duration) <= GetTime()
end

local function CreateHUD(db)
    if hudFrame then
        return hudFrame
    end

    hudFrame = CreateFrame("Frame", "TotemTwisterHUD", UIParent)
    hudFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    hudFrame:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 0)
    hudFrame:SetClampedToScreen(true)
    hudFrame:SetMovable(true)
    hudFrame:EnableMouse(not db.locked)
    hudFrame:RegisterForDrag("LeftButton")

    hudFrame:SetScript("OnDragStart", function(self)
        if not db.locked then
            self:StartMoving()
        end
    end)
    hudFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        db.x = x
        db.y = y
    end)

    -- Background
    hudFrame.bg = hudFrame:CreateTexture(nil, "BACKGROUND")
    hudFrame.bg:SetAllPoints()
    hudFrame.bg:SetColorTexture(0, 0, 0, 0.7)

    -- Title bar
    hudFrame.titleBg = hudFrame:CreateTexture(nil, "BORDER")
    hudFrame.titleBg:SetPoint("TOPLEFT", 0, 0)
    hudFrame.titleBg:SetPoint("TOPRIGHT", 0, 0)
    hudFrame.titleBg:SetHeight(20)
    hudFrame.titleBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

    hudFrame.title = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudFrame.title:SetPoint("TOP", 0, -4)
    hudFrame.title:SetText("|cff66ccffTotemTwister|r")

    -- Big recommendation line
    hudFrame.recommend = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hudFrame.recommend:SetPoint("TOP", 0, -26)
    hudFrame.recommend:SetText("")

    -- Windfury buff status bar
    hudFrame.wfBar = CreateFrame("StatusBar", nil, hudFrame)
    hudFrame.wfBar:SetSize(FRAME_WIDTH - 20, 14)
    hudFrame.wfBar:SetPoint("TOP", 0, -52)
    hudFrame.wfBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hudFrame.wfBar:SetStatusBarColor(COLOR_WF[1], COLOR_WF[2], COLOR_WF[3])
    hudFrame.wfBar:SetMinMaxValues(0, 1)
    hudFrame.wfBar:SetValue(0)
    hudFrame.wfBar.bg = hudFrame.wfBar:CreateTexture(nil, "BACKGROUND")
    hudFrame.wfBar.bg:SetAllPoints()
    hudFrame.wfBar.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    hudFrame.wfBar.label = hudFrame.wfBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hudFrame.wfBar.label:SetPoint("CENTER")
    hudFrame.wfBar.label:SetText("WF buff")

    -- Air totem line
    hudFrame.airText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hudFrame.airText:SetPoint("TOP", 0, -70)
    hudFrame.airText:SetText("")

    -- Next-press + GCD line
    hudFrame.statusText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hudFrame.statusText:SetPoint("BOTTOM", 0, 6)
    hudFrame.statusText:SetText("")

    HUD.frame = hudFrame
    return hudFrame
end

-- Refresh the HUD. Returns the recommended next action ("wf"|"goa"|nil) so the
-- main file can resync the secure button's toggle when out of combat.
local function Update(db, elapsed)
    if not hudFrame then
        return nil
    end

    local wfRemaining = GetBuffRemaining(TotemTwister_TwistButton.WINDFURY_TOTEM)
    local airKind, airRemaining, airName = GetAirTotem()
    local gcdFree = IsGCDFree()
    local nextPress = TotemTwister_TwistButton.GetNextTotem()

    -- Recommendation: keep the Windfury buff alive first, then sit on Grace of Air.
    local recommend
    if wfRemaining <= WF_REFRESH_THRESHOLD then
        recommend = "wf"
    elseif airKind ~= "goa" then
        recommend = "goa"
    else
        recommend = nil -- both covered; wait
    end

    -- Recommendation text + color
    if recommend == "wf" then
        hudFrame.recommend:SetText("CAST WINDFURY")
        hudFrame.recommend:SetTextColor(COLOR_WF[1], COLOR_WF[2], COLOR_WF[3])
    elseif recommend == "goa" then
        hudFrame.recommend:SetText("CAST GRACE OF AIR")
        hudFrame.recommend:SetTextColor(COLOR_GOA[1], COLOR_GOA[2], COLOR_GOA[3])
    else
        hudFrame.recommend:SetText("twist OK")
        hudFrame.recommend:SetTextColor(COLOR_IDLE[1], COLOR_IDLE[2], COLOR_IDLE[3])
    end

    -- Flash the recommendation when it is actionable and the GCD is free.
    if recommend and gcdFree then
        flashElapsed = (flashElapsed or 0) + (elapsed or 0)
        local alpha = 0.55 + 0.45 * math.abs(math.sin(flashElapsed * 4))
        hudFrame.recommend:SetAlpha(alpha)
    else
        flashElapsed = 0
        hudFrame.recommend:SetAlpha(recommend and 1.0 or 0.5)
    end

    -- Windfury buff bar (cap display at 15s, a typical WF buff window).
    local wfMax = 15
    if wfRemaining > 0 then
        hudFrame.wfBar:SetValue(math.min(wfRemaining / wfMax, 1))
        hudFrame.wfBar.label:SetText(string.format("WF buff: %.1fs", wfRemaining))
    else
        hudFrame.wfBar:SetValue(0)
        hudFrame.wfBar.label:SetText("WF buff: --")
    end

    -- Air totem line
    if airKind and airRemaining > 0 then
        hudFrame.airText:SetText(string.format("Air: %s (%.0fs)", airName or "?", airRemaining))
    else
        hudFrame.airText:SetText("Air: none")
    end

    -- Next press + GCD
    local nextLabel = (nextPress == "wf") and "|cff4d99ffWF|r" or "|cff4dff66GoA|r"
    local gcdLabel = gcdFree and "|cff33ff33GCD READY|r" or "|cffff6666GCD|r"
    hudFrame.statusText:SetText("Next: " .. nextLabel .. "   " .. gcdLabel)

    return recommend
end

local function SetLocked(locked)
    if hudFrame then
        hudFrame:EnableMouse(not locked)
    end
end

local function SetShown(shown)
    if hudFrame then
        if shown then
            hudFrame:Show()
        else
            hudFrame:Hide()
        end
    end
end

local function ResetPosition(db)
    if hudFrame then
        hudFrame:ClearAllPoints()
        hudFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        db.x = 0
        db.y = 0
    end
end

HUD.CreateHUD = CreateHUD
HUD.Update = Update
HUD.SetLocked = SetLocked
HUD.SetShown = SetShown
HUD.ResetPosition = ResetPosition

TotemTwister_TwistHUD = HUD
