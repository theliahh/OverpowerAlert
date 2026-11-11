# WoW Forever client: research notes

What we've learned about the WoW Forever client while building Overpower Alert: what addons can and can't see, how we detect Overpower and Revenge, and how releases are packaged. Read this before changing detection logic or the release workflow.

Each finding is marked:

- **Verified in-game:** seen on the live client, in the chat output of a debug or probe command, or reported working by the author.
- **From source:** read from Blizzard's UI code or another addon, not tested in-game.
- **Unverified:** our assumption.

## The client

- WoW Forever runs the modern 12.1 game engine with original-game content. Its TOC interface number is `16001`, and Blizzard calls the game type "camelot". (From source: EllesmereUI's `EllesmereUI_ClientGate.lua` and `EllesmereUI_Lite.lua`.)
- `WOW_PROJECT_ID` reports *mainline* on purpose, so don't use it to detect Forever. (From source: EllesmereUI comments.)
- **Launch (2026-11-04):** the live client installs to `World of Warcraft\_forever_` (Battle.net product `wowf`), version **1.60.1.70790**, still TOC interface `16001`. The addon was developed in the beta install, `_classic_beta_`, which has its own `Interface\AddOns` and `WTF`, so settings don't carry over between the two on their own.
- **Changes from beta build 70450 to launch build 70790** that matter to us: `UNIT_COMBAT`'s `amount` became secret, but we only read `event` and `flagText`, which are still plain. Nothing else we use changed: spell usability and cooldowns, `UnitPower`, nameplates, the Menu dropdown API, and the Cooldown Manager sound list. (From source: diff of the `forever` branch.)
- Blizzard's UI source for this client is in the **`forever` branch** of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever). The generated API docs are in `Interface/AddOns/Blizzard_APIDocumentationGenerated/`. Use this branch, not `live` or `classic_era`, when checking what an API does here.
- Addon Lua is 5.1. Use LuaJIT (installed with winget as `DEVCOM.LuaJIT`) for syntax checks: `luajit -e "assert(loadfile('File.lua'))"`. Lua 5.4 would accept syntax WoW rejects.

## Secret values

The 12.x engine hides some values from addons, especially in combat. A hidden ("secret") value:

- can't be compared, branched on, concatenated, or used as a table key;
- can be detected with `issecretvalue(v)`;
- **can** be passed straight into certain display functions, such as `frame:SetAlpha(secret)`, and the game draws the result. Another Overpower addon uses this to show or hide a glow by setting its transparency to the hidden 0/1 value. It never learns the value, so it can't play a sound from it. (From source: that addon's code.)

Rule of thumb: anything that needs an `if` (playing a sound, starting a timer, choosing what to show) needs a readable value.

## What addons can see

