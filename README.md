# ReelGold — fishing gold tracker for WoW: Forever

Tracks how much gold your fishing makes per minute, per hour or per a custom
number of minutes, ranks the most profitable fishing spots for your skill, and
shows fishing tips that fit the moment. Item names and icons always come
from the game client, so you see the real items.

## Features
- **Session**: gold per time unit (counting active fishing time only), catches,
  coins looted, and a catch log with real item icons and values.
- **Spots**: ranked by expected gold/hour with your current prices. Once you
  have fished a zone long enough, the ranking uses your own catch data, which
  also covers new Forever zones.
- **Tips**: lure missing, skill cap and trainer, Nightfin vs Sunscale (day/night),
  Summer Bass vs Winter Squid (season), Stranglethorn Fishing Extravaganza reminder.
- **Prices**: Auctionator or TradeSkillMaster if installed (optional), vendor
  price otherwise, 5% AH cut option, and manual per-item prices (drag an item in).
- Compact HUD, minimap button, Addon Compartment entry.

Commands: `/rgold` or `/reelgold` with `show`, `session`, `spots`, `tips`,
`settings`, `hud`, `reset`, `minimap` or `version`.

## Blizzard policy
ReelGold only reads information (loot window, prices from other addons, your
skill and equipment) and displays it. It does not cast, loot, click, move, or
automate anything, does not scan or post on the Auction House, and does not
send data anywhere. It follows the UI Add-On Development Policy and is free.

## Testing without the game
`tests/` runs the real addon files against a fake WoW API (`tests/wowmock.lua`)
using Fengari, a Lua interpreter written in JavaScript. It simulates fishing
loot, prices from Auctionator/TSM, idle breaks, day/night, seasons, skill
levels and new zones, clicks every button and tooltip, and prints an example
session report.

```
npm install
npm test
```

The mock uses Lua 5.3 while WoW uses Lua 5.1, and its item prices are test
values. It proves the logic works; it can't prove how the real client draws
the window, so still check it in game after big changes.

## Updating for a new WoW: Forever patch
All game knowledge lives in `Data/` and every client API call goes through
`Core/Compat.lua`, so a patch usually touches only those files.

1. In game, read the new interface number: `/dump select(4, GetBuildInfo())`
2. Point the addon at it:
   ```
   python tools/release.py bump --interface 16002 --client 1.60.2
   ```
3. If fishing content changed, edit `Data/Fish.lua`, `Data/Locations.lua` or
   `Data/Tips.lua`, then `python tools/release.py data --note "what changed"`.
4. If Blizzard renamed an API, fix it in `Core/Compat.lua` (and the matching
   fake in `tests/wowmock.lua`), then run `npm test`.
5. Add saved-variable migrations in `Core/Init.lua` (`MIGRATIONS`) if you ever
   change the saved data layout, so user data is never wiped.
6. Commit, tag and push:
   ```
   git commit -am "Update for 1.60.2"
   git tag v1.1.0
   git push --follow-tags
   ```

## Publishing on CurseForge
- Automatic: create the CurseForge project, add `## X-Curse-Project-ID: <id>`
  to `ReelGold.toc`, add a `CF_API_KEY` secret to the GitHub repository. Every
  `v*` tag then builds and uploads through `.github/workflows/release.yml`.
- Manual: `python tools/release.py package --version 1.0.0` and upload
  `dist/ReelGold-1.0.0.zip`.

## Layout
```
ReelGold.toc          Addon manifest (interface version lives here)
Data/                 Game data: version info, fish, spots, tips
Core/Compat.lua       Every WoW API call (one place to fix after patches)
Core/Pricing.lua      Auctionator / TSM / vendor / manual prices
Core/Tracker.lua      Session + per-zone statistics from fishing loot
Core/Recommend.lua    Spot ranking and context tips
Core/Init.lua         Saved variables, migrations, events, slash commands
UI/                   Main window, HUD, minimap button
tools/release.py      bump / data / package helper
tests/                Offline tests with a mocked WoW API (npm test)
```
