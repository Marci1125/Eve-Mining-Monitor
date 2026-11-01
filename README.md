# EVE Mining

**Version 1.0** — Tool created by **Marcel Ijonen [NO.W8]**.

A compact Windows overlay for tracking multiple EVE Online mining characters.

<img src="Corp-Logo.png" alt="NO.W8 corporation logo" width="96">

## Download

[Download EVE-Mining-1.0.zip](https://github.com/Marci1125/Eve-Mining-Monitor/raw/refs/heads/main/releases/EVE-Mining-1.0.zip)
Extract the complete ZIP into a writable folder, then run **EVE-Mining.exe**.
Keep all included files together. No EVE account login is required.

## Features

- Separate Ice / Ore cargo tracking with the correct item volumes
- Fleet profiles with individual ship classes, cargo capacity and laser settings
- Compression detection, remaining cargo capacity and estimated time until full
- Fleet-wide free ice-block capacity, excluding boost ships
- Estimated mining value and ISK/hour using imported Janice BUY prices
- Automatic session pause after five minutes without mining; next yield resumes
- Incoming-attack sound with a mute option
- Critical-yield highlighting and irregular-mining hints

## Quick setup

1. Start EVE Mining and open **Fleet / prices**.
2. Select your EVE **logs/Gamelogs** folder and click **Add pilots from logs**.
3. Select ship classes and enter each character's actual in-game cargo capacity.
4. Set expected **Lasers** (usually 2 for barges/exhumers, 0 for boosters).
5. Set **Raw cycle (s)** to the slower unboosted laser cycle, or 0 for auto.
6. Name the profile, select ICE / ORE, and **Save and activate profile**.
7. Confirm the initial cargo. Reset if empty; otherwise right-click to set/confirm it.

EVE mining/combat notifications must be in English.
The release includes 186 creator-supplied BUY prices as a dated snapshot.
Prices are not live; update them through **Prices / Janice** when desired.

## Important behavior

Transfers, jettison and station unloading are not automatically inferred.
Use a character's **Reset**, **Reset all**, or a manual remaining-cargo correction.
Compression updates cargo volume without counting mining income twice.
Mining value is an estimate based on compressed-item BUY quotes, before fees.
ETA and irregular-mining messages are estimates derived from log events.
The program does not control EVE or automate gameplay.

**New session** resets income and time while retaining actual cargo counters.
Automatic pauses exclude the paused interval from ISK/hour.

## Requirements

- Windows with Windows PowerShell 5.1 and .NET Framework 4.8
- Local EVE Online game logs with English notifications

## Updates and personal data

Close EVE Mining before replacing program files with a complete newer release.
Keep a backup of **EVE-Ice-Monitor.state.json**: it contains your profiles,
cargo counters, custom prices and session. Do not upload this file to GitHub.
The release ZIP excludes personal profiles and session data.

## Source / build

The release includes the PowerShell source, the C# GUI launcher and
**Build-EVE-Mining.ps1**. Use Windows PowerShell to rebuild the launcher.
See **README-EVE-Mining-Monitor.txt** for detailed behavior and data sources.

Corp logo supplied by the creator. EVE Online item data comes from CCP's
Static Data Export; Janice prices are imported by the user.
