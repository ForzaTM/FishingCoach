-- Minimal fake World of Warcraft API, just enough to run ReelGold outside
-- the game. Everything the tests control lives in the global `Mock` table.
-- Runs on Fengari (Lua 5.3); WoW uses Lua 5.1, so stick to the common subset.

Mock = {
    clock = 1763300000,            -- seconds, drives time()
    money = 0,                     -- copper, drives GetMoney()
    hour = 14, month = 7, weekday = 4,
    mapID = 1447, zone = "Azshara",
    skill = { rank = 300, max = 300, mod = 25 },
    pole = 6256, lure = true, lureMs = 600000,
    loot = nil,                    -- { fishing = bool, items = { {id, qty}, ... } }
    secretLinks = false,
    timers = {},
    frames = {},
    printed = {},
    popups = {},
    events = {},
}

-- Items: name, quality, vendor sell price (copper), bind (1 = soulbound), classID, subClassID
-- Vendor prices here are test values, not real game data.
Mock.items = {
    [6256]  = { "Fishing Pole", 1, 5, 0, 2, 20 },
    [6522]  = { "Deviate Fish", 1, 1, 0, 7, 8 },
    [6358]  = { "Oily Blackmouth", 1, 4, 0, 7, 8 },
    [6359]  = { "Firefin Snapper", 1, 4, 0, 7, 8 },
    [6362]  = { "Raw Rockscale Cod", 1, 4, 0, 7, 8 },
    [4603]  = { "Raw Spotted Yellowtail", 1, 4, 0, 7, 8 },
    [13422] = { "Stonescale Eel", 1, 10, 0, 7, 8 },
    [13893] = { "Large Raw Mightfish", 1, 6, 0, 7, 8 },
    [13756] = { "Raw Summer Bass", 1, 6, 0, 7, 8 },
    [13755] = { "Winter Squid", 1, 6, 0, 7, 8 },
    [13757] = { "Lightning Eel", 1, 8, 0, 7, 8 },
    [13759] = { "Raw Nightfin Snapper", 1, 6, 0, 7, 8 },
    [13760] = { "Raw Sunscale Salmon", 1, 6, 0, 7, 8 },
    [13758] = { "Raw Redgill", 1, 4, 0, 7, 8 },
    [13889] = { "Raw Whitescale Salmon", 1, 6, 0, 7, 8 },
    [13888] = { "Darkclaw Lobster", 1, 6, 0, 7, 8 },
    [7973]  = { "Big-mouth Clam", 1, 25, 0, 15, 0 },
    [13926] = { "Golden Pearl", 2, 1500, 0, 7, 0 },
    [21153] = { "Raw Greater Sagefish", 1, 4, 0, 7, 8 },
    [8365]  = { "Raw Mithril Head Trout", 1, 4, 0, 7, 8 },
    [6289]  = { "Raw Longjaw Mud Snapper", 1, 1, 0, 7, 8 },
    [21071] = { "Raw Sagefish", 1, 1, 0, 7, 8 },
    [6308]  = { "Raw Bristle Whisker Catfish", 1, 2, 0, 7, 8 },
    [6361]  = { "Raw Rainbow Fin Albacore", 1, 1, 0, 7, 8 },
    [13754] = { "Raw Glossy Mightfish", 1, 4, 0, 7, 8 },
    [90001] = { "Riverglades Pike (test item)", 1, 300, 0, 7, 8 },
    [90002] = { "Soulbound Trinket (test item)", 3, 500, 1, 4, 0 },
    [6307]  = { "Message in a Bottle", 1, 0, 0, 15, 0 },
    [6352]  = { "Waterlogged Crate", 1, 0, 0, 15, 0 },
    [6291]  = { "Raw Brilliant Smallfish", 1, 1, 0, 7, 8 },
    [6303]  = { "Raw Slitherskin Mackerel", 1, 1, 0, 7, 8 },
    [6317]  = { "Raw Loch Frenzy", 1, 1, 0, 7, 8 },
}

Mock.maps = {
    [1447] = { name = "Azshara", mapType = 3, parentMapID = 1414 },
    [1444] = { name = "Feralas", mapType = 3, parentMapID = 1414 },
    [1452] = { name = "Winterspring", mapType = 3, parentMapID = 1414 },
    [99001] = { name = "Riverglades", mapType = 3, parentMapID = 1414 },
    [99002] = { name = "Riverglades Shallows", mapType = 5, parentMapID = 99001 }, -- micro map
}

