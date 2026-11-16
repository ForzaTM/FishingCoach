-- ReelGold: fishing gear that makes fishing more efficient, and where to get it.
-- Item IDs verified (classic items against Wowhead Classic; Forever camping
-- items from warcraft.wiki.gg). Names here are English fallbacks only: the
-- addon shows the client's real, localized name and icon.
-- Fields: id, name, bonus (+fishing), minSkill, faction ("Alliance"/"Horde"),
--         source (where to get it), note (extra info)
local _, ns = ...

ns.Gear = {
    poles = {
        { id = 6256,  name = "Fishing Pole",                        bonus = 0,  minSkill = 1,
          source = "Fishing supply vendors (near every fishing trainer)" },
        { id = 12225, name = "Blump Family Fishing Pole",           bonus = 3,  minSkill = 1, faction = "Alliance",
          source = "Alliance quest in Darkshore" },
        { id = 6365,  name = "Strong Fishing Pole",                 bonus = 5,  minSkill = 10,
          source = "Fishing supply vendors" },
        { id = 6367,  name = "Big Iron Fishing Pole",               bonus = 20, minSkill = 100,
          source = "Shellfish Traps in Desolace (tradable, so also on the Auction House)" },
        { id = 19022, name = "Nat Pagle's Extreme Angler FC-5000",  bonus = 25, minSkill = 100, faction = "Horde",
          source = "Horde quest in The Hinterlands" },
        { id = 19970, name = "Arcanite Fishing Pole",               bonus = 35, minSkill = 300,
          source = "Stranglethorn Fishing Extravaganza (Sundays 14:00-16:00), first 50 to finish" },
    },
    lures = {
        { id = 6529, name = "Shiny Bauble",               bonus = 25,  minSkill = 1,   source = "Fishing supply vendors" },
        { id = 6530, name = "Nightcrawlers",              bonus = 50,  minSkill = 50,  source = "Fishing supply vendors" },
        { id = 6811, name = "Aquadynamic Fish Lens",      bonus = 50,  minSkill = 50,  source = "Engineering, or the Auction House" },
        { id = 6532, name = "Bright Baubles",             bonus = 75,  minSkill = 100, source = "Engineering, or the Auction House" },
        { id = 7307, name = "Flesh Eating Worm",          bonus = 75,  minSkill = 100, source = "Auction House" },
        { id = 6533, name = "Aquadynamic Fish Attractor", bonus = 100, minSkill = 100, source = "Engineering, or the Auction House" },
    },
    -- Worn or applied gear (each counts on its own).
    gear = {
        { id = 19972, name = "Lucky Fishing Hat",               bonus = 5, minSkill = 1,
          source = "Stranglethorn Fishing Extravaganza: turn in Keefer's Angelfish" },
        { id = 19969, name = "Nat Pagle's Extreme Anglin' Boots", bonus = 5, minSkill = 1,
          source = "Stranglethorn Fishing Extravaganza: turn in Brownell's Blue Striped Racer" },
        { id = 19971, name = "High Test Eternium Fishing Line", bonus = 5, minSkill = 1,
          source = "Stranglethorn Fishing Extravaganza: turn in Dezian Queenfish",
          note = "Apply it to your pole; ignore this if your pole already has it." },
    },
    -- Enchant on gloves (detected through the gloves' enchant ID).
    glovesEnchant = { enchantID = 845, name = "Enchant Gloves - Fishing", bonus = 2,
        icon = "Interface\\Icons\\Trade_Engraving",
        source = "Formula drops from murlocs in Hillsbrad Foothills; or ask an enchanter" },
    -- WoW: Forever camping utilities (placed near a campfire, 1 hour shared cooldown).
    camping = {
        { id = 279967, name = "Fish Bowl",    minSkill = 20,
          source = "Fishing technique from any fishing trainer", effect = "+8% stats for you and seated friends",
          note = "Craft: 1 Raw Brilliant Smallfish + 1 Empty Vial. +8% stats for you and seated friends." },
        { id = 279965, name = "Fishing Rack", minSkill = 140,
          source = "Blueprint: Fishing Rack drops from Gelihast in Blackfathom Deeps", effect = "catches uncommon fish for 1 hour",
          note = "Craft: 2 Simple Wood, 1 Crystal Vial, 2 Raw Mithril Head Trout. Catches uncommon fish for 1 hour." },
        { id = 279966, name = "Fishing Hut",  minSkill = 300,
          source = "Blueprint: Fishing Hut (drop; source not documented yet)", effect = "catches rare fish for 1 hour",
          note = "Craft: 5 Simple Wood, 2 Bolt of Runecloth, 1 Seasonal Fish Steaks. Catches rare fish for 1 hour." },
    },
}
