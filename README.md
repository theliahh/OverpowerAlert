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

- **Alert sound:** pick from three groups:
  - **Game Sounds:** about 40 built-in sounds.
  - **Shared Media:** every sound other addons share through LibSharedMedia, such as BigWigs, WeakAuras or SharedMedia sound packs. It's empty until you install one of those.
  - **Custom:** a sound file path or FileDataID of your choice.

  Choosing a sound plays it, so you can try several in a row.
- **Sound channel:** Master, Sound Effects, Dialog, Ambience or Music.
- **On-screen text:** show or hide it, and set the size.
- **Moving the text:** click **Unlock Text**, drag the highlighted box where you want it, then right-click it to lock. **Reset Position** puts it back in the default spot.

## Slash commands

| Command | What it does |
| --- | --- |
| `/opa` | Open the options |
| `/opa test` | Play the current alert sound |
| `/opa toggle` | Turn the alert on or off |
| `/opa unlock` / `/opa lock` | Unlock the text to move it, or lock it again |

## How it works

On WoW Forever's client, addons can't read the combat log, so the addon can't see the dodge directly. Instead it watches Overpower itself, which only becomes usable just after a dodge, and alerts when it switches from unusable to usable. The addon picks up whichever rank you've learned.

## Releases

Every push to `main` triggers a GitHub Actions workflow that builds the addon with [BigWigs' packager](https://github.com/BigWigsMods/packager). It publishes a GitHub release with the zip and uploads the same build to Wago. Versions are numbered `1.1.<build number>`.

## Credits

The addon bundles [LibStub](https://www.wowace.com/projects/libstub), [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler) and [LibSharedMedia-3.0](https://www.curseforge.com/wow/addons/libsharedmedia-3-0), which keep their own licenses.
