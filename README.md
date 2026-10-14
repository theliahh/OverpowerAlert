# Overpower Alert

A World of Warcraft Forever addon for Warriors that alerts you the moment **Overpower** or **Revenge** becomes usable. Each alert can play a sound, show text on screen and pop up the spell icon.

## Install

- **Wago:** install [Overpower Alert on Wago Addons](https://addons.wago.io/addons/overpoweralert) with the Wago app.
- **Curseforge:** install [Overpower Alert on Curseforge Addons](https://www.curseforge.com/wow/addons/overpoweralert) with the Curseforge or [WowUp with Curseforge](https://wowup.io/) app.
- **Manually:** download `OverpowerAlert-<version>-forever.zip` from the [latest release](https://github.com/theliahh/OverpowerAlert/releases/latest) and extract it into `World of Warcraft\<game folder>\Interface\AddOns\`. You should end up with an `AddOns\OverpowerAlert\OverpowerAlert.toc` file.

## Usage

The addon works on its own once installed. Both alerts are on by default, and each fires once per opening:

- **Overpower:** available for 5 seconds after your target dodges *your* attack (other players' dodged attacks don't count). It can only be cast in Battle Stance.
- **Revenge:** available for 5 seconds after you block, dodge or parry. It can only be cast in Defensive Stance.

You choose which stances each ability alerts in: Battle, Defensive and Berserker Stance each have a checkbox. By default Overpower alerts in Battle Stance and Revenge in Defensive Stance, the stances they can be cast in. Tick other stances to hear about an opening there too, so you can switch.

- The alert plays the first moment an opening is up while you're in a ticked stance. If it happens in an unticked stance and you switch into a ticked one before it runs out, it alerts then.
- Each opening only alerts once, however much you switch stances.
- If the ability is on cooldown, the alert waits until it's ready, as long as the opening is still up.

## Options

Open the options with `/opa`, or from **Game Menu → Options → AddOns → Overpower Alert**. There's a tab for each ability, and every setting below is set separately for each one.

- **Enable:** turn that ability's alert on or off.
- **Alert in:** the stances to alert in (see above).
- **Alert sound:** pick from:
  - **Cooldown Manager sounds:** the same 93 sounds Blizzard's Cooldown Manager offers for its alerts, in the same categories (Animals, Devices, Impacts, Instruments, Short, Warcraft II, Warcraft III). The defaults are Warhorn for Overpower and Sword Shing for Revenge.
  - **Shared Media:** every sound other addons share through LibSharedMedia, such as BigWigs, WeakAuras or SharedMedia sound packs. It's empty until you install one of those.
  - **Custom:** a sound file path or FileDataID of your choice.

  Choosing a sound plays it, so you can try several in a row.
- **Sound channel:** Master, Sound Effects, Dialog, Ambience or Music.
- **On-screen text:** show or hide "OVERPOWER!" or "REVENGE!", and set its size.
- **Spell icon** (off by default): pops up the ability's icon. Set its size and pick a glow: Proc Glow, Action Button Glow, Pixel Glow, Autocast Shine or None.
- **How long they stay up:** the text and icon stay up while the ability's opening lasts, in any stance: 5 seconds after your target's dodge for Overpower, or after your last block, dodge or parry for Revenge. They fade as soon as you use the ability.
- **Moving the text or icon:** click **Unlock Text** or **Unlock Icon**, drag the highlighted box where you want it, then right-click it to lock. **Reset Position** puts it back in the default spot, and **Preview** shows it as it will appear.

## Slash commands

Commands that take an ability accept `overpower` (or `op`) or `revenge` (or `rev`).

| Command | What it does |
| --- | --- |
| `/opa` | Open the options |
| `/opa test [ability]` | Preview the full alert: plays the sound, and shows the text and icon if they're turned on. Without an ability, previews Overpower. |
| `/opa toggle [ability]` | Turn an alert on or off. Without an ability, turns both off if either is on, otherwise turns both on. |
| `/opa unlock [ability]` / `/opa lock [ability]` | Unlock the text and icon to move them, or lock them again. Without an ability, applies to both. |

## How it works

On WoW Forever's client, addons can't read the combat log, so the addon pieces each opening together from other signals:

- **Revenge:** the game reports your own blocks, dodges and parries to addons, in any stance.
- **Overpower:** a quirk carried over from the original game. An Overpower opening is tracked as a hidden combo point on your character, which appears when your target dodges your attack and lasts 5 seconds, whatever stance you're in.
- **Both:** the ability turning usable in its own stance is used as a backup signal.

It picks up whichever rank you've learned.

## Credits

The addon bundles [LibStub](https://www.wowace.com/projects/libstub), [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler), [LibSharedMedia-3.0](https://www.curseforge.com/wow/addons/libsharedmedia-3-0) and [LibCustomGlow-1.0](https://github.com/Stanzilla/LibCustomGlow), which keep their own licenses.
