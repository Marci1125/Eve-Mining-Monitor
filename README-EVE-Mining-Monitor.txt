EVE Mining 1.0 - English interface

START / SHARE
Close the old monitor, then start EVE-Mining.exe directly. The .cmd launchers also start this EXE.
This is a Windows GUI executable with an embedded Windows PowerShell runspace. No separate PowerShell/Terminal window is launched.
Keep the EXE, .exe.config, all EVE-Mining-*.ps1 files, EVE-Ice-Monitor.ps1 and EVE-Mining-Volumes.json together in a writable folder.
Requires Windows PowerShell 5.1 and .NET Framework 4.8 (Windows 10/11). No Python or EVE login.
The launcher permits one EXE instance per Windows session. Close an older script-based instance before starting the EXE.
Existing profiles, cargo and income quantities are migrated. Old raw price estimates are retained for reference but no longer used as BUY quotes.
Send EVE-Mining-Monitor-Share.zip to friends. Extract into a new folder before starting.
The ZIP excludes your state, characters, profiles, log paths, scan, price cache and local price seeds.
Source is included. Build-EVE-Mining.ps1 optionally rebuilds the launcher; run it using powershell.exe.

FLEET PROFILES
Open Fleet / prices > Fleet profiles.
Choose your EVE Gamelogs folder; the Windows Documents folder is suggested automatically.
Add pilots from logs, or enter exact Listener names manually.
Choose each ship class and its actual hold capacity from EVE, including skills and fitting.
Enable Use for pilots to track. Choose ICE or ORE and Save and activate profile.
To create another setup, load one into the editor, change its name and edit the ships/capacities before saving.
Use the main dropdown to switch saved setups. Class/capacity changes mark cargo CHECK; they do not restore fictional old cargo.
Current cargo belongs to each character and is kept when switching profiles. Confirm or correct it after changing ships.
Delete profile removes a setup, retaining cargo and session history.

COMPACT OVERLAY / CARGO
Compact is the default. Expand shows free volume, per-pilot session value and last event.
Hover over a pilot/cargo line for details. Right-click a pilot name, cargo bar or cargo text to Set current cargo in m3.
Reset clears one pilot. Reset all clears only the active fleet's cargo. Neither clears income.
Use these after jettison, full transfers or station unloading; partial transfers require a manual remaining-volume correction.
On top, compact/expanded view and position are saved. Larger fleets scroll.
ICE shows how many additional standard 1,000 m3 blocks fit. ORE uses each item's individual m3 per unit, including mixed cargo.
Changing modes preserves all cargo and counts supported yields in both modes.
Green = available capacity. Yellow = critical yield for 30 seconds from its EVE UTC timestamp.
Red = 95% capacity or higher, taking priority over critical yellow. ICE also turns red if less than 1,000 m3 remains.
A further critical extends yellow to 30 seconds after that event. Cargo still updates every second.
CHECK = verify starting cargo. UNCOUNTED = an unsupported/mismatched event requires manual correction.

ON-GRID COMPRESSION
The monitor reads this notification in the affected character's log:
[ 2026.10.30 14:39:46 ] (notify) Successfully compressed Arkonor into 267 Compressed Arkonor.
Modern compression keeps unit quantity 1:1 and replaces the raw volume with the compressed item's volume from the CCP table.
Example: 267 Arkonor = 4,272 m3; 267 Compressed Arkonor = 42.72 m3.
Example: 44 Clear Icicle IV-Grade = 44,000 m3; compressed = 4,400 m3.
Compressed cargo remains onboard and is added to later raw mining yields. Repeated mining/compression cycles are supported.
Compression does NOT add mined units, income or critical/activity events.
The monitor tracks item quantities to avoid compressing the same tracked raw cargo twice.
Migrated/manual cargo without material detail can be compressed if sufficient unassigned volume exists.
If the log requests more raw material than the tracked cargo can contain, volume is kept and UNCOUNTED is shown; correct the actual cargo instead of allowing negative/free cargo.
Obsolete Batch Compressed conversions are not assumed to be modern 1:1.
Station compression after an unlogged unloading/transfer may therefore be flagged for manual correction.

JANICE BUY PRICE SETS
Income is now based on BUY quotes only. CCP averages and the earlier rounded belt-scan estimates are not used.
For a mined raw item, the corresponding modern Compressed item BUY price has priority (one raw unit = one compressed unit).
This is an estimated gross value if compressed and sold to those buy orders, before tax, fees, freight or price movement.
It is not wallet income. Missing BUY prices are excluded and flagged as PARTIAL.

Initial price-set workflow:
1. Open Fleet / prices > Prices / Janice.
2. Click Copy compressed list. Or use Janice-Compressed-Input.txt: all 186 matching modern compressed ore/ice types, one unit each, from the bundled table.
3. Open Janice, paste the list, and appraise at your chosen location/settings.
4. Copy its result rows, including Item / Amount / Volume / Buy / Sell.
5. Import Janice prices and paste the rows. Only BUY is imported; SELL and Volume never become the price.
6. The price set is saved locally and used to recalculate the existing session quantities.

