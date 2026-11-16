-- ReelGold: API compatibility layer.
-- WoW: Forever runs on the modern (12.x) client API, but every call is wrapped
-- here so a single file needs touching when Blizzard renames something.
local _, ns = ...

local C = {}
ns.C = C

local C_Item, C_Map, C_Spell = C_Item, C_Map, C_Spell

-- "Secret values" (Midnight-era restriction, also active in Forever) cannot be
-- inspected by addons. Never compare or index them.
function C.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

function C.GetItemInfo(id)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
    return GetItemInfo(id)
end

function C.GetItemInfoInstant(item)
    if C_Item and C_Item.GetItemInfoInstant then return C_Item.GetItemInfoInstant(item) end
    return GetItemInfoInstant(item)
end

function C.GetItemIcon(id)
    local icon
    if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(id) end
    if not icon and GetItemIcon then icon = GetItemIcon(id) end
    if not icon then icon = select(5, C.GetItemInfoInstant(id)) end
    return icon or ns.Icons.question
end

function C.RequestItem(id)
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(id)
    end
end

function C.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    if GetSpellInfo then return (GetSpellInfo(spellID)) end
end

function C.GetPlayerMap()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil, GetRealZoneText() end
    local mapID = C_Map.GetBestMapForUnit("player")
    if C.IsSecret(mapID) then mapID = nil end
    -- Walk up to the zone level map (sub-zones/micro maps -> zone).
    local info = mapID and C_Map.GetMapInfo(mapID)
    local MICRO = Enum and Enum.UIMapType and Enum.UIMapType.Micro or 5
    while info and info.mapType == MICRO and info.parentMapID and info.parentMapID > 0 do
        mapID = info.parentMapID
        info = C_Map.GetMapInfo(mapID)
    end
    return mapID, (info and info.name) or GetRealZoneText()
end

function C.GetMapName(mapID)
    if mapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name then return info.name end
    end
end

-- Returns rank, maxRank, modifier (modifier = pole/lure/gear bonuses).
function C.GetFishingSkill()
    if GetProfessions and GetProfessionInfo then
        local _, _, _, fishing = GetProfessions()
        if fishing then
            local _, _, rank, maxRank, _, _, _, mod = GetProfessionInfo(fishing)
            return rank or 0, maxRank or 0, mod or 0
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        local fishName = C.GetSpellName(7620) or "Fishing"
        for i = 1, GetNumSkillLines() do
            local name, _, _, rank, _, mod, maxRank = GetSkillLineInfo(i)
            if name == fishName then return rank or 0, maxRank or 0, mod or 0 end
        end
    end
    return nil
end

local SLOT_ITEM = (Enum and Enum.LootSlotType and Enum.LootSlotType.Item) or LOOT_SLOT_ITEM or 1
C.LOOT_SLOT_ITEM = SLOT_ITEM

function C.IsFishingLoot()
    return IsFishingLoot ~= nil and IsFishingLoot() == true
end

-- Mainhand fishing pole + lure state (read only).
function C.GetPoleState()
    local itemID = GetInventoryItemID("player", INVSLOT_MAINHAND or 16)
    local hasPole = false
    if itemID then
        local _, _, _, _, _, classID, subClassID = C.GetItemInfoInstant(itemID)
        local poleSub = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole) or 20
        hasPole = (classID == 2 and subClassID == poleSub)
    end
    local hasLure, expiresMs = false, 0
    if hasPole and GetWeaponEnchantInfo then
        local mh, exp = GetWeaponEnchantInfo()
        hasLure, expiresMs = mh == true, exp or 0
    end
    return hasPole, hasLure, expiresMs
end

-- How many of an item you carry (bags) and whether it is equipped.
function C.GetItemCount(id)
    local n
    if C_Item and C_Item.GetItemCount then n = C_Item.GetItemCount(id, true)
    elseif GetItemCount then n = GetItemCount(id, true) end
    if C.IsSecret(n) then return 0 end
    return n or 0
end

function C.IsEquipped(id)
    local f = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
    return f ~= nil and f(id) == true
end

function C.Owns(id)
    return C.GetItemCount(id) > 0 or C.IsEquipped(id)
end

function C.Faction()
    return UnitFactionGroup and UnitFactionGroup("player") or nil
end

-- Enchant ID on the equipped gloves (slot 10), or nil.
function C.GlovesEnchant()
    local link = GetInventoryItemLink and GetInventoryItemLink("player", INVSLOT_HAND or 10)
    if not link or C.IsSecret(link) then return nil end
    return tonumber(link:match("item:%d+:(%d+)"))
end

function C.GetGameHour()
    local h = GetGameTime and GetGameTime()
    return h or tonumber(date("%H"))
end

function C.GetMonth()
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local t = C_DateAndTime.GetCurrentCalendarTime()
        if t and t.month then return t.month, t.weekday end
    end
    local t = date("*t")
    return t.month, t.wday
end
