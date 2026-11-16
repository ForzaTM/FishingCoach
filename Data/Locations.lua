-- Fishing Coach: seed fishing spots.
--
-- These are starting ESTIMATES based on the vanilla fishing tables Forever is
-- built on. As soon as you fish a zone long enough (Settings: "learn after N
-- catches"), Fishing Coach uses YOUR real catch data for that zone instead, and new
-- Forever zones (Riverglades, Mount Hyjal, Zephras Isle, ...) are ranked from
-- your own data automatically.
--
-- Fields:
--   key            unique id
--   mapID          uiMapID (used to match your current zone and localize the name)
--   zone           English fallback name
--   spot           where in the zone to stand
--   minSkill       approx. skill for no "got away" (Forever: all catches succeed at this skill)
--   catchesPerHour realistic catches/hour incl. moving between pools
--   junkCopper     average vendor value of grey junk per catch (copper)
--   loot           { itemID, share per catch [, time="day"|"night"] [, season="summer"|"winter"] }
--   tip            shown in the spot tooltip
--   x, y           APPROXIMATE map position (0-1) for the map marker; only set where a
--                  clear landmark is known. Your own catch positions replace it.
local _, ns = ...

ns.Locations = {
    {
        key = "barrens_oasis", x = 0.52, y = 0.32, mapID = 1413, zone = "The Barrens",
        spot = "Lushwater Oasis / Forgotten Pools",
        minSkill = 75, catchesPerHour = 260, junkCopper = 6,
        loot = { {6522, 0.35}, {6289, 0.35}, {21071, 0.12}, {6308, 0.05} },
        tip = "Deviate Fish only bites in the oases. Sell raw or cook Savory Deviate Delight.",
    },
    {
        key = "westfall_coast", x = 0.30, y = 0.48, mapID = 1436, zone = "Westfall",
        spot = "Western coast (Oily Blackmouth schools)",
        minSkill = 75, catchesPerHour = 220, junkCopper = 6,
        loot = { {6358, 0.45}, {6361, 0.25}, {6359, 0.10} },
        tip = "Fish into schools only. Blackmouth sells to alchemists for Swiftness/Rage potions.",
    },
    {
        key = "darkshore_coast", x = 0.36, y = 0.48, mapID = 1439, zone = "Darkshore",
        spot = "Coast between Auberdine and the Master's Glaive",
        minSkill = 75, catchesPerHour = 220, junkCopper = 6,
        loot = { {6358, 0.40}, {6361, 0.28}, {6359, 0.12} },
        tip = "Lots of schools close together. Good Alliance-side oil farm.",
    },
    {
        key = "wetlands_coast", x = 0.11, y = 0.57, mapID = 1437, zone = "Wetlands",
        spot = "Menethil Harbor coast",
        minSkill = 150, catchesPerHour = 230, junkCopper = 10,
        loot = { {6359, 0.30}, {6358, 0.25}, {6362, 0.20} },
        tip = "Firefin Snapper is the main money maker here (Fire Oil).",
    },
    {
        key = "hillsbrad_inland", mapID = 1424, zone = "Hillsbrad Foothills",
        spot = "Rivers and lakes (Sagefish schools)",
        minSkill = 150, catchesPerHour = 260, junkCopper = 10,
        loot = { {6308, 0.35}, {8365, 0.25}, {21071, 0.20} },
        tip = "Murlocs here drop Enchant Gloves - Fishing. Sagefish schools respawn quickly.",
    },
    {
        key = "stv_coast", x = 0.26, y = 0.70, mapID = 1434, zone = "Stranglethorn Vale",
        spot = "Coast north of Booty Bay",
        minSkill = 225, catchesPerHour = 250, junkCopper = 18,
        loot = { {6362, 0.35}, {4603, 0.30}, {6359, 0.08}, {6358, 0.07} },
        tip = "Sunday 2-4 PM: Stranglethorn Fishing Extravaganza. Old Man Heming (Expert) is in Booty Bay.",
    },
    {
        key = "dustwallow_coast", x = 0.68, y = 0.50, mapID = 1445, zone = "Dustwallow Marsh",
        spot = "Theramore coast",
        minSkill = 225, catchesPerHour = 250, junkCopper = 18,
        loot = { {4603, 0.35}, {13754, 0.25}, {6362, 0.15} },
        tip = "Nat Pagle (Artisan quest) is on the island east of Theramore. Lord Angler drops the Ravaged Fishing Pole.",
    },
    {
        key = "tanaris_coast", x = 0.68, y = 0.24, mapID = 1446, zone = "Tanaris",
        spot = "Steamwheedle Port / Lost Rigger Cove coast",
        minSkill = 300, catchesPerHour = 240, junkCopper = 25,
        loot = { {13754, 0.30}, {4603, 0.25}, {13756, 0.25, season = "summer"}, {13755, 0.25, season = "winter"} },
        tip = "Summer Bass and Winter Squid rotate with the season.",
    },
    {
        key = "feralas_coast", x = 0.29, y = 0.45, mapID = 1444, zone = "Feralas",
        spot = "Sardor Isle / Feathermoon coast (Stonescale schools)",
        minSkill = 300, catchesPerHour = 210, junkCopper = 25,
        loot = { {13422, 0.30}, {13893, 0.15}, {13888, 0.10}, {13756, 0.20, season = "summer"}, {13755, 0.20, season = "winter"} },
        tip = "Stonescale Eel only comes from schools - hop between them.",
    },
    {
        key = "azshara_coast", mapID = 1447, zone = "Azshara",
        spot = "Eastern coast / Bay of Storms (Stonescale schools)",
        minSkill = 330, catchesPerHour = 210, junkCopper = 30,
        loot = { {13422, 0.35}, {13893, 0.15}, {13757, 0.08}, {7973, 0.03}, {13756, 0.15, season = "summer"}, {13755, 0.15, season = "winter"} },
        tip = "Best Stonescale Eel farm. Big-mouth Clams can hold Golden Pearls.",
    },
    {
        key = "hinterlands_inland", mapID = 1425, zone = "The Hinterlands",
        spot = "Rivers and lakes (Greater Sagefish schools)",
        minSkill = 300, catchesPerHour = 250, junkCopper = 25,
        loot = { {13889, 0.30}, {13758, 0.25}, {21153, 0.20}, {8365, 0.10} },
        tip = "Horde: the Nat Pagle's Extreme Angler FC-5000 quest is here.",
    },
    {
        key = "winterspring_inland", x = 0.53, y = 0.45, mapID = 1452, zone = "Winterspring",
        spot = "Lakes near Everlook",
        minSkill = 330, catchesPerHour = 260, junkCopper = 30,
        loot = { {13889, 0.25}, {13758, 0.20}, {13759, 0.35, time = "night"}, {13760, 0.35, time = "day"} },
        tip = "Night: Nightfin Snapper (raid mana soup). Day: Sunscale Salmon.",
    },
    {
        key = "felwood_inland", mapID = 1448, zone = "Felwood",
        spot = "Lakes and rivers",
        minSkill = 300, catchesPerHour = 260, junkCopper = 28,
        loot = { {13758, 0.30}, {13759, 0.35, time = "night"}, {13760, 0.35, time = "day"} },
        tip = "Fish at night for Nightfin Snapper - steady raid demand.",
    },
    {
        key = "ungoro_inland", mapID = 1449, zone = "Un'Goro Crater",
        spot = "Lakeshore and Fire Plume Ridge pools",
        minSkill = 300, catchesPerHour = 250, junkCopper = 28,
        loot = { {13758, 0.30}, {13759, 0.35, time = "night"}, {13760, 0.35, time = "day"} },
        tip = "Combine with herbalism/mining here for extra gold per hour.",
    },
    {
        key = "wpl_inland", x = 0.62, y = 0.72, mapID = 1422, zone = "Western Plaguelands",
        spot = "Darrowmere Lake",
        minSkill = 300, catchesPerHour = 260, junkCopper = 28,
        loot = { {13758, 0.25}, {13889, 0.10}, {13759, 0.35, time = "night"}, {13760, 0.35, time = "day"} },
        tip = "Quiet lake with short walks between casts.",
    },
}