Example accepted row (tabs or whitespace):
Compressed Clear Icicle IV-Grade  1  100.00  260100.00  285000.00
Result: 260,100 ISK per unit, not 285,000.
For Amount > 1, Buy is treated as the row's total Buy value and divided by Amount. Prefer the generated Amount=1 list to avoid ambiguity.
English and German number formats are supported. Duplicate rows are combined using total Buy / total Amount.
The filter finds items. Buy ISK / unit is an editable per-unit manual BUY override; Save price overrides persists it.
Clear an override to remove it. Zero is an intentional zero valuation, not a missing quote.
Used buy / unit shows the effective price, including a matching compressed quote inherited by a raw item.
Save pending price-grid edits before importing; import repopulates the grid.
No online prices are fetched automatically. Janice price sets remain fixed until edited/reimported.
The Janice page was not fetched by the app: the import uses the table you paste.
Your local installation includes the supplied single-item example as a one-time BUY seed (260,100 ISK). It is excluded from the share ZIP.

MINING INCOME
Only new mining log events, including critical additional yield, add session quantities.
Session total changes with yield; the large green ISK/h number is refreshed only every 60 seconds.
New session clears income/trend and refreshes the headline immediately, keeping cargo.
ISK/h = session estimated value / active elapsed session time. Explicit Session pauses are excluded, including a pause while the app is closed. Time closed without pausing remains part of the session.
Session start and mined quantities survive restarts; switching profiles keeps the same income session.
The trend shows ten one-minute yield-value buckets, each extrapolated to ISK/h. It is not a ten-minute rolling average.
Changing prices revalues the session totals immediately; the large rate number catches up at the next 60-second refresh.

ADAPTIVE CYCLE TIMING / IRREGULAR MINING
Fleet profiles include Lasers and Raw cycle (s). Existing Cycle values are kept and now treated as unboosted reference values.
Barges/exhumers, Venture and Prospect default to 2 expected harvesters; Endurance defaults to 1.
Porpoise, Orca and Rorqual are excluded from mining-activity alerts. Lasers=0 disables activity hints for other ships.
For Abyssal modules with different timings, the slower unboosted cycle is acceptable as an approximate reference.
Raw cycle=0 means no unboosted reference is supplied. Actual timing is still learned from regular mining events.
The observed cycle is an equivalent aggregate cycle derived from recent regular yield timing for all expected lasers, not a separate measurement of each laser.
Hover over a cargo line or use Expand to see the effective/observed timing, reference and speed difference.
A faster measured rate can be consistent with boosts, but does not identify the boost ship, skills, implants or siege state.
Unequal laser speeds, partial cycles or drones can also change the observed rate; the monitor does not claim a particular boost is active.
Comparable fleet ships are compared relative to their own unboosted references where available.
The detector adapts to both faster and slower sustained rates, rather than retaining the fastest cycle ever observed.
A substantial fleet timing change gives a settling period to reduce false activity warnings when boosts start or end.
After warm-up, IRREGULAR flags a substantially lower regular event rate than expected (possible missing laser).
NO YIELD in the tooltip/details flags a silent ship while another mining ship is still producing yields.
Critical bonus lines do not count as separate lasers. Near-full/red and unconfirmed cargo states suppress activity warnings.
Reset/profile changes begin a grace period. Fleet-relative silence warnings are suppressed if everyone stops.
These are hints: logs cannot prove module state. Depleted rocks, travel, unequal modules, skills, boosts, drones and intentional pauses can affect them.
A solo ship missing a laser from startup, particularly under unknown boosts, cannot always be distinguished from a genuinely slower cycle.
Cycle timing affects activity hints only. Cargo and income continue to use the actual quantities and volumes from mining logs.

ATTACK SOUND / COMBAT INDICATOR
Attack sound in the main window enables/disables a short Windows Exclamation tone. This preference is saved.
Incoming combat hits ('34 from Blood Friar - Hits') and incoming misses ('Blood Archbishop misses you completely') trigger detection.
Outgoing player/drone hits and outgoing misses do not trigger it. The detector also works for Porpoise/Orca/Rorqual in the active fleet.
It detects incoming attacks generally, including NPC or player attackers; it does not infer NPC identity from a name.
One tone at most every 30 seconds across the fleet avoids constant beeping during combat.
The active character is visually marked ATTACK and the attacker is shown for 45 seconds after the latest incoming event.
Muting sound keeps visual indications enabled. Combat does not alter cargo or income.
Existing historical combat lines do not play sounds: only incoming events no more than 15 seconds old are eligible.
The tone uses Windows system audio and respects system mute/volume settings.
The custom mining icon is embedded in the EXE and loaded for the main window from EVE-Mining.ico.