| Signal | Result | Status |
| --- | --- | --- |
| Combat log (`COMBAT_LOG_EVENT_UNFILTERED`) | `C_CombatLog.IsCombatLogRestricted()` returned **true** in open-world combat. No installed addon registers this event. | Verified in-game |
| `C_Spell.IsSpellUsable(id)` | Readable. Overpower and Revenge only report usable in their own stance (Battle and Defensive). Outside that stance they report `usable=false, noPower=false` even right after a dodge or parry. | Verified in-game |
| `UNIT_COMBAT` (unit, action, flagText) | Readable (the 4th argument, `amount`, is secret since the launch build). `player` + `DODGE`/`PARRY`/`BLOCK`/`MISS` are your own avoidances. `target` + `DODGE` is any attacker's attack on your target, not just yours. | Verified in-game |
| `UNIT_COMBAT` partial block | A partly blocked hit is `WOUND` with `flagText == "BLOCK_REDUCED"`; a hit fully blocked can also be `WOUND` with `"BLOCK"`. Both count for Revenge. Missing `BLOCK_REDUCED` caused missed Revenge alerts, mostly under Shield Block (user reports). | Verified in-game (`WOUND` + `BLOCK_REDUCED` seen under Shield Block) |
| Proc glow (`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`/`_HIDE`, `C_SpellActivationOverlay.IsSpellOverlayed`) | Never fires for Overpower, Revenge or Victory Rush; `IsSpellOverlayed` stays `false`. Not usable as a signal (it is what EllesmereUI's action bar proc glow uses). | Verified in-game |
| Revenge usable vs. `UNIT_COMBAT` | `IsSpellUsable` turns true ~0.2-0.3 s before the block/dodge/parry arrives in `UNIT_COMBAT` (same lead as Overpower's combo point over the dodge). | Verified in-game |
| Revenge window end | Timing 5 s from `UNIT_COMBAT` left the alert up ~0.6-1 s after the action bar button went unusable (clip). The addon now keeps the end time from the usable edge when `UNIT_COMBAT` follows within 0.5 s, and ends the opening when `IsSpellUsable` falls while the player stays in Defensive Stance. | Seen in-game (video); fix covered by tests |
| Target health (Execute) | `UnitHealth`, `UnitHealthMax`, `UnitHealthPercent` (with or without a curve) and the player's own `UnitHealth` are all `<secret>`, in and out of combat. The target frame's health bar is readable but always reads 1/1. `UnitPower("player", 1)` (rage) was secret too. | Verified in-game (`/opa execprobe`) |
| Execute usability | `IsSpellUsable(Execute)` is `false/false` above 20% and turns `true/false` the moment the target crosses it, together with `SPELL_UPDATE_USABLE`/`ACTIONBAR_UPDATE_USABLE` and a `COMBAT_TEXT_UPDATE`. Short of rage (after a cast or a stance swap) it's `false/true`. It's `true` straight away when targeting a mob already below 20%. It stays `false` in Defensive Stance with the target below 20%, and turns `true` on switching to Battle. A kill clears the target (`false/false`). The action bar's `IsUsableAction` agrees. | Verified in-game (`/opa execprobe`) |
| Execute in Defensive Stance | No signal. `COMBAT_TEXT_UPDATE` `SPELL_ACTIVE` fires the instant Execute turns usable in Battle Stance, but a full 14 s Defensive Stance fight down to the kill gave none (another short fight gave one, 2 s in, most likely Revenge). Like Overpower's, it follows the stance the spell can be cast in. So below 20% can't be seen from Defensive Stance; the alert comes on switching to Battle or Berserker. | Verified in-game (`/opa execprobe`) |
| Overpower and Revenge cooldowns | Casting Revenge also puts Overpower on cooldown for the same ~5 s (`GetSpellCooldown` `isActive`). Possibly a shared cooldown on Forever; not yet checked by casting Overpower right after Revenge. | Seen in-game |
| `COMBAT_TEXT_UPDATE` `"SPELL_ACTIVE"` | Fired when **Revenge** activated. Its spell name from `C_CombatText.GetCurrentEventInfo()` was `<secret>`. It did **not** fire when the target dodged in Defensive Stance, so it gives no Overpower signal outside Battle Stance. The API docs mark `GetCurrentEventInfo` as `SecretReturns = true`. | Verified in-game |
| Proc glow (`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`) / `C_SpellActivationOverlay.IsSpellOverlayed` | No events, always `false`, for both abilities. | Verified in-game |
| **Combo points, `UnitPower("player", 4)`** | **The Overpower opening.** See below. | Verified in-game |

### Overpower opening = hidden combo point

As in the original game, an Overpower opening is stored as a combo point on the warrior (power type 4, `Enum.PowerType.ComboPoints`).

From a probe in **Defensive Stance**, during combat (verified in-game):

- The value went 0 → 1 when the target dodged the player's attack, and back to 0 almost exactly 5.0 s later (36.74 → 41.76 and 54.01 → 59.00).
- It was **readable** (plain `1`, not secret) in open-world combat.
- `UNIT_POWER_UPDATE` fired **once** per change with payload `("player", "COMBO_POINTS")`. `UNIT_POWER_FREQUENT` fired twice per change.
- The matching `UNIT_COMBAT target DODGE` arrived about **0.6 s after** the combo point changed, not before.
- Other players' dodges don't affect it, so it only reflects the player's own dodged attacks.

The other Overpower addon says this value can be secret in combat in some situations, maybe instances or encounters. We haven't seen that (unverified). Our fallback: if the value is secret, a combo-point change within 1.0 s of a target dodge, in either order, counts as a new opening.

## How Overpower Alert detects procs

The addon tracks each ability's **opening** in every stance, and decides separately whether to alert.

- **What starts or extends an opening (a "trigger"):**
  - Revenge: `UNIT_COMBAT player BLOCK/DODGE/PARRY`.
  - Overpower: combo points going from 0 to 1, with the secret-value fallback above.
  - Backup: `C_Spell.IsSpellUsable` changing from false to true. It only starts an opening if none is running, not within 0.5 s of one ending, and not while one the player has just used up would still be running. Otherwise it's a stance switch into an opening we already know about.
  - "Usable except for rage" (`noPower == true`) counts as usable.
- **What ends an opening:**
  - 5 s after the last trigger.
  - Casting the ability (`UNIT_SPELLCAST_SUCCEEDED`; spell IDs are readable, verified in-game). This also fades the text and icon right away.
  - For Overpower, the combo point dropping to 0.
- **When it alerts:** each opening alerts at most once, the first moment all of these hold:
  - the player is in a stance ticked in the ability's settings (`cfg.stances.battle/defensive/berserker`);
  - the ability is known and enabled;
  - the ability isn't on its own cooldown.

  This is re-checked on every trigger, stance change (`UPDATE_SHAPESHIFT_FORM`), cooldown update (`SPELL_UPDATE_COOLDOWN`), and every 0.1 s in combat. So switching into a ticked stance partway through an opening alerts then, and switching again doesn't.
- **Current stance:** `GetShapeshiftForm()` gives the stance bar index, and `GetShapeshiftFormInfo(index)` gives its spell ID (Battle `2457`, Defensive `71`, Berserker `2458`). The fallback is bar order 1/2/3 = Battle/Defensive/Berserker. Stance index 2 = Defensive is verified in-game; the spell-ID lookup is from the API (unverified on Forever).
- **Cooldowns:** read with `C_Spell.GetSpellCooldown(id)`'s `isActive` and `isOnGCD`, falling back to `duration > 1.6`. If the game won't say, it counts as off cooldown.
  - Without this check, a block right after casting Revenge would alert while Revenge can't be used.
  - The field names come from EllesmereUI's code (from source; unverified on Forever).
- **Phantom alerts at the end of combat (fixed):** an old opening would flash back with a fresh timer. Ending an opening used to clear its end time, which switched off the "just ended" guard, so a late usable update (the game re-sends them when the target dies) started a new opening. Now the end time is kept, and when Overpower's combo point is readable and 0 the usable backup is ignored. Reproduced and checked off-game; the end-of-combat usable flicker itself is inferred, not seen in a probe.
- **Why "usable" can't just be trusted:** `C_Spell.IsSpellUsable` ignores cooldowns, so Revenge keeps reporting usable after it's cast (verified in-game). That's why a cast also blocks the backup signal for the rest of the opening it used up.
- The text and icon stay up while the opening lasts (`ns.IsActive`: the opening is running, or the Overpower combo point is up), in any stance.
- **Settings history:** before per-stance settings there was a single "any stance" checkbox. Ticked became all three stances; unticked became the ability's own stance.

- **Victory Rush (unverified in-game):** spell **`402927`** on Forever, the Season of Discovery rune version (from Wowhead's Forever database and Warcraft Wiki: 20 s after a kill that gives experience or honor). `34428` (other game versions) is kept as a fallback. It can be cast in any stance (confirmed in game),. The buff ID `402975` was confirmed in game. The opening is the "Victorious" buff (`402975`), read with `C_UnitAuras.GetPlayerAuraBySpellID`, re-checked on `UNIT_AURA` and every 0.1 s in combat. Its `expirationTime` sets the end when readable, otherwise 20 s. Stances default to all three; the ticks are a preference. In combat `GetPlayerAuraBySpellID` doesn't return the buff at all (it appeared ~5 s late, when combat ended), so in combat a missing buff counts as unknown and Victory Rush turning usable starts the opening; it ends on the cast or after 20 s, and the real end time is picked up once combat ends.

Spell IDs (highest rank first): Overpower `11585, 11584, 7887, 7384`; Revenge `25288, 11601, 11600, 7379, 6574, 6572`. The highest rank the player knows is chosen with `IsPlayerSpell`.

### Approaches that didn't work

- **"Any target dodge" via `UNIT_COMBAT target DODGE` alone:** it can't tell the player's attacks from anyone else's, so the author rejected it.
- **`SPELL_ACTIVE` combat text for Overpower:** it doesn't fire outside Battle Stance, and the spell name is secret.
- **Combat log:** restricted.
- **Proc-glow events:** never fire for these abilities.

### How we found this

Debug and probe slash commands that print every candidate signal to chat with timestamps while the author fights in each stance. The useful pattern: register the candidate events, poll the values every 0.1 s and print only changes, and print secret values as `<secret>` rather than touching them. These commands were removed after use; rebuild one this way if a new question comes up.

## UI building blocks that work on this client

All verified in-game unless marked.

- Options page: `Settings.RegisterCanvasLayoutCategory(panel, name)` + `Settings.RegisterAddOnCategory`; open it with `Settings.OpenToCategory(category:GetID())`.
- Dropdowns: `CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")` with `:SetupMenu`. Use `:CreateRadio`, `:CreateButton` for submenus, `:SetScrollMode(maxHeight)` for long lists, and `:OverrideText` for the label shown.
- Scrolling pages: `UIPanelScrollFrameTemplate`.
- Tabs: `PanelTopTabButtonTemplate` is used if creating it succeeds (in a `pcall`), with plain buttons as the fallback. Which one this client uses hasn't been checked (unverified).
- Glows: LibCustomGlow-1.0 (bundled, copied from BigWigs_Plugins) works for Proc, Action Button, Pixel and Autocast glows.
- Sounds: `PlaySound(soundKitID, channel, true)` plays the Cooldown Manager's sound kit IDs. The list is copied from `Blizzard_CooldownViewer/CooldownViewerSoundAlertData.lua` (93 sounds in 7 categories), minus its "Short" category (26 sounds, IDs 353387-353428): none of them play on Forever, in this addon or in Blizzard's own Cooldown Manager menu (seen in game). That leaves 67. LibSharedMedia-3.0 gives the BigWigs/SharedMedia sound list.
- Moving frames: call `frame:SetDontSavePosition(true)` and save the position yourself, so the client's layout cache doesn't fight it.
- Nameplates: `C_NamePlate.GetNamePlateForUnit("target")` and a plain `SetPoint` onto the plate, as BigWigs' Nameplates plugin does. Verified in-game: the icon attaches to the target's nameplate and follows it.
  - The icon re-checks every frame while shown, so it follows target changes and plates being recycled.
  - It skips plates where `plate:IsForbidden()` is true.
  - The icon's visible parts live on an inner `body` frame. With no nameplate and the fallback off, only `body` is hidden, so the outer frame's `OnUpdate` keeps the hold/fade timing running.
- Nameplate offsets: the icon's facing edge is anchored to the chosen side of the plate, plus the saved `nameplateX`/`nameplateY`. These replaced the single `nameplateGap`, which `LoadSettings` converts.
- Action bar glow (`ActionBars.lua`; unverified in-game): every 0.1 s while a glow is wanted, it scans `ActionBarButtonEventsFrame.frames`, the Blizzard bar buttons by name, LibActionButton's `buttonRegistry`, and EllesmereUI's `EABButton<slot>` buttons (which EllesmereUI removes from Blizzard's registry). Each visible button's spell comes from `GetActionInfo` on its `"action"` attribute, falling back to `button.action` (secret in combat on 12.x, per EllesmereUI's comments) (macros through `GetMacroSpell`) or LAB's `button:GetSpellId()`. LibCustomGlow glows use their own key, so they don't clash with other addons' glows on the same button.
- Text: every string the addon shows is in `Strings.lua` as `ns.L.KEY`, loaded before `OverpowerAlert.lua` (ability names and descriptions are built from it at load). A missing key shows the key itself. Translations go in a per-locale file loaded right after it.
- Adding or removing files in the TOC needs a full client restart; `/reload` isn't enough.

## Releases and packaging

- [.github/workflows/release.yml](../.github/workflows/release.yml) tags every push to `main` as `<VERSION_PREFIX>.<run number>` and runs BigWigs' `release.sh`.
- **Gotcha:** on a branch push, the packager skips any commit that already has a tag ("Found future tag … not packaging"). A tag pushed with `GITHUB_TOKEN` doesn't start another workflow run. So the workflow runs `release.sh` itself with `GITHUB_REF=refs/tags/<tag>` instead of using the `BigWigsMods/packager@v2` action.
- The packager recognises TOC `16xxx` as game type `forever`. Wago files the upload under game version **1.60.1**. CurseForge uses game version type ID `88568`. WoWInterface doesn't support Forever and is skipped.
- The upload IDs come from the TOC: `## X-Wago-ID: EGPaeEN1` and `## X-Curse-Project-ID: 1715423`. The packager matches these **case-sensitively**; `X-WAgo-ID` was silently ignored.
- Repo secrets: `WAGO_API_TOKEN` and `CF_API_KEY`. GitHub uses the built-in `GITHUB_TOKEN`.
- Pushing workflow files from the GitHub CLI needs the `workflow` permission: `gh auth refresh -h github.com -s workflow`.
- `.pkgmeta` keeps `README.md` and `docs/` out of the release zip.
