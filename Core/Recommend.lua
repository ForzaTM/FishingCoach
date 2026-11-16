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

-- Cheapest common way to cover a skill gap (Forever lure/pole values).
local BOOSTS = {
    { 25,  "a Shiny Bauble (+25)" },
    { 50,  "Nightcrawlers or an Aquadynamic Fish Lens (+50)" },
    { 75,  "Bright Baubles or a Flesh Eating Worm (+75)" },
    { 100, "an Aquadynamic Fish Attractor (+100)" },
}
function R.BoostFor(gap)
    for _, b in ipairs(BOOSTS) do
        if gap <= b[1] then return b[2] end
    end
end

-- Best spots for the player's current effective skill.
-- Returns { skill, rank, mod, maxRank, best = { up to `count` fishable spots },
--           nextGoal = spot worth unlocking or nil, gap = skill points missing }
function R.ForSkill(count)
    count = count or 3
    local rank, maxRank, mod = ns.C.GetFishingSkill()
    local result = { rank = rank, maxRank = maxRank, mod = mod or 0, best = {} }
    if not rank then return result end
    local list, skill = R.Rank()
    result.skill = skill

    local bestValue = 0
    for _, e in ipairs(list) do
        if e.canFish and #result.best < count then
            result.best[#result.best + 1] = e
            bestValue = math.max(bestValue, e.perHour)
        end
    end
    -- Next goal: a locked spot that pays more than your best one; closest unlock first.
    for _, e in ipairs(list) do
        if not e.canFish and e.minSkill and e.perHour > bestValue then
            local n = result.nextGoal
            if not n or e.minSkill < n.minSkill or (e.minSkill == n.minSkill and e.perHour > n.perHour) then
                result.nextGoal = e
            end
        end
    end
    if result.nextGoal then
        result.gap = result.nextGoal.minSkill - skill
        result.gain = result.nextGoal.perHour - bestValue
    end
    return result
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

----------------------------------------------------------------------
-- Gear advice: what is missing to fish efficiently, and where to get it
-- (shown on the Tips tab). Reads bags, bank and equipped items only.
----------------------------------------------------------------------
local function GearName(e)
    return (e.id and ns.C.GetItemInfo(e.id)) or e.name
end

local function FactionOK(e, faction)
    return not e.faction or not faction or e.faction == faction
end

function R.GearAdvice()
    local out = {}
    local function add(e, text) out[#out + 1] = { itemID = e.id, icon = e.icon, text = text, gear = true } end
    local G = ns.Gear
    local rank = ns.C.GetFishingSkill()
    if not rank then
        out[1] = { icon = ns.Icons.fishing, text = "|cffff5555Missing: the Fishing skill.|r Learn it from any fishing trainer in a capital or starting area.", gear = true }
        return out
    end
    local skill, faction = rank, ns.C.Faction()

    -- Pole: best one you own vs. the best you could use now / later.
    local owned = -1
    for _, p in ipairs(G.poles) do
        if ns.C.Owns(p.id) and p.bonus > owned then owned = p.bonus end
    end
    local nextPole, topPole
    for _, p in ipairs(G.poles) do
        if p.bonus > owned and FactionOK(p, faction) then
            if p.minSkill <= skill and (not nextPole or p.bonus > nextPole.bonus) then nextPole = p end
            if not topPole or p.bonus > topPole.bonus then topPole = p end
        end
    end
    if owned < 0 then
        local p = nextPole or G.poles[1]
        add(p, ("|cffff5555Missing: a fishing pole.|r Best for you now: %s (+%d): %s."):format(GearName(p), p.bonus, p.source))
    elseif nextPole then
        add(nextPole, ("|cffff5555Better pole:|r %s (+%d, yours +%d): %s."):format(GearName(nextPole), nextPole.bonus, owned, nextPole.source))
    end
    if topPole and topPole ~= nextPole and topPole.minSkill > skill then
        add(topPole, ("|cffffaa00Later, at skill %d:|r %s (+%d): %s."):format(topPole.minSkill, GearName(topPole), topPole.bonus, topPole.source))
    end

    -- Lures in your bags vs. the strongest you can use.
    local bestOwnedLure, bestUsable, cheap = nil, nil, nil
    for _, l in ipairs(G.lures) do
        if ns.C.GetItemCount(l.id) > 0 and (not bestOwnedLure or l.bonus > bestOwnedLure) then bestOwnedLure = l.bonus end
        if l.minSkill <= skill then
            if not bestUsable or l.bonus > bestUsable.bonus then bestUsable = l end
            if l.source:find("vendors") and (not cheap or l.bonus > cheap.bonus) then cheap = l end
        end
    end
    if bestUsable and not bestOwnedLure then
        local txt = ("|cffff5555Missing: lures.|r Strongest for you: %s (+%d): %s."):format(GearName(bestUsable), bestUsable.bonus, bestUsable.source)
        if cheap and cheap ~= bestUsable then
            txt = txt .. (" Cheaper: %s (+%d): %s."):format(GearName(cheap), cheap.bonus, cheap.source)
        end
        add(bestUsable, txt)
    elseif bestUsable and bestUsable.bonus > bestOwnedLure then
        add(bestUsable, ("|cffffaa00Stronger lure:|r %s (+%d, your best +%d): %s."):format(GearName(bestUsable), bestUsable.bonus, bestOwnedLure, bestUsable.source))
    end

    -- Forever camping utilities.
    for _, c in ipairs(G.camping) do
        if not ns.C.Owns(c.id) then
            if skill >= c.minSkill then
                add(c, ("|cffff5555Missing: %s.|r %s. %s"):format(GearName(c), c.source, c.note))
            else
                add(c, ("|cffffaa00At skill %d: %s.|r %s. %s"):format(c.minSkill, GearName(c), c.source, c.note))
            end
        end
    end

    -- Hat, boots, fishing line.
    for _, g in ipairs(G.gear) do
        if not ns.C.Owns(g.id) then
            add(g, ("|cffff5555Missing: %s (+%d).|r %s.%s"):format(GearName(g), g.bonus, g.source, g.note and (" " .. g.note) or ""))
        end
    end

    -- Fishing enchant on gloves.
    local ge = G.glovesEnchant
    if ns.C.GlovesEnchant() ~= ge.enchantID then
        add(ge, ("|cffff5555Missing: %s (+%d) on your gloves.|r %s."):format(ge.name, ge.bonus, ge.source))
    end

    if #out == 0 then
        out[1] = { icon = ns.Icons.pole, text = "|cff33ff33You have all the fishing gear ReelGold knows about.|r", gear = true }
    end
    return out
end
