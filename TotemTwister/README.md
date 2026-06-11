# TotemTwister

A small WoW **TBC Classic** (2.5.x) addon that helps a **Shaman** twist between
**Windfury Totem** and **Grace of Air Totem** — the two air totems — to keep the
lingering Windfury proc buff up while also benefiting from Grace of Air's agility.

## What it does (and the important limitation)

WoW does **not** let an addon cast spells on its own. Casting is a *protected*
action that can only happen in response to a hardware event (a key press or
click) — Blizzard blocks the "auto-cast on a free GCD" behaviour specifically.

So TotemTwister gives you the next best thing:

1. **One secure button** (`TotemTwisterButton`). Each press casts the *next*
   totem in the twist sequence (Windfury → Grace of Air → Windfury → …). A secure
   handler flips which spell is cast, so the single button keeps working **in
   combat**. You twist by tapping one key.
2. **A timing HUD** that tells you *when* to tap — it shows the lingering
   Windfury buff timer, which air totem is currently down, whether the global
   cooldown is free, and a flashing **CAST WINDFURY / CAST GRACE OF AIR** prompt.

## Install

Copy the `TotemTwister` folder into your client's `Interface/AddOns/` directory
and enable it on a Shaman. (Non-Shaman characters load nothing.)

## Usage

Bind a key, then tap it whenever the HUD prompts you. There are three ways to
bind it (pick one):

1. **Key Bindings UI (recommended):** `Esc → Options → Key Bindings`, find the
   **TotemTwister** header, and set a key for *"Twist totem (Windfury / Grace of
   Air)"*.
2. **Slash shortcut:** `/tt bind T` binds the `T` key to the twist button.
3. **Macro:** `/click TotemTwisterButton`

### Slash commands (`/tt` or `/totemtwist`)

| Command            | Effect                              |
|--------------------|-------------------------------------|
| `/tt lock`         | Lock the HUD in place               |
| `/tt unlock`       | Unlock so you can drag the HUD      |
| `/tt show` `/hide` | Show / hide the HUD                 |
| `/tt reset`        | Recenter the HUD                    |
| `/tt bind <key>`   | Bind a key to the twist button      |

## How the recommendation works

- The HUD watches the **Windfury Totem** buff on you. When it is within ~2s of
  dropping (and the GCD is free), it flashes **CAST WINDFURY** to refresh it.
- Otherwise, if Grace of Air isn't your current air totem, it flashes **CAST
  GRACE OF AIR** so you pick up the agility while the Windfury buff lingers.
- **Out of combat** the addon steers the secure button so each press casts the
  recommended totem. **In combat** the button simply alternates each press.

## Caveat: in-combat desync

Because Blizzard forbids changing a secure button's spell during combat, the
in-combat button just **alternates** WF ↔ GoA on every press. If a press fails
(out of range, out of mana, or interrupted), the alternation can drift out of
sync with what's actually on the ground — tap once more to correct it. The addon
automatically re-syncs the moment you leave combat. This is an inherent limit of
secure totem twisting, not a bug.
