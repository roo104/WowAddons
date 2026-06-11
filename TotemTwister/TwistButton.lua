-- TotemTwister: Secure one-button totem twister
-- Compatible with WoW TBC Classic (2.5.x)
--
-- Casting spells is a PROTECTED action in WoW: it can only happen in response
-- to a hardware event (key press / mouse click). We therefore cannot auto-cast
-- on a free GCD. Instead this module exposes a single SecureActionButton that,
-- on every press, casts the *next* totem in the twist sequence
-- (Windfury Totem -> Grace of Air Totem -> Windfury Totem -> ...).
--
-- A secure pre-click snippet flips which spell is cast. Because it runs in the
-- restricted (secure) environment, it keeps working IN COMBAT, where insecure
-- SetAttribute calls are forbidden.

---@diagnostic disable: undefined-global

local TwistButton = {}

-- Spell names: casting by name auto-selects the highest known rank.
local WINDFURY_TOTEM = "Windfury Totem"
local GRACE_OF_AIR_TOTEM = "Grace of Air Totem"

local button = nil

-- Build the secure button. MUST be called out of combat (PLAYER_LOGIN is fine).
local function CreateButton()
    if button then
        return button
    end

    button = CreateFrame("Button", "TotemTwisterButton", UIParent, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyDown")

    -- Base attributes (set out of combat).
    button:SetAttribute("type", "spell")
    button:SetAttribute("wfspell", WINDFURY_TOTEM)
    button:SetAttribute("goaspell", GRACE_OF_AIR_TOTEM)
    button:SetAttribute("nexttotem", "wf")
    -- Seed the spell so the very first press already has a valid target.
    button:SetAttribute("spell", WINDFURY_TOTEM)

    -- Secure pre-click snippet: choose the spell for THIS press, then flip the
    -- toggle for the next press. Runs in the secure environment => combat-safe.
    SecureHandlerWrapScript(button, "OnClick", button, [[
        local nt = self:GetAttribute("nexttotem")
        if nt == "wf" then
            self:SetAttribute("spell", self:GetAttribute("wfspell"))
            self:SetAttribute("nexttotem", "goa")
        else
            self:SetAttribute("spell", self:GetAttribute("goaspell"))
            self:SetAttribute("nexttotem", "wf")
        end
    ]])

    return button
end

-- Insecure read of the toggle (reading attributes is always allowed).
-- Returns "wf" or "goa": the totem the next press will cast.
local function GetNextTotem()
    if not button then
        return "wf"
    end
    return button:GetAttribute("nexttotem") or "wf"
end

-- Resync the toggle to reality. Only possible out of combat (insecure
-- SetAttribute is blocked in combat). expectedNext is "wf" or "goa".
--
-- A blind toggle can drift if a press fails (out of range / OOM / interrupted),
-- so we re-anchor it between pulls based on which air totem is actually down.
local function ResyncOutOfCombat(expectedNext)
    if not button then
        return
    end
    if InCombatLockdown() then
        return
    end
    button:SetAttribute("nexttotem", expectedNext or "wf")
end

-- Bind a key directly to the twist button (out of combat only).
-- Alternatively the user can use a macro: /click TotemTwisterButton
local function BindKey(key)
    if not button then
        return false, "Button not created yet"
    end
    if InCombatLockdown() then
        return false, "Cannot change key bindings in combat"
    end
    if not key or key == "" then
        return false, "No key specified"
    end
    SetBindingClick(string.upper(key), "TotemTwisterButton")
    SaveBindings(GetCurrentBindingSet())
    return true
end

TwistButton.CreateButton = CreateButton
TwistButton.GetNextTotem = GetNextTotem
TwistButton.ResyncOutOfCombat = ResyncOutOfCombat
TwistButton.BindKey = BindKey
TwistButton.WINDFURY_TOTEM = WINDFURY_TOTEM
TwistButton.GRACE_OF_AIR_TOTEM = GRACE_OF_AIR_TOTEM

TotemTwister_TwistButton = TwistButton
