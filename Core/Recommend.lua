-- ReelGold: spot ranking and context tips.
local _, ns = ...

local R = {}
ns.Recommend = R

function R.IsNight()
    local h = ns.C.GetGameHour()
    return h >= 18 or h < 6
end

function R.Season()
    local m = ns.C.GetMonth()
    return (m >= 4 and m <= 9) and "summer" or "winter"
end

local function EntryActive(e)
    if e.time == "night" and not R.IsNight() then return false end
    if e.time == "day" and R.IsNight() then return false end
    if e.season and e.season ~= R.Season() then return false end
    return true
end

-- Builds a ranking entry from seed data (estimate).
local function FromSeed(loc)
    local perCatch = loc.junkCopper or 0
    local loot = {}
    for _, e in ipairs(loc.loot) do
        local id, share = e[1], e[2]
        if EntryActive(e) then
            local price = ns.Pricing.Get(id)
            perCatch = perCatch + share * price
            loot[#loot + 1] = { id = id, share = share, value = share * price }
        end
    end
    table.sort(loot, function(a, b) return a.value > b.value end)
    return {
        key = loc.key, mapID = loc.mapID,
        zone = ns.C.GetMapName(loc.mapID) or loc.zone,
        spot = loc.spot, minSkill = loc.minSkill, tip = loc.tip,
        perHour = perCatch * loc.catchesPerHour,
        catchesPerHour = loc.catchesPerHour,
        loot = loot, learned = false,
    }
end

-- Builds a ranking entry from the player's own zone statistics.
local function FromStats(z, seed)
    local value = ns.Tracker.ItemsValue(z.items)
    local loot = {}
    for _, it in ipairs(ns.Tracker.SortedItems(z.items)) do
        loot[#loot + 1] = { id = it.id, share = it.count / math.max(1, z.catches), value = it.total / math.max(1, z.catches) }
    end
    return {
        key = "stats:" .. tostring(z.mapID or z.name), mapID = z.mapID,
        zone = (z.mapID and ns.C.GetMapName(z.mapID)) or z.name or "?",
        spot = seed and seed.spot or "Your fishing data",
        minSkill = seed and seed.minSkill, tip = seed and seed.tip,
        perHour = z.seconds > 0 and (value / z.seconds * 3600) or 0,
        catchesPerHour = z.seconds > 0 and (z.catches / z.seconds * 3600) or 0,
        catches = z.catches,
        loot = loot, learned = true,
    }
end

-- Returns ranked list. Each entry has .canFish (skill check).
function R.Rank()
    local rank, maxRank, mod = ns.C.GetFishingSkill()
    local skill = rank and (rank + (mod or 0)) or nil

    local seedsByMap, list = {}, {}
    for _, loc in ipairs(ns.Locations) do
        seedsByMap[loc.mapID] = seedsByMap[loc.mapID] or loc
    end

    -- Learned data replaces estimates for the same zone.
    local learnedMaps = {}
    for _, z in pairs(ns.db.zoneStats) do
        if z.catches >= ns.db.minLearnCatches and z.seconds > 0 then
            local seed = z.mapID and seedsByMap[z.mapID]
            list[#list + 1] = FromStats(z, seed)
            if z.mapID then learnedMaps[z.mapID] = true end
        end
    end
    for _, loc in ipairs(ns.Locations) do
        if not learnedMaps[loc.mapID] then
            list[#list + 1] = FromSeed(loc)
        end
    end

    for _, e in ipairs(list) do
        -- Your own catch data proves you can fish there, whatever the estimate says.
        e.canFish = e.learned or (skill == nil) or (e.minSkill == nil) or (skill >= e.minSkill)
    end
    table.sort(list, function(a, b)
        if a.canFish ~= b.canFish then return a.canFish end
        return a.perHour > b.perHour
    end)
    return list, skill, maxRank
end

----------------------------------------------------------------------
-- Context tips (shown first on the Tips tab and in the HUD tooltip)
----------------------------------------------------------------------
function R.ContextTips()
    local tips = {}
    local function add(icon, text) tips[#tips + 1] = { icon = icon, text = text, context = true } end

    local hasPole, hasLure, expMs = ns.C.GetPoleState()
    if not hasPole then
        add(ns.Icons.pole, "No fishing pole equipped.")
    elseif not hasLure then
        add(ns.Icons.lure, "|cffff5555No lure on your pole|r - apply one for a big skill boost.")
    elseif expMs and expMs > 0 and expMs < 60000 then
        add(ns.Icons.lure, "Your lure expires in under a minute.")
    end

    local rank, maxRank, mod = ns.C.GetFishingSkill()
    if rank then
        if maxRank and rank >= maxRank and maxRank < 300 then
            local nxt = maxRank < 75 and "Apprentice" or maxRank < 150 and "Journeyman"
                or maxRank < 225 and "Expert (Old Man Heming, Booty Bay)" or "Artisan (Nat Pagle, Dustwallow Marsh)"
            add(ns.Icons.book, ("Skill capped at %d - train %s."):format(maxRank, nxt))
        end
        local best = R.Rank()[1]
        if best and best.minSkill and rank + (mod or 0) < best.minSkill then
            add(ns.Icons.fishing, ("You need %d effective skill for the top spot (you have %d)."):format(best.minSkill, rank + (mod or 0)))
        end
    end

    if R.IsNight() then
        add(ns.C.GetItemIcon(13759), "It is night: Raw Nightfin Snapper bites now (Winterspring, Felwood, Un'Goro, Western Plaguelands).")
    else
        add(ns.C.GetItemIcon(13760), "It is daytime: Raw Sunscale Salmon bites in high level lakes; Nightfin starts at 18:00.")
    end
    if R.Season() == "summer" then
        add(ns.C.GetItemIcon(13756), "Summer season: Raw Summer Bass in high level coastal waters.")
    else
        add(ns.C.GetItemIcon(13755), "Winter season: Winter Squid in high level coastal waters.")
    end

    local _, weekday = ns.C.GetMonth()
    local h = ns.C.GetGameHour()
    if weekday == 1 then -- Sunday
        if h < 14 then
            add(ns.Icons.clock, "Today is Sunday: Stranglethorn Fishing Extravaganza at 14:00!")
        elseif h < 16 then
            add(ns.Icons.clock, "|cff33ff33The Stranglethorn Fishing Extravaganza is running now!|r")
        end
    end

    if ns.Tracker.IsIdle() and ns.Tracker.Session().catches > 0 then
        add(ns.Icons.clock, "Session paused (no catch within the idle timeout). It resumes on your next catch.")
    end
    return tips
end
