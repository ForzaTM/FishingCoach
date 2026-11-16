-- ReelGold: fishing session tracker.
-- Listens to fishing loot only (IsFishingLoot) and measures ACTIVE fishing
-- time: the gap between two catches counts only while it is shorter than the
-- idle timeout, so AFK breaks and travel do not ruin your gold/hour.
local _, ns = ...

local Tracker = {}
ns.Tracker = Tracker

local FIRST_CATCH_SECONDS = 15 -- typical cast-to-loot cycle for the first catch

Tracker.UNITS = { "minute", "hour", "custom" }

function Tracker.NewSession()
    return { started = time(), active = 0, last = nil, catches = 0, items = {}, money = 0 }
end

function Tracker.Session()
    return ns.char.session
end

function Tracker.Reset()
    ns.char.session = Tracker.NewSession()
    ns:FireRefresh()
end

local function ZoneStats(mapID, zoneName)
    local key = mapID or ("name:" .. (zoneName or "?"))
    local z = ns.db.zoneStats[key]
    if not z then
        z = { seconds = 0, catches = 0, items = {} }
        ns.db.zoneStats[key] = z
    end
    z.mapID = mapID
    z.name = zoneName or z.name
    return z
end

-- items = { {id=, count=}, ... }
function Tracker.RecordCatch(items)
    local s = Tracker.Session()
    local now = time()
    local add
    if s.last and (now - s.last) <= ns.db.idleTimeout then
        add = now - s.last
    else
        add = FIRST_CATCH_SECONDS
    end
    s.active = s.active + add
    s.last = now
    s.catches = s.catches + 1

    local mapID, zoneName = ns.C.GetPlayerMap()
    local z = ZoneStats(mapID, zoneName)
    z.seconds = z.seconds + add
    z.catches = z.catches + 1

    for _, it in ipairs(items) do
        s.items[it.id] = (s.items[it.id] or 0) + it.count
        z.items[it.id] = (z.items[it.id] or 0) + it.count
    end
    ns:FireRefresh()
end

function Tracker.AddMoney(copper)
    if copper and copper > 0 then
        local s = Tracker.Session()
        s.money = s.money + copper
        ns:FireRefresh()
    end
end

-- Active seconds including the running gap since the last catch.
function Tracker.ActiveSeconds()
    local s = Tracker.Session()
    local extra = 0
    if s.last then
        local gap = time() - s.last
        if gap <= ns.db.idleTimeout then extra = gap end
    end
    return s.active + extra
end

function Tracker.IsIdle()
    local s = Tracker.Session()
    return not s.last or (time() - s.last) > ns.db.idleTimeout
end

function Tracker.ItemsValue(items)
    local total = 0
    for id, count in pairs(items) do
        total = total + ns.Pricing.Get(id) * count
    end
    return total
end

function Tracker.TotalValue()
    local s = Tracker.Session()
    return Tracker.ItemsValue(s.items) + (s.money or 0)
end

function Tracker.UnitSeconds()
    local u = ns.db.timeUnit
    if u == "minute" then return 60 end
    if u == "custom" then return math.max(1, ns.db.customMinutes) * 60 end
    return 3600
end

function Tracker.UnitLabel()
    local u = ns.db.timeUnit
    if u == "minute" then return "per minute" end
    if u == "custom" then return ("per %d min"):format(ns.db.customMinutes) end
    return "per hour"
end

-- Copper earned per selected time unit.
function Tracker.Rate()
    local secs = Tracker.ActiveSeconds()
    if secs < 1 then return 0 end
    return Tracker.TotalValue() / secs * Tracker.UnitSeconds()
end

-- Sorted list of { id, count, unit, market, total, source }
--   market = price each as shown on the AH (or vendor/manual)
--   unit   = counted value each (after the AH cut when enabled); total = unit * count
function Tracker.SortedItems(items)
    local list = {}
    for id, count in pairs(items) do
        local d = ns.Pricing.GetDetail(id)
        list[#list + 1] = { id = id, count = count, unit = d.value, market = d.market,
                            total = d.value * count, source = d.source }
    end
    table.sort(list, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.id < b.id
    end)
    return list
end

----------------------------------------------------------------------
-- Loot events
----------------------------------------------------------------------
local handled, moneyBefore = false, nil

function Tracker.OnLootReady()
    if handled or not ns.C.IsFishingLoot() then return end
    handled = true
    moneyBefore = GetMoney()

    local items = {}
    for slot = 1, (GetNumLootItems() or 0) do
        local slotType = GetLootSlotType(slot)
        if not ns.C.IsSecret(slotType) and slotType == ns.C.LOOT_SLOT_ITEM then
            local link = GetLootSlotLink(slot)
            local _, _, qty = GetLootSlotInfo(slot)
            if link and not ns.C.IsSecret(link) and not ns.C.IsSecret(qty) then
                local id = ns.C.GetItemInfoInstant(link)
                if id then items[#items + 1] = { id = id, count = qty or 1 } end
            end
        end
    end
    Tracker.RecordCatch(items)
end

function Tracker.OnLootClosed()
    if handled and moneyBefore then
        Tracker.AddMoney(GetMoney() - moneyBefore)
    end
    handled, moneyBefore = false, nil
end
