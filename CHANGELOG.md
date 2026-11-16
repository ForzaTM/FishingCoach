# Changelog

## Unreleased
- Windows installer: finds WoW: Forever on your PC and installs, updates or removes ReelGold.
- Spots where you already have your own catch data are no longer marked as too hard for your skill.
- Added an offline test suite (`npm test`) that runs the addon against a mocked WoW API.

## 1.0.0 (2026-11-16)
- First release for WoW: Forever 1.60.1 (interface 16001).
- Session tracker: gold per minute / hour / custom minutes, counting active fishing time only.
- Prices from Auctionator or TradeSkillMaster when installed, vendor price otherwise, plus manual per-item prices.
- Spot ranking from estimates, replaced by your own catch data per zone (also covers new Forever zones).
- Context tips (lure, skill cap, day/night fish, season, Extravaganza) and a general tips list.
- Compact HUD, minimap button and Addon Compartment entry.
