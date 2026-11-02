# EVE Mining
**V2.1 — Python edition**

A compact Windows monitor for multiple EVE Online mining characters.

## Download
[Download EVE Mining V2.1](https://github.com/Marci1125/Eve-Mining-Monitor/raw/refs/heads/main/EVE-Mining-V2.1-Python-Share.zip)

Extract the complete ZIP into a writable local folder and run **EVE-Mining.exe**.
Keep **Sounds**, **Licenses** and the included documentation together.
Python is bundled; no Python installation, installer or administrator rights are required.

## New in V2.1
- Separate **Cargo volume** and **Attack volume** sliders, from 0–100%.
- Both default to **20%**; save the levels with **Save alert settings**.
- Test sounds and real alerts use the same levels; a running preview can be adjusted directly.
- Both bundled attack alarms are **four seconds** long, with a short fade-out.
- Existing selections of the old bundled MP3 alarms map to the shortened WAV files.
- Existing Python profiles, cargo, session, prices and sound preferences are preserved.

## Quick setup
1. Open **Fleet / prices > Fleet profiles** and select your local EVE **Gamelogs** folder.
2. Click **Add pilots from logs**, then double-click each pilot to edit.
3. Set ship class, actual in-game hold capacity, expected lasers and raw unboosted cycle.
4. Name your profile, choose **ICE / ORE**, then **Save and activate profile**.
5. Confirm starting cargo: **Reset** if empty, or right-click the pilot to set/confirm it.
6. Under **Alerts**, choose and test local cargo/attack sounds, then save.

English EVE mining/combat log notifications are required.

## Features
- ICE and ORE cargo tracking with material-specific volumes and logged compression.
- Saved fleet profiles, individual hold capacities and reset controls.
- Red cargo warning at 95%, 30-second critical-yield highlighting and estimated time to full.
- Fleet free capacity excluding booster ships.
- Configurable cargo-threshold and incoming-attack sounds; add MP3/WAV files to **Sounds**.
- Mining activity hints that account for observed boosts and unequal laser cycles.
- Estimated income from compressed-item **BUY** quotes; 186 dated default prices and manual imports.
- Automatic pause after five minutes without mining; the next mining yield resumes.
- Headline ISK/h updates every 60 seconds, or on session/pause changes.

Transfers, jettison and station unloading are not logged: reset cargo or correct the remaining volume manually.
**New session** clears income/time while retaining cargo counters.
Income, activity hints and ETA are estimates. Prices are not live.

## Local operation
The application reads the configured local gamelogs and does not control EVE or automate gameplay.
It has no application network client, browser launch or automatic updater.
Python, Tkinter and PyInstaller are used; the one-file bootloader temporarily extracts its runtime at startup.
Windows provides normal UI, file and audio services. OneDrive synchronization remains independent.

## Personal data and updates
Profiles, cargo, prices and session are saved in **EVE-Mining.python-state.json** beside the EXE.
Keep this file when updating; do not upload it or its backups.
To migrate from the C# edition, copy **EVE-Mining.native-state.json** beside the new EXE before first use.
The Python edition imports that file only if no Python state exists and leaves the original unchanged.

The downloadable ZIP contains no personal profiles or session data.
The full usage guide and third-party notices are included in the ZIP.
