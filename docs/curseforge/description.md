# ReelGold

**How much gold does your fishing really make, and where should you fish next?**
ReelGold tracks your fishing income per minute, per hour or per any number of
minutes you choose, ranks the most profitable fishing spots for your skill, and
gives you fishing tips that fit the moment. Made for **World of Warcraft: Forever**.

## Features

### Gold per time, honestly measured
- Gold **per minute**, **per hour** or **per custom minutes** (one click to switch).
- Counts **active fishing time only**: AFK breaks, travel and bank trips don't drag your rate down. The session pauses itself after 5 minutes without a catch (adjustable).
- Catch log with the real item icons, counts, unit value and total, sorted by value.
- Coins looted from fishing are included.

### Best fishing spots for you
- Spots ranked by **expected gold per hour with your current prices**.
- Shows the skill each spot needs and marks the ones you can fish right now.
- Hover a spot for its main catches, catch rates and a tip.
- **Learns from your own catches:** after 40 catches in a zone, its ranking uses your real results instead of estimates. New Forever zones are ranked automatically as soon as you fish them.

### Tips that fit the moment
- No lure on your pole, or about to expire.
- Skill capped, and where to train next (Old Man Heming, Nat Pagle).
- Night or day: Nightfin Snapper vs Sunscale Salmon.
- Summer Bass vs Winter Squid by season.
- Stranglethorn Fishing Extravaganza reminder on Sundays.
- Plus a list of general fishing tips: poles, lures, fishing food, schools, Fishing Rack and Hut.

### Prices
- Uses **Auctionator** or **TradeSkillMaster** prices when installed (both optional).
- Falls back to vendor prices.
- Optional 5% Auction House cut.
- Set your own price for any item: drag it onto the price box.

### Small and out of the way
- Compact HUD you can drag anywhere. It shows only while a fishing pole is equipped (optional).
- Minimap button and Addon Compartment entry.
- Every icon and item name comes straight from the game client, in your language.

## Commands
`/rgold` (or `/reelgold`) opens the window. Add one of:
- `spots`, `tips`, `settings` or `session` to open that tab
- `hud` to show or hide the HUD
- `reset` to start a new session
- `minimap` to show or hide the minimap button
- `version` to show the addon and data version

## What ReelGold does not do
ReelGold **only reads and displays** information: your fishing loot, your skill
and gear, and prices from other addons. It does **not** cast, loot, click, rebind
keys, scan or post on the Auction House, send chat or addon messages, or connect
anywhere. Fishing stays 100% manual, as Blizzard's rules require. ReelGold is
free and its code is open on GitHub.

## Good to know
- Spot values start as estimates based on the classic fishing tables Forever is built on. They get better the more you fish, because your own catches replace them.
- Your settings and fishing history are saved per account and survive updates.

## Install
- **CurseForge app:** click Install.
- **Manually:** unzip into `World of Warcraft\_forever_\Interface\AddOns\`, so you end up with `AddOns\ReelGold\ReelGold.toc`.
- **Windows installer:** download it from the GitHub releases page. It finds your WoW: Forever folder for you.

## Feedback and bugs
Please report bugs and ideas on GitHub: https://github.com/ForzaTM/ReelGold/issues
If something looks wrong, include the output of `/rgold version`.