LOGS / STORAGE
Only complete new log lines are processed once. Residue is excluded.
The latest session per active pilot is watched. Existing history at first detection is skipped because past transfers are unknown.
New/re-enabled characters start at the current end of their log and require a cargo confirmation.
Unlogged transfers/jettison/unloading, including while the monitor is closed, still require Reset or manual volume correction.
EVE-Ice-Monitor.state.json stores profiles, cargo inventories, income, log positions, BUY quotes and preferences.
The optional EVE-Mining-Buy-Seed.json imports local initial BUY quotes; it is archived as .imported after saving price overrides.
Older saved raw/scan estimates may remain labelled Legacy estimate (ignored) until removed.
The program reads local EVE logs. It does not steer EVE or automate gameplay.

SOURCES
Offline volume table: CCP Static Data Export downloaded 2026-11-01; 499 asteroid-category entries, including all 14 raw ice types and modern compressed variants.
Future CCP item/volume changes require updating the bundled table.
https://developers.eveonline.com/docs/services/static-data/
https://forums.eveonline.com/t/details-on-forthcoming-improvements-to-compression-mechanics/349870/1
Pasted BUY quotes:
https://janice.e-351.com/

CARGO VERIFICATION LABEL
VERIFY CARGO (previously CHECK) is an unconfirmed cargo start value, not an irregular-mining warning. Right-click a character > Confirm displayed cargo if the value matches EVE. Right-click Reset all > Confirm all displayed cargo values to confirm the whole active fleet without resetting amounts or income. Incorrect values need Set current cargo; unsupported/uncounted events must be corrected first. Confirmation is saved.


IRREGULAR RECOVERY
IRREGULAR clears automatically once the latest approximately two cycles contain the expected number of regular yield events. It no longer waits for the entire older detection window to recover. Critical bonus lines still do not count as additional lasers. Cargo and income are unchanged.


CARGO ETA
Approximate time until full appears next to blocks fit (also in ORE mode). Based on actual recent mined m3 over up to five minutes, including critical yield, with at least 30 seconds between observed yields. ICE counts only complete 1,000 m3 blocks that fit. Reset/corrections/compression recalculate remaining capacity while keeping the recent rate. ETA learning / paused / verify / unknown indicate insufficient activity or unconfirmed data; boosters without yields show ETA --. Assumes continued mining without future transfers/compression. Hover for m3/min. Estimates actual fullness rather than the red 95% warning.


FLEET FREE SPACE
Below Fleet / prices, Miners free shows total remaining whole ice-block capacity (ICE) or free m3 (ORE) across active non-booster ships. Porpoise, Orca and Rorqual are excluded. Whole block capacity is rounded down per ship before summing, so unusable sub-1,000 m3 remainders are never combined into a fictional slot. Hover for the per-character breakdown. Unconfirmed/unknown cargo is explicitly marked for verification. Assumes no further compression/transfers.


INDIVIDUAL ABYSSAL LASER CADENCE
Stable unequal two-laser cadence is calibrated per character against the fleet timing reference. A ship with slower 43s/46s harvesters can remain healthy even while peers are substantially faster. Once calibrated, the character-specific offset is retained for activity comparison so a later genuine missing laser can still be flagged. Initial individual calibration requires several regular yields and relearns after a profile change/restart. It changes activity hints only, not cargo, quantities, prices or income.


SESSION PAUSE
Pause session freezes the active session timer. Resume session or the next mining yield continues the same totals without counting the paused interval in ISK/h. The first resumed yield is included. Cargo, compression tracking and incoming-attack sound/visual alerts remain active. Mining-activity hints are suppressed during a deliberate pause. The pause state is saved across restarts. New session clears income and pause history while keeping cargo. Pause/resume refreshes the ISK/h headline immediately.

AUTOMATIC SESSION PAUSE
After five minutes without any mining yield across the active fleet, the session pauses automatically. Boost/combat/other notifications do not reset the mining inactivity timer. The five-minute wait remains active session time; the following paused interval is excluded from ISK/h. The next mining event automatically resumes and is counted, including after a manual pause. Cargo/compression tracking and attack warnings remain active. Pauses and last mining time are saved, and multi-client backlog yields are processed chronologically to avoid false idle gaps. New session clears income, pause intervals and inactivity history, starting a fresh session while retaining actual cargo counters.

VERSION 1.0 RELEASE
Tool created by Marcel Ijonen [NO.W8]. Corp logo supplied by the creator.
See QUICK-SETUP.txt or the in-app Quick setup link for first-time setup. A Quick setup window appears on a fresh installation.
186 creator-supplied BUY quotes are bundled in EVE-Mining-Default-Prices.json with a UTC snapshot timestamp. These are defaults, not live quotes. Existing personal BUY prices take priority. Defaults are applied once; clearing an override remains effective after restart.
AppVersion 1.0 is separate from the internal state schema version.
Fixed: transient log-read errors no longer advance some cargo cursors while losing the matching session income. A complete read batch succeeds before state is changed.
