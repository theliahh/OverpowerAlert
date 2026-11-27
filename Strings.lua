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
    "which only shows in those two stances. Tick Defensive Stance to still see the icon there: it\n" ..
    "appears below 20%, but with no sound or text, since the addon can't tell when that happens."

L.BATTLE_STANCE = "Battle Stance"
L.DEFENSIVE_STANCE = "Defensive Stance"
L.BERSERKER_STANCE = "Berserker Stance"

--------------------------------------------------------------------------------
-- Options: General tab
--------------------------------------------------------------------------------

L.GENERAL = "General"
L.GENERAL_DESCRIPTION = "Settings shared by every ability."
L.COMBAT_ONLY = "Only show alerts in combat"
L.COMBAT_ONLY_HINT = "Alerts still up when combat ends are hidden."
L.PROFILE = "Profile"
L.PROFILE_FOR_SET = "Profile (%s)"               -- %s: SPEC_PRIMARY or SPEC_SECONDARY
L.PROFILE_NEW = "New"
L.PROFILE_COPY = "Copy"
L.PROFILE_RENAME = "Rename"
L.PROFILE_DELETE = "Delete"
L.PROFILE_RESET = "Reset profile"
L.PROFILE_EXPORT = "Export"
L.PROFILE_IMPORT = "Import"
L.PROFILE_HINT = "A profile holds every setting on every tab. Profiles are shared by all your characters, and\n" ..
    "each character uses the one chosen here. The Default profile can't be renamed or deleted."
L.PROFILE_NAME = "Profile name"
L.PROFILE_NEW_TITLE = "New profile (default settings)"
L.PROFILE_COPY_TITLE = "Copy \"%s\" to a new profile" -- %s: profile name
L.PROFILE_COPY_NAME = "%s copy"                  -- %s: profile name
L.PROFILE_RENAME_TITLE = "Rename \"%s\""         -- %s: profile name
L.PROFILE_DELETE_TITLE = "Delete profile"
L.PROFILE_DELETE_CONFIRM = "Delete the profile \"%s\"? Every character using it will use Default instead." -- %s: profile name
L.PROFILE_RESET_TITLE = "Reset profile"
L.PROFILE_RESET_CONFIRM = "Put every setting in \"%s\" back to its default? Every character using it is affected." -- %s: profile name
L.PROFILE_EXPORT_TITLE = "Export \"%s\""         -- %s: profile name
L.PROFILE_EXPORT_HINT = "Copy this text (Ctrl+C) and share it. Importing it recreates this profile, positions included."
L.PROFILE_IMPORT_TITLE = "Import a profile"
L.PROFILE_IMPORT_HINT = "Paste a profile string (Ctrl+V). It's added as a new profile and used straight away."

L.TALENT_SETS = "Talent sets"
L.CURRENT_SET = "Current set: %s"              -- %s: SET_PRIMARY or SET_SECONDARY
L.SET_PRIMARY = "Primary"
L.SET_SECONDARY = "Secondary"
L.PER_SPEC = "Use different profiles for primary and secondary talents"
L.SPEC_PRIMARY = "primary talents"
L.SPEC_SECONDARY = "secondary talents"
L.PER_SPEC_HINT = "|cffffaa33Experimental:|r swapping talents switches to that set's profile. With this on, the profile\n" ..
    "chosen at the top is the one for the talent set you're on."
L.SPEC_SWITCHED = "now using the \"%s\" profile for your %s" -- %s: profile name, then SPEC_PRIMARY or SPEC_SECONDARY

