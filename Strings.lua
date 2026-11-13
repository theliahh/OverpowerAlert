local ADDON_NAME, ns = ...

-- Every piece of text the addon shows, in one place: the options page (in
-- page order), the on-screen move hints and chat messages.
--
-- Editing: change the text on the right. %s and %d are filled in by the
-- code (an ability name, a number); keep each one, in the same order.
-- \n starts a new line.
--
-- Translating: add a file such as Locales\deDE.lua that replaces entries
-- for one game language, and list it in OverpowerAlert.toc after this file
-- and before OverpowerAlert.lua:
--
--     local _, ns = ...
--     if GetLocale() ~= "deDE" then return end
--     local L = ns.L
--     L.ENABLE_ALERT = "%s-Alarm aktivieren"
--
-- Anything it leaves out stays in English. Slash command words (/opa test,
-- overpower, rev, ...) aren't translated, so the hints that name them
-- should keep them as they are.
--
-- Not here: the Cooldown Manager sound names, which are copied from
-- Blizzard's list in OverpowerAlert.lua, and Shared Media sound names, which
-- come from the addons that register them.

local L = setmetatable({}, {
    -- A missing entry shows its own key, so a typo is easy to spot.
    __index = function(_, key) return key end,
})
ns.L = L

--------------------------------------------------------------------------------
-- Addon and abilities
--------------------------------------------------------------------------------

L.ADDON_TITLE = "Overpower Alert"
L.OPTIONS_SUBTITLE = "Plays an alert when Overpower, Revenge, Victory Rush or Execute becomes usable. Each has its own settings."

L.OVERPOWER = "Overpower"
L.OVERPOWER_ALERT_TEXT = "OVERPOWER!"
L.OVERPOWER_DESCRIPTION = "Available for 5 seconds after your target dodges your attack. Can only be cast in Battle Stance."

L.REVENGE = "Revenge"
L.REVENGE_ALERT_TEXT = "REVENGE!"
L.REVENGE_DESCRIPTION = "Available for 5 seconds after you block, dodge or parry. Can only be cast in Defensive Stance."

L.VICTORY_RUSH = "Victory Rush"
L.VICTORY_RUSH_ALERT_TEXT = "VICTORY RUSH!"
L.VICTORY_RUSH_DESCRIPTION = "Available for 20 seconds after you kill an enemy that gives experience or honor. Can be cast in any stance."

L.EXECUTE = "Execute"
L.EXECUTE_ALERT_TEXT = "EXECUTE!"
L.EXECUTE_DESCRIPTION = "Available while your target is below 20% health. Can be cast in Battle and Berserker Stance.\n" ..
    "The game hides your target's health from addons, so it's read from Execute becoming usable,\n" ..
    "which only shows in those two stances."

L.BATTLE_STANCE = "Battle Stance"
L.DEFENSIVE_STANCE = "Defensive Stance"
L.BERSERKER_STANCE = "Berserker Stance"

--------------------------------------------------------------------------------
-- Options: top of each ability's tab
--------------------------------------------------------------------------------

L.ENABLE_ALERT = "Enable %s alert"             -- %s: ability name
L.ALERT_IN = "Alert in:"
L.STANCE_HINT = "Alerts once per opening, the first moment you're in a ticked stance while it's up."
L.SHOW_ON_COOLDOWN = "Alert even while %s is on cooldown (the icon shows greyed out with the cooldown)" -- %s: ability name

--------------------------------------------------------------------------------
-- Options: sound
--------------------------------------------------------------------------------

L.ALERT_SOUND = "Alert sound"
L.SOUND_GROUP = "%s (%d)"                      -- %s: group name, %d: number of sounds
L.SHARED_MEDIA = "Shared Media"
L.SHARED_MEDIA_NONE = "Shared Media (none installed)"
L.SOUND_NONE = "None"
L.SOUND_CUSTOM_MENU = "Custom (path or file ID)"
L.SOUND_CUSTOM = "Custom"                      -- shown on the dropdown once picked
L.TEST = "Test"
L.SHARED_MEDIA_HINT = "Shared Media lists every sound registered through LibSharedMedia by other addons\n" ..
    "(BigWigs, SharedMedia packs, WeakAuras, etc.). Install those to get more sounds."
L.CUSTOM_SOUND_LABEL = "Sound file path or FileDataID (e.g. Interface\\AddOns\\OverpowerAlert\\Sounds\\alert.ogg)"

L.SOUND_CHANNEL = "Sound channel"
L.CHANNEL_MASTER = "Master"
L.CHANNEL_SFX = "Sound Effects"
L.CHANNEL_DIALOG = "Dialog"
L.CHANNEL_AMBIENCE = "Ambience"
L.CHANNEL_MUSIC = "Music"

