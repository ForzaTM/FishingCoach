-- ReelGold: general fishing tips (based on WoW: Forever fishing rules).
-- Context-aware tips (lure missing, day/night, season, Extravaganza, ...)
-- are generated in Core\Recommend.lua.
local _, ns = ...

ns.Tips = {
    { icon = "Interface\\Icons\\INV_Misc_Orb_03",
      text = "Always keep a lure on your pole. Below skill 25 a Shiny Bauble guarantees catches in starting zones." },
    { icon = "Interface\\Icons\\Trade_Fishing",
      text = "In Forever every zone has a skill requirement: once you reach it, every catch succeeds. Poles, lures, food and gear raise your effective skill." },
    { icon = "Interface\\Icons\\INV_Fishingpole_02",
      text = "Better poles: Strong Fishing Pole (+5, vendor), Big Iron Fishing Pole (+20, Desolace Shellfish Traps), Nat Pagle's FC-5000 (+25, Horde quest, Hinterlands), Arcanite Fishing Pole (+35, Extravaganza)." },
    { icon = "Interface\\Icons\\INV_Misc_Food_14",
      text = "Fishing food stacks with lures: Bristle Whisker Catfish (+8), Rockscale Cod (+12), Filet of Redgill / Spinefin Halibut (+18)." },
    { icon = "Interface\\Icons\\INV_Misc_Fish_14",
      text = "Schools (pools) hold the valuable fish. If your bobber lands outside the school, recast immediately." },
    { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
      text = "Stranglethorn Fishing Extravaganza: Sundays 2-4 PM realm time. The first 50 players to finish win rewards such as the Arcanite Fishing Pole." },
    { icon = "Interface\\Icons\\INV_Misc_Book_09",
      text = "Expert fishing: Old Man Heming in Booty Bay. Artisan: Nat Pagle in Dustwallow Marsh (level 35, needs Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker and Savage Coast Blue Sailfin)." },
    { icon = "Interface\\Icons\\INV_Misc_Coin_01",
      text = "Check prices before you farm: oils (Blackmouth, Firefin) and Stonescale Eel follow alchemist demand, raid foods spike before raid nights." },
    { icon = "Interface\\Icons\\INV_Misc_Gear_01",
      text = "Fishing Rack (skill 140) catches uncommon fish for an hour and Fishing Hut (skill 300) catches rare fish - place them where you fish." },
    { icon = "Interface\\Icons\\INV_Misc_Fish_02",
      text = "Legacy perk Luremaster gives a 25-50% chance for an extra fish while a lure is active." },
    { icon = "Interface\\Icons\\Trade_Engineering",
      text = "ReelGold only reads loot and prices. Casting and looting stay manual, as Blizzard's rules require - never use bots or automation." },
}