----------------------------------------------------------------------
-- Lua 5.1 / WoW global helpers
----------------------------------------------------------------------
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
unpack = unpack or table.unpack
date = os.date
time = function() return Mock.clock end
tinsert, tremove = table.insert, table.remove
strlower, strupper, strfind, strsub = string.lower, string.upper, string.find, string.sub
strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
BreakUpLargeNumbers = function(n) return tostring(n) end
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    Mock.printed[#Mock.printed + 1] = table.concat(parts, " ")
end
YES, NO = "Yes", "No"
INVSLOT_MAINHAND = 16
LOOT_SLOT_ITEM = 1
Enum = {
    LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 },
    UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
    ItemWeaponSubclass = { Fishingpole = 20 },
}
ITEM_QUALITY_COLORS = {
    [0] = { r = .6, g = .6, b = .6 }, [1] = { r = 1, g = 1, b = 1 }, [2] = { r = .1, g = 1, b = 0 },
    [3] = { r = 0, g = .44, b = .87 }, [4] = { r = .64, g = .21, b = .93 },
}
issecretvalue = function(v) return Mock.secretLinks and type(v) == "string" and v:find("|Hitem:") ~= nil end

----------------------------------------------------------------------
-- Frames: any CamelCase method exists and does nothing unless defined.
----------------------------------------------------------------------
local Widget = {}
local function noop() end

