-- ReelGold: fish and fishing loot database.
-- Names and icons are NOT stored here: they are always read from the game
-- client by item ID, so they show the real, localized item and icon.
-- `use` is a short hint shown in tooltips.
local _, ns = ...

ns.Fish = {
    -- Low level
    [6291]  = { use = "Cooking (Brilliant Smallfish)" },
    [6303]  = { use = "Cooking (Slitherskin Mackerel)" },
    [6317]  = { use = "Cooking (Loch Frenzy Delight)" },
    [6289]  = { use = "Cooking (Longjaw Mud Snapper)" },
    [6522]  = { use = "Savory Deviate Delight - high AH demand" },
    [21071] = { use = "Sagefish Delight (mana regen food)" },

    -- Mid level
    [6358]  = { use = "Blackmouth Oil - Alchemy (Swiftness / Rage potions)" },
    [6359]  = { use = "Fire Oil - Alchemy (Fire Protection potions)" },
    [6361]  = { use = "Cooking (Rainbow Fin Albacore)" },
    [6308]  = { use = "Cooking (Bristle Whisker Catfish, +fishing food)" },
    [6362]  = { use = "Cooking (Rockscale Cod, +fishing food)" },
    [8365]  = { use = "Cooking (Mithril Head Trout)" },
    [21153] = { use = "Greater Sagefish Delight (mana regen food)" },
    [4603]  = { use = "Cooking (Spotted Yellowtail)" },

    -- High level
    [13754] = { use = "Cooking (Glossy Mightfish)" },
    [13755] = { use = "Cooking (Grilled Squid - agility food) - winter" },
    [13756] = { use = "Cooking (Baked Salmon) - summer" },
    [13757] = { use = "Alchemy / Cooking (Lightning Eel)" },
    [13758] = { use = "Cooking (Filet of Redgill, +fishing food)" },
    [13759] = { use = "Nightfin Soup (mana regen) - night only" },
    [13760] = { use = "Cooking (Sunscale Salmon) - day only" },
    [13888] = { use = "Cooking (Lobster Stew)" },
    [13889] = { use = "Cooking (Baked Salmon)" },
    [13893] = { use = "Mightfish Steak (stamina food)" },
    [13422] = { use = "Alchemy - Elixir of the Mongoose / Flasks: top seller" },

    -- Treasure
    [7973]  = { use = "Open for Golden/Black Pearls and Zesty Clam Meat" },
    [13926] = { use = "Golden Pearl - Jewelcrafting / Enchanting demand" },
}

-- Icons used for UI decoration: the ReelGold logo (our own texture) plus real
-- client textures for everything else.
ns.Icons = {
    logo      = "Interface\\AddOns\\ReelGold\\Media\\Icon",
    fishing   = "Interface\\Icons\\Trade_Fishing",
    pole      = "Interface\\Icons\\INV_Fishingpole_02",
    coin      = "Interface\\Icons\\INV_Misc_Coin_01",
    map       = "Interface\\Icons\\INV_Misc_Map_01",
    book      = "Interface\\Icons\\INV_Misc_Book_09",
    gear      = "Interface\\Icons\\INV_Misc_Gear_01",
    lure      = "Interface\\Icons\\INV_Misc_Orb_03",
    clock     = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    question  = "Interface\\Icons\\INV_Misc_QuestionMark",
}