--------------------------------------------------------------------------------
-- Options: sizes (text and icon size dropdowns)
--------------------------------------------------------------------------------

L.SIZE_LABEL = "%s (%d)"                       -- %s: size name, %d: pixels
L.SIZE_SMALL = "Small"
L.SIZE_MEDIUM = "Medium"
L.SIZE_LARGE = "Large"
L.SIZE_HUGE = "Huge"
L.SIZE_MASSIVE = "Massive"

--------------------------------------------------------------------------------
-- Options: on-screen text and spell icon
--------------------------------------------------------------------------------

L.ONSCREEN_TEXT = "On-screen text"
L.SHOW_TEXT = "Show \"%s\" on screen"          -- %s: the alert text, e.g. OVERPOWER!
L.TEXT_SIZE = "Text size"
L.UNLOCK_TEXT = "Unlock Text"
L.LOCK_TEXT = "Lock Text"

L.SPELL_ICON = "Spell icon"
L.SHOW_ICON = "Show the %s icon (stays up while %s is usable)" -- %s, %s: ability name twice
L.ICON_SIZE = "Icon size"
L.UNLOCK_ICON = "Unlock Icon"
L.LOCK_ICON = "Lock Icon"
L.ICON_GLOW = "Icon glow"

L.RESET_POSITION = "Reset Position"
L.PREVIEW = "Preview"
L.MOVE_HINT = "Unlock, then drag the highlighted box anywhere. Right-click it (or /opa lock) to lock.\n" ..
    "With the icon on the nameplate, this sets its normal position, used as the fallback."

-- Glow styles (icon glow and action bar glow dropdowns)
L.GLOW_NONE = "None"
L.GLOW_PROC = "Proc Glow"
L.GLOW_BUTTON = "Action Button Glow"
L.GLOW_PIXEL = "Pixel Glow"
L.GLOW_AUTOCAST = "Autocast Shine"

--------------------------------------------------------------------------------
-- Options: nameplate
--------------------------------------------------------------------------------

L.NAMEPLATE = "Nameplate"
L.ICON_ON_NAMEPLATE = "Anchor icon to target's nameplate"
L.OVERPOWER_NAMEPLATE_NOTE = "|cffffaa33Experimental:|r the icon goes on the mob that dodged, even if it isn't your target, and stays\n" ..
    "there if you change target (Overpower only works on that mob). It may pick the wrong mob at times."
L.SIDE = "Side"
L.SIDE_TOP = "Above"
L.SIDE_BOTTOM = "Below"
L.SIDE_LEFT = "Left"
L.SIDE_RIGHT = "Right"
L.X_OFFSET = "X offset"
L.Y_OFFSET = "Y offset"
L.OFFSET_HINT = "Pixels from the chosen side: X moves right (negative: left), Y moves up (negative: down).\n" ..
    "Give each ability different offsets so they don't overlap when more than one is up."
L.NAMEPLATE_FALLBACK = "If your target has no nameplate, show the icon at its normal position instead"

--------------------------------------------------------------------------------
-- Options: action bars
--------------------------------------------------------------------------------

L.ACTION_BARS = "Action bars"
L.BAR_GLOW = "Glow %s on your action bars while it's up (any stance)" -- %s: ability name
L.BUTTON_GLOW = "Button glow"
L.BAR_HINT = "Works with Blizzard's bars, EllesmereUI, and LibActionButton bars (Bartender4, ElvUI).\n" ..
    "Only buttons on bars you can see glow, so put it on a bar that shows in every stance."

--------------------------------------------------------------------------------
-- Options: countdown and bottom of the page
--------------------------------------------------------------------------------

L.COUNTDOWN = "Countdown"
L.SHOW_COUNTDOWN = "Show the seconds left in the opening (on the icon, or beside the text if the icon is off)"
L.SLASH_HINT = "Slash commands: /opa (options), /opa test [overpower|revenge|victoryrush|execute], /opa toggle [ability],\n" ..
    "/opa unlock [ability], /opa lock [ability]. Without an ability, toggle/unlock/lock\n" ..
    "apply to all and test plays Overpower."

--------------------------------------------------------------------------------
-- On screen while unlocked
--------------------------------------------------------------------------------

L.MOVE_TEXT_HINT = "%s text: drag to move, right-click to lock" -- %s: ability name
L.MOVE_ICON_HINT = "%s icon: drag to move, right-click to lock" -- %s: ability name

--------------------------------------------------------------------------------
-- Chat messages
--------------------------------------------------------------------------------

L.UNKNOWN_ABILITY = "unknown ability \"%s\" (use overpower, revenge, victoryrush or execute)" -- %s: what was typed
L.ALERT_ENABLED = "%s alert enabled"           -- %s: ability name
L.ALERT_DISABLED = "%s alert disabled"         -- %s: ability name