local function NewWidget(kind, name, parent)
    local w = { __kind = kind, __scripts = {}, __shown = true, __text = "", __events = {}, __parent = parent, __name = name }
    if kind == "Frame" or kind == "Button" or kind == "CheckButton" or kind == "EditBox" then
        Mock.frames[#Mock.frames + 1] = w
    end
    return setmetatable(w, Widget)
end

Widget.__index = function(t, k)
    local m = rawget(Widget, k)
    if m then return m end
    if type(k) == "string" and k:match("^[A-Z]") then return noop end
    return nil
end

function Widget:SetScript(name, fn) self.__scripts[name] = fn end
function Widget:GetScript(name) return self.__scripts[name] end
function Widget:HookScript(name, fn)
    local old = self.__scripts[name]
    self.__scripts[name] = function(...) if old then old(...) end fn(...) end
end
function Widget:RegisterEvent(e) self.__events[e] = true end
function Widget:UnregisterEvent(e) self.__events[e] = nil end
function Widget:Show() self.__shown = true end
function Widget:Hide() self.__shown = false end
function Widget:SetShown(v) self.__shown = v and true or false end
function Widget:IsShown()
    if not self.__shown then return false end
    if self.__parent and self.__parent.IsShown then return self.__parent:IsShown() end
    return true
end
function Widget:IsVisible() return self:IsShown() end
function Widget:SetText(t) self.__text = t == nil and "" or tostring(t) end
function Widget:GetText() return self.__text end
function Widget:SetChecked(v) self.__checked = v and true or false end
function Widget:GetChecked() return self.__checked end
function Widget:HasFocus() return false end
function Widget:GetWidth() return 140 end
function Widget:GetHeight() return 140 end
function Widget:GetCenter() return 100, 100 end
function Widget:GetEffectiveScale() return 1 end
function Widget:GetPoint() return "CENTER", nil, "CENTER", 10, 20 end
function Widget:GetName() return self.__name end
function Widget:GetStringHeight() return 12 end
function Widget:CreateTexture() return NewWidget("Texture", nil, self) end
function Widget:CreateFontString() return NewWidget("FontString", nil, self) end
function Widget:SetTexture(t) self.__texture = t end

function CreateFrame(kind, name, parent)
    local f = NewWidget(kind, name, parent)
    if name then _G[name] = f end
    return f
end

UIParent = NewWidget("Frame", "UIParent")
Minimap = NewWidget("Frame", "Minimap", UIParent)
GameTooltip = NewWidget("Frame", "GameTooltip", UIParent)
GameTooltip.lines = {}
function GameTooltip:SetOwner() wipe(self.lines) end
function GameTooltip:SetText(t) self.lines[#self.lines + 1] = tostring(t) end
function GameTooltip:AddLine(t) self.lines[#self.lines + 1] = tostring(t) end
function GameTooltip:AddDoubleLine(a, b) self.lines[#self.lines + 1] = tostring(a) .. " | " .. tostring(b) end
function GameTooltip:SetItemByID(id) self.lines[#self.lines + 1] = "item:" .. id end
GameTooltip_Hide = function() GameTooltip:Hide() end

-- Blizzard Options window (Settings API, Dragonflight and later)
Mock.settings = { categories = {}, addonCategories = {}, opened = nil }
SettingsPanel = NewWidget("Frame", "SettingsPanel", UIParent)
SettingsPanel.__shown = false
HideUIPanel = function(f) f:Hide() end
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        local cat = { frame = frame, name = name, id = #Mock.settings.categories + 1 }
        function cat:GetID() return self.id end
        Mock.settings.categories[#Mock.settings.categories + 1] = cat
        return cat
    end,
    RegisterAddOnCategory = function(cat) Mock.settings.addonCategories[#Mock.settings.addonCategories + 1] = cat end,
    OpenToCategory = function(id)
        Mock.settings.opened = id
        SettingsPanel:Show()
        local cat = Mock.settings.categories[id]
        if cat and cat.frame.__scripts.OnShow then cat.frame.__scripts.OnShow(cat.frame) end
    end,
}

UISpecialFrames = {}
StaticPopupDialogs = {}
StaticPopup_Show = function(which) Mock.popups[#Mock.popups + 1] = which end
SlashCmdList = {}

C_Timer = {
    After = function(_, fn) Mock.timers[#Mock.timers + 1] = fn end,
    NewTicker = function() return { Cancel = noop } end,
}
function Mock.FlushTimers()
    while #Mock.timers > 0 do
        local list = Mock.timers
        Mock.timers = {}
        for _, fn in ipairs(list) do fn() end
    end
end

----------------------------------------------------------------------
-- Game state APIs
----------------------------------------------------------------------
local function ItemLink(id)
    local it = Mock.items[id]
    return ("|cffffffff|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(id, it and it[1] or "?")
end

local function ParseID(item)
    if type(item) == "number" then return item end
    if type(item) == "string" then return tonumber(item:match("item:(%d+)")) end
end

C_Item = {
    GetItemInfo = function(item)
        local id = ParseID(item)
        local it = id and Mock.items[id]
        if not it then return nil end
        -- name, link, quality, ilvl, reqLvl, type, subType, stack, equipLoc, texture, sellPrice, classID, subClassID, bindType
        return it[1], ItemLink(id), it[2], 1, 1, "Trade Goods", "Meat", 20, "", "icon:" .. id, it[3], it[5], it[6], it[4]
    end,
    GetItemInfoInstant = function(item)
        local id = ParseID(item)
        local it = id and Mock.items[id]
        if not it then return id end
        return id, "Trade Goods", "Meat", "", "icon:" .. id, it[5], it[6]
    end,
    GetItemIconByID = function(id) return Mock.items[id] and ("icon:" .. id) or nil end,
    RequestLoadItemDataByID = noop,
    GetItemQualityColor = function(q) local c = ITEM_QUALITY_COLORS[q] or ITEM_QUALITY_COLORS[1]; return c.r, c.g, c.b end,
}

C_Map = {
    GetBestMapForUnit = function() return Mock.mapID end,
    GetMapInfo = function(id)
        local m = Mock.maps[id]
        if not m then return nil end
        return { mapID = id, name = m.name, mapType = m.mapType, parentMapID = m.parentMapID }
    end,
}
GetRealZoneText = function() return Mock.zone end

C_Spell = { GetSpellName = function(id) return id == 7620 and "Fishing" or nil end }
C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "@project-version@" or nil end }
C_DateAndTime = {
    GetCurrentCalendarTime = function() return { month = Mock.month, weekday = Mock.weekday, monthDay = 1, year = 2026 } end,
}
GetGameTime = function() return Mock.hour, 0 end
GetBuildInfo = function() return "1.60.1", "70500", "Nov 4 2026", Mock.interface or 16001 end
GetMoney = function() return Mock.money end
GetCursorInfo = function() return nil end
ClearCursor = noop
GetCursorPosition = function() return 150, 150 end

GetProfessions = function()
    if not Mock.skill then return nil end
    return nil, nil, nil, 4, nil
end
GetProfessionInfo = function(idx)
    if idx ~= 4 or not Mock.skill then return nil end
    return "Fishing", 136245, Mock.skill.rank, Mock.skill.max, 0, 0, 356, Mock.skill.mod
end

GetInventoryItemID = function(_, slot) if slot == 16 then return Mock.pole end end

-- Bags / equipment / faction for the gear checklist.
Mock.bags = {}          -- [itemID] = count (bags + bank)
Mock.equipped = {}      -- [itemID] = true (besides the pole in Mock.pole)
Mock.faction = "Alliance"
Mock.glovesEnchant = nil
C_Item.GetItemCount = function(id) return Mock.bags[id] or 0 end
C_Item.IsEquippedItem = function(id) return id == Mock.pole or Mock.equipped[id] == true end
UnitFactionGroup = function() return Mock.faction, Mock.faction end
GetInventoryItemLink = function(_, slot)
    if slot == 10 then return ("|cffffffff|Hitem:9999:%s::::::::60:::::|h[Gloves]|h|r"):format(Mock.glovesEnchant or "") end
    if slot == 16 and Mock.pole then return ("|cffffffff|Hitem:%d::::::::60:::::|h[Pole]|h|r"):format(Mock.pole) end
end
for id, it in pairs({
    [6365] = { "Strong Fishing Pole", 1, 1, 0, 2, 20 }, [12225] = { "Blump Family Fishing Pole", 2, 1, 1, 2, 20 },
    [6367] = { "Big Iron Fishing Pole", 1, 10, 0, 2, 20 }, [19022] = { "Nat Pagle's Extreme Angler FC-5000", 3, 10, 1, 2, 20 },
    [19970] = { "Arcanite Fishing Pole", 4, 10, 1, 2, 20 },
    [6529] = { "Shiny Bauble", 1, 25, 0, 0, 0 }, [6530] = { "Nightcrawlers", 1, 5, 0, 0, 0 },
    [6811] = { "Aquadynamic Fish Lens", 1, 50, 0, 0, 0 }, [6532] = { "Bright Baubles", 1, 100, 0, 0, 0 },
    [7307] = { "Flesh Eating Worm", 1, 10, 0, 0, 0 }, [6533] = { "Aquadynamic Fish Attractor", 1, 100, 0, 0, 0 },
    [19972] = { "Lucky Fishing Hat", 3, 1, 1, 4, 1 }, [19969] = { "Nat Pagle's Extreme Anglin' Boots", 3, 1, 1, 4, 1 },
    [19971] = { "High Test Eternium Fishing Line", 3, 1, 1, 0, 0 },
    [279967] = { "Fish Bowl", 1, 0, 0, 0, 0 }, [279965] = { "Fishing Rack", 2, 0, 0, 0, 0 }, [279966] = { "Fishing Hut", 3, 0, 0, 0, 0 },
}) do Mock.items[id] = Mock.items[id] or it end
GetWeaponEnchantInfo = function() return Mock.lure, Mock.lure and Mock.lureMs or 0 end

IsFishingLoot = function() return Mock.loot ~= nil and Mock.loot.fishing == true end
GetNumLootItems = function() return Mock.loot and #Mock.loot.items or 0 end
GetLootSlotType = function(slot) return (Mock.loot and Mock.loot.items[slot]) and 1 or 0 end
GetLootSlotLink = function(slot) local s = Mock.loot.items[slot]; return s and ItemLink(s[1]) end
GetLootSlotInfo = function(slot)
    local s = Mock.loot.items[slot]
    if not s then return nil end
    local it = Mock.items[s[1]]
    return "icon:" .. s[1], it and it[1], s[2], nil, it and it[2] or 1
end

----------------------------------------------------------------------
-- Event helpers used by the scenarios
----------------------------------------------------------------------
function Mock.Fire(event, ...)
    for _, f in ipairs(Mock.frames) do
        if f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
    Mock.FlushTimers()
end

-- Simulates one complete fishing catch with autoloot (READY + OPENED + CLOSED).
function Mock.Catch(items, coins, fishing)
    Mock.loot = { fishing = fishing ~= false, items = items or {} }
    Mock.Fire("LOOT_READY", true)
    Mock.Fire("LOOT_OPENED", true)
    Mock.money = Mock.money + (coins or 0)
    Mock.Fire("LOOT_CLOSED")
    Mock.loot = nil
end

function Mock.Advance(seconds) Mock.clock = Mock.clock + seconds end
