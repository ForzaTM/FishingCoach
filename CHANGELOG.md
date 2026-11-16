# Changelog

## Unreleased
- **Renamed from ReelGold to Fishing Coach.** Folder `FishingCoach`, commands `/fcoach` and `/fishingcoach`. The installer removes the old ReelGold folder and carries your settings and fishing history over.
- Gear checklist shows what you already have (green highlight with a check mark) and what another of your characters carries (blue: mail it over; soulbound items excluded). The first page lists what you can get now at your skill; items for a higher skill come later.
- New "How to use" tab with a short guide; it opens by itself on the very first launch. `/fcoach guide` opens it again.
- Window is a bit wider (560 px) to fit six tabs.
- Tips tab: checklist of fishing gear you're missing and where to get it: better pole (faction-aware), strongest usable lure, Fish Bowl / Fishing Rack / Fishing Hut, Lucky Fishing Hat, Anglin' Boots, Eternium Fishing Line and the gloves fishing enchant. Checks your bags, bank and equipped items; item icons with tooltips.
- The 5% AH cut toggle is on the Settings tab (and in Options); switching it updates totals and gold per time at once. The gold-per-time label says whether the cut is applied.
- Update notices on top of the Fishing Coach window: when WoW: Forever is patched (a Fishing Coach update is then likely) and after Fishing Coach itself was updated. Settings shows a copyable link to the latest releases. Fishing Coach still sends nothing: no addon or chat messages.
- Catch log shows each item's price exactly as on the Auction House (tagged AH / vendor / set); the total column is labelled "after 5% AH cut". Item tooltips show AH price, after-cut value, vendor price and what Fishing Coach counts.
- Prices update by themselves after every Auctionator scan (and when you close the Auction House). New "Refresh prices" button and price status (source, how many fish have AH prices, how old) in the window title bar; `/fcoach prices` does the same. Item tooltips show when Auctionator last saw the item.
- Fishing Coach now uses its own logo (addon list, minimap button, window title, HUD, Options page and addon compartment) instead of the generic fishing icon.
- New "For me" tab: your top 3 spots for your current skill with catches and tips, plus the next better-paying spot to unlock and the quickest way to get the skill. `/fcoach best` opens it.
- The HUD has a close button (X). Show it again with `/fcoach hud`, a right-click on the minimap button, or in Settings.
- New Fishing Coach page in Options -> AddOns with the main settings and an "Open Fishing Coach" button. `/fcoach options` opens it.
- Spots list: no empty separator for zones known only from your own data.

## 1.0.1 (2026-11-16)
- Fix: spots where you already have your own catch data are no longer marked as too hard for your skill.
- New Windows installer (FishingCoach-1.0.1-windows-installer.zip): finds WoW: Forever on your PC and installs, updates or removes Fishing Coach.
- Added an offline test suite (`npm test`) that runs the addon against a mocked WoW API.
- Releases now run the tests first and attach the Windows installer.

## 1.0.0 (2026-11-16)
- First release for WoW: Forever 1.60.1 (interface 16001).
- Session tracker: gold per minute / hour / custom minutes, counting active fishing time only.
- Prices from Auctionator or TradeSkillMaster when installed, vendor price otherwise, plus manual per-item prices.
- Spot ranking from estimates, replaced by your own catch data per zone (also covers new Forever zones).
- Context tips (lure, skill cap, day/night fish, season, Extravaganza) and a general tips list.
- Compact HUD, minimap button and Addon Compartment entry.