-- Profiles: names and the reasons an action is refused
L.PROFILE_SECONDARY_TALENTS = "Secondary talents" -- the profile made from old secondary-talent settings
L.PROFILE_IMPORTED = "Imported"                   -- name for an import with no name
L.PROFILE_NAME_EMPTY = "Enter a name."
L.PROFILE_NAME_LONG = "Names can be at most %d letters." -- %d: the limit
L.PROFILE_NAME_TAKEN = "There's already a profile called \"%s\"." -- %s: the existing name
L.PROFILE_MISSING = "That profile doesn't exist any more."
L.PROFILE_DEFAULT_FIXED = "The Default profile can't be renamed or deleted."
L.EXPORT_FAILED = "This profile couldn't be exported."
L.IMPORT_EMPTY = "Paste an Overpower Alert profile string first."
L.IMPORT_TOO_LONG = "That text is too long to be an Overpower Alert profile."
L.IMPORT_NOT_PROFILE = "That isn't an Overpower Alert profile string."
L.IMPORT_NEWER = "That profile was exported by a newer version of Overpower Alert. Update the addon to import it."
L.IMPORT_DAMAGED = "That profile string is damaged or incomplete. Copy it again in full."
L.FONT = "Font"
L.FONT_DEFAULT = "Default (game font)"
L.FONT_HINT = "Used for the on-screen text and the countdown numbers of every ability.\n" ..
    "Lists every font registered through LibSharedMedia by other addons\n" ..
    "(SharedMedia packs, ElvUI, WeakAuras, etc.). Install those to get more fonts."
L.FONT_SAMPLE = "OVERPOWER!  4.2"

L.ICON_LAYOUT = "Icon positions"
L.ICON_LAYOUT_SEPARATE = "Separate: each icon at its own spot"
L.ICON_LAYOUT_GROUP = "Grouped: side by side from one spot"
L.GROUP_GROW = "Grow direction"
L.GROW_RIGHT = "Right"
L.GROW_LEFT = "Left"
L.GROW_UP = "Up"
L.GROW_DOWN = "Down"
L.GROW_HCENTER = "Centered (row)"
L.GROW_VCENTER = "Centered (column)"
L.GROUP_SPACING = "Spacing"
L.UNLOCK_GROUP = "Unlock Icons"
L.LOCK_GROUP = "Lock Icons"
L.GROUP_HINT = "Grouped: the icons that are up sit next to each other. A new one goes on the end; they close up when one goes.\n" ..
    "Unlock, then drag the highlighted box to move them all. Right-click it (or /opa lock) to lock.\n" ..
    "Each ability's Unlock Icon and Reset Position buttons then move the group too.\n" ..
    "Icons shown on a nameplate aren't part of the group. Sizes are still set per ability."

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
L.CUSTOM_TEXT = "Text"
L.CUSTOM_TEXT_HINT = "Type your own, or leave it empty for %s" -- %s: the default text, e.g. OVERPOWER!
L.TEXT_SIZE = "Text size"
L.UNLOCK_TEXT = "Unlock Text"
L.LOCK_TEXT = "Lock Text"

L.SPELL_ICON = "Spell icon"
L.SHOW_ICON = "Show the %s icon (stays up while %s is usable)" -- %s, %s: ability name twice
L.ICON_SIZE = "Icon size"
L.UNLOCK_ICON = "Unlock Icon"
L.LOCK_ICON = "Lock Icon"
L.ICON_GLOW = "Icon glow"
L.TINT_NO_RAGE = "Tint the icon blue while you don't have enough rage for %s" -- %s: ability name

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
L.NAMEPLATE_BOTH = "Also show the icon at its normal position (or in the icon group) at the same time"
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
L.MOVE_GROUP_HINT = "Icons: drag to move, right-click to lock"
L.MOVE_ICON_HINT = "%s icon: drag to move, right-click to lock" -- %s: ability name

--------------------------------------------------------------------------------
-- Chat messages
--------------------------------------------------------------------------------

L.UNKNOWN_ABILITY = "unknown ability \"%s\" (use overpower, revenge, victoryrush or execute)" -- %s: what was typed
L.ALERT_ENABLED = "%s alert enabled"           -- %s: ability name
L.ALERT_DISABLED = "%s alert disabled"         -- %s: ability name
