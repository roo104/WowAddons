-- TotemTwister: main entry point
-- Compatible with WoW TBC Classic (2.5.x)
--
-- Helps a Shaman twist between Windfury Totem and Grace of Air Totem using a
-- single secure keybind (see TwistButton.lua) plus a timing HUD (TwistHUD.lua).
--
-- NOTE: This addon never casts on its own. WoW only allows spell casts from a
-- hardware event, so you twist by tapping one bound key; the addon decides which
-- totem that press casts and shows you when to press.

---@diagnostic disable: undefined-global

-- Display text for the Key Bindings UI (Esc > Key Bindings > TotemTwister).
-- Defined before the class guard so the names always render correctly.
BINDING_HEADER_TOTEMTWISTER = "TotemTwister"
BINDING_NAME_TOTEMTWISTER_TWIST = "Twist totem (Windfury / Grace of Air)"

-- Only Shamans need this addon. Stay completely dormant for everyone else.
local _, class = UnitClass("player")
if class ~= "SHAMAN" then
    return
end

local UPDATE_INTERVAL = 0.05 -- HUD refresh cadence (responsive flashing)

-- Saved variables (per-character).
TotemTwisterDB = TotemTwisterDB or {
    locked = false,
    x = 0,
    y = 0,
    shown = true,
}

local frame = CreateFrame("Frame", "TotemTwisterFrame", UIParent)
local updateTimer = 0
local initialized = false

local function Initialize()
    if initialized then
        return
    end
    initialized = true

    -- Secure button must be created out of combat.
    if TotemTwister_TwistButton then
        TotemTwister_TwistButton.CreateButton()
    end

    if TotemTwister_TwistHUD then
        TotemTwister_TwistHUD.CreateHUD(TotemTwisterDB)
        TotemTwister_TwistHUD.SetLocked(TotemTwisterDB.locked)
        TotemTwister_TwistHUD.SetShown(TotemTwisterDB.shown)
    end
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Initialize()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Just left combat: re-anchor the toggle to what's actually recommended.
        if TotemTwister_TwistHUD then
            local recommend = TotemTwister_TwistHUD.Update(TotemTwisterDB, 0)
            if recommend and TotemTwister_TwistButton then
                TotemTwister_TwistButton.ResyncOutOfCombat(recommend)
            end
        end
    end
end

local function OnUpdate(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer < UPDATE_INTERVAL then
        return
    end
    local delta = updateTimer
    updateTimer = 0

    if not TotemTwister_TwistHUD then
        return
    end

    local recommend = TotemTwister_TwistHUD.Update(TotemTwisterDB, delta)

    -- Out of combat we can steer the secure button so each press casts the
    -- recommended totem. In combat the button free-runs (alternates).
    if recommend and TotemTwister_TwistButton and not InCombatLockdown() then
        TotemTwister_TwistButton.ResyncOutOfCombat(recommend)
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", OnEvent)
frame:SetScript("OnUpdate", OnUpdate)

-- Slash commands ------------------------------------------------------------

local function PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTotemTwister:|r " .. msg)
end

local function PrintHelp()
    PrintMsg("commands:")
    PrintMsg("  /tt lock | unlock  - toggle moving the HUD")
    PrintMsg("  /tt show | hide    - show or hide the HUD")
    PrintMsg("  /tt reset          - recenter the HUD")
    PrintMsg("  /tt bind <key>     - bind a key to the twist button")
    PrintMsg("  (or macro: /click TotemTwisterButton)")
end

SLASH_TOTEMTWISTER1 = "/totemtwist"
SLASH_TOTEMTWISTER2 = "/tt"
SlashCmdList["TOTEMTWISTER"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if cmd == "lock" then
        TotemTwisterDB.locked = true
        if TotemTwister_TwistHUD then TotemTwister_TwistHUD.SetLocked(true) end
        PrintMsg("HUD locked.")
    elseif cmd == "unlock" then
        TotemTwisterDB.locked = false
        if TotemTwister_TwistHUD then TotemTwister_TwistHUD.SetLocked(false) end
        PrintMsg("HUD unlocked - drag to move.")
    elseif cmd == "show" then
        TotemTwisterDB.shown = true
        if TotemTwister_TwistHUD then TotemTwister_TwistHUD.SetShown(true) end
        PrintMsg("HUD shown.")
    elseif cmd == "hide" then
        TotemTwisterDB.shown = false
        if TotemTwister_TwistHUD then TotemTwister_TwistHUD.SetShown(false) end
        PrintMsg("HUD hidden.")
    elseif cmd == "reset" then
        if TotemTwister_TwistHUD then TotemTwister_TwistHUD.ResetPosition(TotemTwisterDB) end
        PrintMsg("HUD position reset.")
    elseif cmd == "bind" then
        if TotemTwister_TwistButton then
            local ok, err = TotemTwister_TwistButton.BindKey(rest)
            if ok then
                PrintMsg("Bound " .. string.upper(rest) .. " to the twist button.")
            else
                PrintMsg("Bind failed: " .. (err or "unknown error"))
            end
        end
    else
        PrintHelp()
    end
end
