# Overpower Alert

A World of Warcraft Forever addon for Warriors that plays a sound, and optionally flashes **OVERPOWER!** on screen, the moment Overpower becomes usable after your target dodges.

## Install

- **Wago:** install [Overpower Alert on Wago Addons](https://addons.wago.io/addons/overpoweralert) with the Wago app.
- **Manually:** download `OverpowerAlert-<version>-forever.zip` from the [latest release](https://github.com/theliahh/OverpowerAlert/releases/latest) and extract it into `World of Warcraft\<game folder>\Interface\AddOns\`. You should end up with an `AddOns\OverpowerAlert\OverpowerAlert.toc` file.

## Usage

The addon works on its own once installed. When your target dodges, Overpower becomes usable for a few seconds, and the alert fires once each time that happens.

- Overpower can only be used in Battle Stance, so that's the only stance where the normal alert fires.
- To be alerted whenever your target dodges, in any stance, turn on **Also alert on any target dodge** in the options. This also goes off when your target dodges someone else's attack, which doesn't enable your Overpower.

## Options

Open the options with `/opa`, or from **Game Menu → Options → AddOns → Overpower Alert**.

- **Alert sound:** pick from:
  - **Cooldown Manager sounds:** the same 93 sounds Blizzard's Cooldown Manager offers for its alerts, in the same categories (Animals, Devices, Impacts, Instruments, Short, Warcraft II, Warcraft III). The default is Warhorn.
  - **Shared Media:** every sound other addons share through LibSharedMedia, such as BigWigs, WeakAuras or SharedMedia sound packs. It's empty until you install one of those.
  - **Custom:** a sound file path or FileDataID of your choice.

  Choosing a sound plays it, so you can try several in a row.
- **Sound channel:** Master, Sound Effects, Dialog, Ambience or Music.
- **On-screen text:** show or hide "OVERPOWER!", and set its size.
- **Spell icon** (off by default): pops up the Overpower icon and keeps it up while Overpower is usable. Set its size and pick a glow: Proc Glow, Action Button Glow, Pixel Glow, Autocast Shine or None.
- **Moving the text or icon:** click **Unlock Text** or **Unlock Icon**, drag the highlighted box where you want it, then right-click it to lock. **Reset Position** puts it back in the default spot, and **Preview** shows it as it will appear.

## Slash commands

| Command | What it does |
| --- | --- |
| `/opa` | Open the options |
| `/opa test` | Play the current alert sound |
| `/opa toggle` | Turn the alert on or off |
| `/opa unlock` / `/opa lock` | Unlock the text and icon to move them, or lock them again |

## How it works

On WoW Forever's client, addons can't read the combat log, so the addon can't see the dodge directly. Instead it watches Overpower itself, which only becomes usable just after a dodge, and alerts when it switches from unusable to usable. The addon picks up whichever rank you've learned.


## Credits

The addon bundles [LibStub](https://www.wowace.com/projects/libstub), [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler), [LibSharedMedia-3.0](https://www.curseforge.com/wow/addons/libsharedmedia-3-0) and [LibCustomGlow-1.0](https://github.com/Stanzilla/LibCustomGlow), which keep their own licenses.
