-- ReelGold offline scenarios. Loaded by tests/run.js after wowmock.lua.
-- Each test runs against the real addon files listed in ReelGold.toc.

local passed, failed, failures = 0, 0, {}
local current

local function check(cond, msg)
    if not cond then error(msg or "check failed", 2) end
end
local function eq(a, b, msg)
    if a ~= b then error(("%s: expected %s, got %s"):format(msg or "value", tostring(b), tostring(a)), 2) end
end
local function near(a, b, tol, msg)
    if math.abs(a - b) > (tol or 1e-6) then error(("%s: expected ~%s, got %s"):format(msg or "value", tostring(b), tostring(a)), 2) end
end
local function test(name, fn)
    current = name
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        passed = passed + 1
        REPORT("  PASS  " .. name)
    else
        failed = failed + 1
        failures[#failures + 1] = name
        REPORT("  FAIL  " .. name .. "\n" .. tostring(err))
    end
end

----------------------------------------------------------------------
-- Load the addon exactly as the client would (TOC order, shared ns).
----------------------------------------------------------------------
local ns = {}
for _, path in ipairs(TOC_FILES) do
    local chunk, err = loadfile(path)
    if not chunk then error("Cannot load " .. path .. ": " .. tostring(err)) end
    chunk("ReelGold", ns)
end
Mock.Fire("ADDON_LOADED", "ReelGold")
Mock.Fire("PLAYER_LOGIN")

local T, P, R, U = ns.Tracker, ns.Pricing, ns.Recommend, ns.Util

-- One typical Azshara catch sequence, repeated (approximately the seed shares).
local AZSHARA = {
    { {13422, 1} }, { {13893, 1} }, { {13422, 2} }, { {13756, 1} }, { {13757, 1} },
    { {13422, 1} }, { {13893, 1} }, { {7973, 1} }, { {13422, 1} }, { {13756, 1} },
}
local function FishFor(n, every, pattern, coinsEvery)
    for i = 1, n do
        Mock.Advance(every)
        local coins = (coinsEvery and i % coinsEvery == 0) and 35 or 0
        Mock.Catch(pattern[(i - 1) % #pattern + 1], coins)
    end
end

REPORT("ReelGold offline tests (mock WoW API, " .. _VERSION .. ")\n")

test("addon loads, saved variables get defaults, slash command registered", function()
    check(ReelGoldDB and ReelGoldCharDB, "saved variables created")
    eq(ReelGoldDB.timeUnit, "hour", "default time unit")
    eq(ReelGoldDB.idleTimeout, 300, "default idle timeout")
    eq(ReelGoldDB.priceSource, "auto", "default price source")
    check(type(SlashCmdList.REELGOLD) == "function", "slash handler")
    eq(SLASH_REELGOLD1, "/reelgold")
    eq(ns.version, "dev", "unpackaged version shows as dev")
end)

test("money formatting", function()
    local plain = function(c) return (U.Money(c):gsub("|T[^|]+|t", "")) end
    eq(plain(0), "0", "zero")
    eq(plain(57), "57", "copper only")
    eq(plain(1234), "12 34", "silver and copper")
    eq(plain(409312), "40 93 12", "gold silver copper")
    eq((U.Money(409312, true):gsub("|T[^|]+|t", "")), "40 93", "short form drops copper")
    eq(U.Duration(3725), "1h 02m", "duration hours")
    eq(U.Duration(75), "1m 15s", "duration minutes")
end)

test("vendor pricing when no auction addon is installed", function()
    eq(P.Get(13422), 10, "Stonescale vendor price")
    local _, src = P.Get(13422)
    eq(src, "Vendor")
end)

test("fishing catches are counted once per loot window (READY + OPENED dedupe)", function()
    T.Reset()
    Mock.Catch({ {13422, 1} })
    local s = T.Session()
    eq(s.catches, 1, "one catch")
    eq(s.items[13422], 1, "one eel")
end)

test("non-fishing loot (mobs, chests) is ignored", function()
    T.Reset()
    Mock.Catch({ {13422, 5} }, 0, false)
    eq(T.Session().catches, 0, "no catch recorded")
    eq(T.Session().items[13422], nil, "no items recorded")
end)

test("active time: 20 catches every 15 s = 300 s", function()
    T.Reset()
    FishFor(20, 15, AZSHARA)
    -- first catch counts a 15 s estimate, the next 19 add 15 s each
    eq(T.Session().active, 300, "active seconds")
    eq(T.Session().catches, 20, "catches")
end)

test("idle breaks do not count (AFK 20 min, then fish again)", function()
    T.Reset()
    FishFor(10, 15, AZSHARA)
    local before = T.Session().active
    Mock.Advance(20 * 60)
    check(T.IsIdle(), "session is idle during the break")
    eq(T.ActiveSeconds(), before, "running time frozen while idle")
    Mock.Catch({ {13422, 1} })
    eq(T.Session().active, before + 15, "only a 15 s estimate added after the break")
end)

test("coins from fishing loot are added to the session", function()
    T.Reset()
    FishFor(10, 15, AZSHARA, 5)
    eq(T.Session().money, 70, "two catches with 35 copper each")
end)

test("rate per minute / hour / custom minutes are consistent", function()
    T.Reset()
    FishFor(40, 15, AZSHARA)
    ReelGoldDB.timeUnit = "hour";   local h = T.Rate()
    ReelGoldDB.timeUnit = "minute"; local m = T.Rate()
    ReelGoldDB.timeUnit = "custom"; ReelGoldDB.customMinutes = 30; local c = T.Rate()
    ReelGoldDB.timeUnit = "hour"
    check(h > 0, "hourly rate positive")
    near(h, m * 60, 1e-6, "hour = 60 x minute")
    near(c, h / 2, 1e-6, "30 min = half an hour")
    near(h, T.TotalValue() / T.ActiveSeconds() * 3600, 1e-6, "hour = value / time")
end)

test("Auctionator price is used when higher than vendor, minus 5% AH cut", function()
    Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id)
        return ({ [13422] = 7000, [13757] = 2 })[id]
    end } } }
    local p, src = P.Get(13422)
    eq(src, "Auctionator"); eq(p, 6650, "7000 minus 5%")
    ReelGoldDB.applyAHCut = false
    eq((P.Get(13422)), 7000, "without AH cut")
    ReelGoldDB.applyAHCut = true
    local lp, lsrc = P.Get(13757)
    eq(lsrc, "Vendor", "AH below vendor falls back to vendor"); eq(lp, 8)
end)

test("TSM is used when Auctionator has no price", function()
    TSM_API = { GetCustomPriceValue = function(src, itemString)
        eq(src, "DBMarket", "TSM source"); return itemString == "i:13893" and 2000 or nil
    end }
    local p, src = P.Get(13893)
    eq(src, "TSM"); eq(p, 1900)
end)

test("soulbound items always use vendor price", function()
    local p, src = P.Get(90002)
    eq(src, "Vendor"); eq(p, 500)
end)

test("manual price overrides every other source", function()
    P.SetOverride(13422, 12345)
    local p, src = P.Get(13422)
    eq(src, "Manual"); eq(p, 12345)
    P.SetOverride(13422, nil)
    eq(select(2, P.Get(13422)), "Auctionator", "override cleared")
end)

test("vendor-only setting ignores auction addons", function()
    ReelGoldDB.priceSource = "vendor"
    eq(select(2, P.Get(13422)), "Vendor")
    ReelGoldDB.priceSource = "auto"
end)

test("spot ranking: seeds ranked by value, own zone data replaces the estimate", function()
    wipe(ReelGoldDB.zoneStats)
    T.Reset()
    Mock.mapID = 1447
    FishFor(39, 15, AZSHARA)
    local function find(list, zone) for _, e in ipairs(list) do if e.zone == zone then return e end end end
    local list = R.Rank()
    eq(find(list, "Azshara").learned, false, "39 catches: still an estimate")
    FishFor(1, 15, AZSHARA)
    list = R.Rank()
    local az = find(list, "Azshara")
    eq(az.learned, true, "40 catches: uses your data")
    eq(az.catches, 40)
    near(az.perHour, T.ItemsValue(ReelGoldDB.zoneStats[1447].items) / ReelGoldDB.zoneStats[1447].seconds * 3600, 1e-6, "per hour from own data")
    for i = 2, #list do
        if list[i - 1].canFish == list[i].canFish then
            check(list[i - 1].perHour >= list[i].perHour, "sorted by gold per hour")
        end
    end
end)

test("new Forever zone (not in seed data) gets ranked from your catches, micro map rolls up", function()
    Mock.mapID = 99002 -- micro map inside "Riverglades"
    FishFor(45, 20, { { {90001, 1} } })
    local found
    for _, e in ipairs(R.Rank()) do if e.zone == "Riverglades" then found = e end end
    check(found, "Riverglades listed")
    eq(found.learned, true)
    eq(ReelGoldDB.zoneStats[99001].catches, 45, "stored under the zone map, not the micro map")
    Mock.mapID = 1447
end)

test("skill filter marks spots you cannot fish yet", function()
    Mock.skill = { rank = 150, max = 150, mod = 0 }
    local list = R.Rank()
    for _, e in ipairs(list) do
        if e.learned then
            check(e.canFish, e.zone .. ": your own catches prove you can fish there")
        elseif e.minSkill and e.minSkill > 150 then
            check(not e.canFish, e.zone .. " should be too hard")
        end
    end
    check(list[1].canFish, "fishable spots first")
    Mock.skill = { rank = 300, max = 300, mod = 25 }
end)

test("day/night and season change which fish the estimate counts", function()
    local function has(zone, id)
        for _, e in ipairs(R.Rank()) do
            if e.zone == zone and not e.learned then
                for _, l in ipairs(e.loot) do if l.id == id then return true end end
            end
        end
        return false
    end
    Mock.hour = 23
    check(has("Winterspring", 13759), "Nightfin at night"); check(not has("Winterspring", 13760), "no Sunscale at night")
    Mock.hour = 12
    check(has("Winterspring", 13760), "Sunscale at day"); check(not has("Winterspring", 13759), "no Nightfin at day")
    Mock.month = 1
    check(has("Feralas", 13755), "Winter Squid in January"); check(not has("Feralas", 13756), "no Summer Bass in January")
    Mock.month = 7
    check(has("Feralas", 13756), "Summer Bass in July")
end)

test("context tips react to lure, skill cap and Sunday Extravaganza", function()
    local function anyTip(pat)
        for _, t in ipairs(R.ContextTips()) do if t.text:find(pat) then return true end end
        return false
    end
    Mock.lure = false
    check(anyTip("No lure"), "no-lure warning")
    Mock.lure = true
    check(not anyTip("No lure"), "no warning with lure")
    Mock.pole = nil
    check(anyTip("No fishing pole"), "no-pole warning")
    Mock.pole = 6256
    Mock.skill = { rank = 150, max = 150, mod = 0 }
    check(anyTip("train Expert"), "skill cap tip")
    Mock.skill = { rank = 300, max = 300, mod = 25 }
    Mock.weekday, Mock.hour = 1, 15
    check(anyTip("running now"), "Extravaganza running")
    Mock.weekday, Mock.hour = 4, 14
end)

test("secret values from the client are skipped without errors", function()
    T.Reset()
    Mock.secretLinks = true
    Mock.Catch({ {13422, 1} })
    Mock.secretLinks = false
    eq(T.Session().catches, 1, "catch still counted")
    eq(T.Session().items[13422], nil, "secret item not read")
end)

test("newer client interface prints a one-time notice", function()
    Mock.interface = 16002
    wipe(Mock.printed)
    Mock.Fire("PLAYER_LOGIN")
    Mock.Fire("PLAYER_LOGIN")
    local n = 0
    for _, line in ipairs(Mock.printed) do if line:find("16002") then n = n + 1 end end
    eq(n, 1, "notice printed once")
    Mock.interface = nil
end)

test("Auctionator scans update prices and every view automatically", function()
    -- Fake Auctionator with the same API as Auctionator 347 (RegisterForDBUpdate etc.).
    local ahdb, callbacks = { [13422] = 1000, [13757] = 2 }, {}
    Auctionator = { API = { v1 = {
        GetAuctionPriceByItemID = function(_, id) return ahdb[id] end,
        GetAuctionAgeByItemID = function(_, id) return ahdb[id] and 0 or nil end,
        RegisterForDBUpdate = function(caller, cb)
            eq(caller, "ReelGold", "caller ID"); callbacks[#callbacks + 1] = cb
        end,
    } } }
    Mock.Fire("ADDON_LOADED", "Auctionator")
    Mock.Fire("ADDON_LOADED", "Auctionator")
    eq(#callbacks, 1, "hooked exactly once")
    check(P.IsHooked(), "hook reported")

    ns.UI.Toggle("spots")
    local origRefresh, redraws = ns.UI.Refresh, 0
    ns.UI.Refresh = function(...) redraws = redraws + 1; return origRefresh(...) end
    eq((P.Get(13422)), 950, "old AH price (1000 - 5%)")

    -- A scan finds a new price: ReelGold picks it up and redraws without any click.
    ahdb[13422] = 9000
    wipe(Mock.printed)
    callbacks[1](); Mock.FlushTimers()
    eq((P.Get(13422)), 8550, "new AH price used")
    eq(P.lastReason, "scan")
    check(redraws >= 1, "window redrawn after the scan")
    local msgs = 0
    for _, l in ipairs(Mock.printed) do if l:find("Prices updated from Auctionator") then msgs = msgs + 1 end end
    eq(msgs, 1, "one chat message")
    callbacks[1](); callbacks[1](); Mock.FlushTimers()
    msgs = 0
    for _, l in ipairs(Mock.printed) do if l:find("Prices updated") then msgs = msgs + 1 end end
    eq(msgs, 1, "no message spam for repeated scan callbacks in one AH visit")
    check(ReelGoldMainFrame.priceStatus:GetText():find("^Auctionator %d+/%d+"), "status: " .. ReelGoldMainFrame.priceStatus:GetText())

    -- Fallback: closing the Auction House refreshes too (TSM users).
    Mock.Fire("AUCTION_HOUSE_CLOSED")
    eq(P.lastReason, "ah")
    wipe(Mock.printed)
    callbacks[1](); Mock.FlushTimers()
    check(Mock.printed[1] and Mock.printed[1]:find("Prices updated from Auctionator"), "next AH visit announces again")

    -- Manual button in the title bar and /rgold prices.
    local btn
    for _, f in ipairs(Mock.frames) do
        if f.__parent == ReelGoldMainFrame and f.__text == "Refresh prices" then btn = f end
    end
    check(btn, "Refresh prices button exists")
    wipe(Mock.printed)
    btn.__scripts.OnClick(btn, "LeftButton"); Mock.FlushTimers()
    eq(P.lastReason, "manual")
    check(Mock.printed[1] and Mock.printed[1]:find("of %d+ fish have Auction House prices"), "coverage message: " .. tostring(Mock.printed[1]))
    SlashCmdList.REELGOLD("prices")
    eq(P.lastReason, "manual")
    Mock.Advance(125)
    check(ReelGoldMainFrame.priceStatus:GetText() and P.ShortStatus():find("2m ago"), "age shown: " .. P.ShortStatus())

    ns.UI.Refresh = origRefresh
    ahdb[13422] = 7000 -- back to the value the later tests expect
end)

test("catch log shows the AH price exactly as Auctionator has it (real case from Wetlands)", function()
    -- Real data from the owner's game: Auctionator 'last seen minimum' prices (copper per unit).
    local prev = Auctionator
    local ahdb = { [6358] = 194, [6359] = 24, [6361] = 4 }
    Auctionator = { API = { v1 = {
        GetAuctionPriceByItemID = function(_, id) return ahdb[id] end,
        GetAuctionAgeByItemID = function(_, id) return ahdb[id] and 0 or nil end,
    } } }
    T.Reset()
    Mock.mapID = 1437
    -- The owner's real session: Albacore x4, Blackmouth x1, Message in a Bottle, Waterlogged Crate.
    for _, catch in ipairs({ { {6361, 1} }, { {6361, 1} }, { {6307, 1} }, { {6361, 1} }, { {6358, 1} }, { {6352, 1} }, { {6361, 1} } }) do
        Mock.Advance(25); Mock.Catch(catch)
    end
    local d = P.GetDetail(6358)
    eq(d.market, 194, "market = Auctionator price, untouched")
    eq(d.value, 184, "counted value = 194 minus 5% (rounded down)")
    eq(d.cut, 10, "cut amount")
    eq(d.source, "Auctionator")

    ns.UI.Toggle("session"); ns.UI.Refresh()
    local plain = function(s) return (s:gsub("|T[^|]+|t", "")) end
    local rows = {}
    for _, f in ipairs(Mock.frames) do
        if f.count and f.name and f:IsShown() then rows[f.name.__text] = plain(f.count.__text) .. " = " .. plain(f.total.__text) end
    end
    REPORT("    Catch log rows: " .. table.concat((function() local t = {} for k, v in pairs(rows) do t[#t + 1] = k .. ": " .. v end table.sort(t) return t end)(), " | "))
    check(rows["Oily Blackmouth"] and rows["Oily Blackmouth"]:find("^x1  @ 1 94 |cff33ff33AH|r = 1 84$"), "Blackmouth row: " .. tostring(rows["Oily Blackmouth"]))
    check(rows["Raw Rainbow Fin Albacore"] and rows["Raw Rainbow Fin Albacore"]:find("^x4  @ 4 |cff33ff33AH|r = 12$"), "Albacore row: " .. tostring(rows["Raw Rainbow Fin Albacore"]))
    check(rows["Message in a Bottle"] and rows["Message in a Bottle"]:find("vendor"), "no AH data -> vendor")

    -- With the AH cut off, totals equal the AH price exactly.
    ReelGoldDB.applyAHCut = false
    eq((P.Get(6358)), 194, "no cut: counted = AH price")
    ReelGoldDB.applyAHCut = true

    -- After a new scan the log uses the new price at once.
    ahdb[6358] = 250
    ns.UI.Refresh()
    for _, f in ipairs(Mock.frames) do
        if f.count and f.name and f.name.__text == "Oily Blackmouth" then
            check(plain(f.count.__text):find("@ 2 50"), "updated price: " .. plain(f.count.__text))
        end
    end
    Auctionator = prev
    Mock.mapID = 1447
end)

local function inMainWindow(f)
    local p = f.__parent
    while p do if p == ReelGoldMainFrame then return true end p = p.__parent end
    return false
end

test("AH cut toggle lives on the Settings tab and updates the values on screen", function()
    T.Reset()
    Mock.mapID = 1447
    FishFor(4, 15, { { {13422, 1} } }) -- 4 Stonescale Eels, AH price 7000c each (fake Auctionator)
    ReelGoldDB.applyAHCut = true
    ns.UI.Toggle("session"); ns.UI.Refresh()
    for _, f in ipairs(Mock.frames) do
        check(not (f.label and f.label.__text == "Count 5% AH cut"), "no AH cut toggle on the Session tab any more")
    end
    local function eelRow()
        ns.UI.Toggle("session"); ns.UI.Refresh()
        for _, f in ipairs(Mock.frames) do
            if f.count and f.name and f:IsShown() and f.name.__text == "Stonescale Eel" then
                return (f.count.__text:gsub("|T[^|]+|t", "")), (f.total.__text:gsub("|T[^|]+|t", ""))
            end
        end
    end
    local each, total = eelRow()
    check(each:find("@ 70 |", 1, true), "price each = AH price: " .. each)
    eq(total, "2 66", "total after cut: 4 x 66s50c = 2g 66s")
    local rateOn = T.Rate()

    ns.UI.Toggle("settings"); ns.UI.Refresh()
    local cb
    for _, f in ipairs(Mock.frames) do
        if f.__kind == "CheckButton" and f.label and f.label.__text == "Subtract 5% Auction House cut"
            and inMainWindow(f) and f:IsShown() then cb = f end
    end
    check(cb, "toggle is on the Settings tab")
    cb:SetChecked(false); cb.__scripts.OnClick(cb, "LeftButton"); Mock.FlushTimers()
    eq(ReelGoldDB.applyAHCut, false, "setting switched off")
    each, total = eelRow()
    check(each:find("@ 70 |", 1, true), "price each unchanged: " .. each)
    eq(total, "2 80", "total at full AH price: 4 x 70s = 2g 80s")
    near(T.Rate(), rateOn / 0.95, rateOn * 0.001, "gold per hour rises by the cut")
    ReelGoldDB.applyAHCut = true
    eq(select(2, eelRow()), "2 66", "total after cut again")
end)

test("update notice banner: WoW patched, ReelGold updated, dismiss, copyable link", function()
    ns.UI.Toggle("session"); ns.UI.Refresh()
    local banner = ReelGoldMainFrame.banner
    check(not banner:IsShown(), "no banner normally")

    -- WoW: Forever patched to a newer interface than ReelGold was made for.
    Mock.interface = 16002
    ns.UI.Refresh()
    check(banner:IsShown(), "banner shown after a WoW patch")
    check(banner.text.__text:find("interface 16002") and banner.text.__text:find("CurseForge"), banner.text.__text)
    banner.close.__scripts.OnClick(banner.close, "LeftButton"); Mock.FlushTimers()
    check(not banner:IsShown(), "dismissed")
    ns.UI.Refresh()
    check(not banner:IsShown(), "stays dismissed for this WoW version")
    Mock.interface = 16003
    ns.UI.Refresh()
    check(banner:IsShown(), "comes back for the next WoW patch")
    banner.close.__scripts.OnClick(banner.close, "LeftButton")
    Mock.interface = nil

    -- ReelGold itself updated between logins.
    local savedVersion = ns.version
    ns.version = "1.0.1"; Mock.Fire("PLAYER_LOGIN")
    ns.UI.Refresh()
    check(not banner:IsShown(), "first seen version: no notice")
    ns.version = "1.0.2"; Mock.Fire("PLAYER_LOGIN")
    ns.UI.Refresh()
    check(banner:IsShown() and banner.text.__text:find("v1.0.1 %-> v1.0.2"), "updated notice: " .. tostring(banner.text.__text))
    banner.close.__scripts.OnClick(banner.close, "LeftButton"); Mock.FlushTimers()
    ns.UI.Refresh()
    check(not banner:IsShown(), "updated notice dismissed")
    ns.version = savedVersion

    -- Settings shows the update link in a read-only box.
    ns.UI.Toggle("settings"); ns.UI.Refresh()
    local box
    for _, f in ipairs(Mock.frames) do
        if f.__kind == "EditBox" and f.__text == ns.GameVersion.UPDATE_URL then box = f end
    end
    check(box, "update link box on Settings")
    box:SetText("typed over it"); box.__scripts.OnTextChanged(box)
    eq(box:GetText(), ns.GameVersion.UPDATE_URL, "link cannot be edited")
end)

test("HUD has a close button that hides it until shown again", function()
    ReelGoldDB.hud.shown, ReelGoldDB.hud.onlyWithPole = true, true
    Mock.pole = 6256
    ns.HUD.UpdateVisibility()
    local hud = ns.HUD.GetFrame()
    check(hud and hud:IsShown(), "HUD visible with a pole")
    local close
    for _, f in ipairs(Mock.frames) do
        if f.__parent == hud and f.__kind == "Button" then close = f end
    end
    check(close and close.__scripts.OnClick, "close button exists on the HUD")
    close.__scripts.OnClick(close, "LeftButton")
    check(not hud:IsShown(), "HUD hidden after clicking X")
    eq(ReelGoldDB.hud.shown, false, "stays hidden (saved)")
    Mock.Fire("PLAYER_EQUIPMENT_CHANGED")
    check(not hud:IsShown(), "re-equipping the pole does not bring it back")
    SlashCmdList.REELGOLD("hud")
    check(hud:IsShown(), "/rgold hud shows it again")
end)

test("'For me' tab: best fishable spots and the next spot worth unlocking", function()
    local savedStats = ReelGoldDB.zoneStats
    ReelGoldDB.zoneStats = {}
    Mock.skill = { rank = 290, max = 300, mod = 0 }
    P.SetOverride(13422, 50000) -- make Stonescale Eel (Feralas 300 / Azshara 330) the best money
    local r = R.ForSkill(3)
    eq(r.skill, 290, "effective skill")
    eq(#r.best, 3, "three fishable spots")
    for i, e in ipairs(r.best) do
        check(e.canFish, e.zone .. " must be fishable")
        if i > 1 then check(r.best[i - 1].perHour >= e.perHour, "sorted by gold per hour") end
    end
    check(r.nextGoal, "a next goal exists")
    eq(r.nextGoal.zone, "Feralas", "closest better-paying unlock")
    eq(r.gap, 10, "10 skill missing")
    check(r.gain > 0, "unlock pays more")
    check(R.BoostFor(r.gap):find("Shiny Bauble"), "a +25 lure covers 10 points")
    eq(R.BoostFor(150), nil, "too big for a lure")

    Mock.skill = { rank = 330, max = 375, mod = 25 }
    r = R.ForSkill(3)
    eq(r.nextGoal, nil, "nothing left to unlock at 355")

    Mock.skill = { rank = 10, max = 75, mod = 0 }
    r = R.ForSkill(3)
    eq(#r.best, 0, "beginner: no money spot yet")
    eq(r.nextGoal and r.nextGoal.minSkill, 75, "first unlock at 75")
    ns.UI.Toggle("best"); ns.UI.Refresh()

    Mock.skill = nil
    eq(R.ForSkill(3).rank, nil, "fishing not learned")
    ns.UI.Refresh()

    Mock.skill = { rank = 300, max = 300, mod = 25 }
    P.SetOverride(13422, nil)
    ReelGoldDB.zoneStats = savedStats
end)

test("ReelGold has a page in Options -> AddOns", function()
    eq(#Mock.settings.addonCategories, 1, "registered exactly once (PLAYER_LOGIN fired several times)")
    local cat = Mock.settings.addonCategories[1]
    eq(cat.name, "ReelGold", "category name")
    SlashCmdList.REELGOLD("options")
    eq(Mock.settings.opened, cat:GetID(), "/rgold options opens the page")
    check(SettingsPanel:IsShown(), "Options window shown")
    -- Every control on the page works and changes the shared settings.
    local panel = cat.frame
    local before = ReelGoldDB.priceSource
    for _, f in ipairs(Mock.frames) do
        local p = f.__parent
        while p and p ~= panel do p = p.__parent end
        if p == panel and f.__scripts.OnClick and f.__kind == "Button" and f.__text:find("^Price source") then
            f.__scripts.OnClick(f, "LeftButton")
        end
    end
    check(ReelGoldDB.priceSource ~= before, "price source button cycles the shared setting")
    ReelGoldDB.priceSource = before
    -- "Open ReelGold" closes Options and opens the main window.
    for _, f in ipairs(Mock.frames) do
        if f.__parent == panel and f.__text == "Open ReelGold" then f.__scripts.OnClick(f, "LeftButton") end
    end
    check(not SettingsPanel:IsShown(), "Options window closed")
    check(ReelGoldMainFrame and ReelGoldMainFrame:IsShown(), "main window opened")
end)

test("UI smoke test: every tab, button, tooltip and slash command runs", function()
    T.Reset()
    FishFor(30, 15, AZSHARA, 7)
    for _, cmd in ipairs({ "", "spots", "tips", "settings", "session", "hud", "hud", "version", "minimap", "minimap", "help" }) do
        SlashCmdList.REELGOLD(cmd)
        Mock.FlushTimers()
    end
    check(ReelGoldMainFrame and ReelGoldMainFrame:IsShown(), "main window open")
    for _, tab in ipairs({ "session", "spots", "tips", "settings" }) do
        ns.UI.Toggle(tab); ns.UI.Refresh()
    end
    local fired = 0
    for _, f in ipairs(Mock.frames) do
        for _, s in ipairs({ "OnShow", "OnEnter", "OnLeave", "OnClick", "OnMouseWheel", "OnEnterPressed", "OnDragStart", "OnDragStop", "OnMouseUp" }) do
            local fn = f.__scripts[s]
            if fn then fn(f, s == "OnMouseWheel" and -1 or (s == "OnMouseUp" and "RightButton" or "LeftButton")); fired = fired + 1 end
        end
        if f.__scripts.OnUpdate then f.__scripts.OnUpdate(f, 1.5); fired = fired + 1 end
    end
    Mock.FlushTimers()
    ns.UI.Toggle("session"); ns.UI.Refresh(); ns.HUD.Refresh()
    ReelGold_OnAddonCompartmentEnter(nil, UIParent)
    ReelGold_OnAddonCompartmentClick(nil, "LeftButton")
    check(fired > 50, "fired " .. fired .. " UI scripts")
end)

----------------------------------------------------------------------
-- Example session report (what the Session tab would show)
----------------------------------------------------------------------
do
    local function plain(c, short)
        return (U.Money(c, short):gsub("|TInterface\\MoneyFrame\\UI%-(%a)%a+Icon[^|]*|t", function(x) return x:lower() end))
    end
    ReelGoldDB.priceSource = "auto"
    T.Reset()
    Mock.mapID, Mock.hour = 1447, 14
    FishFor(120, 15, AZSHARA, 6)
    REPORT("\nExample: 120 catches in Azshara, one every 15 s (mock prices)")
    REPORT(("  Active time  %s   Catches %d   Coins %s"):format(U.Duration(T.ActiveSeconds()), T.Session().catches, plain(T.Session().money)))
    for _, unit in ipairs({ "minute", "hour", "custom" }) do
        ReelGoldDB.timeUnit = unit
        REPORT(("  %-12s %s"):format(T.UnitLabel(), plain(T.Rate(), true)))
    end
    ReelGoldDB.timeUnit = "hour"
    local fm = R.ForSkill(3)
    REPORT(("  'For me' tab at effective skill %d:"):format(fm.skill))
    for i, e in ipairs(fm.best) do
        REPORT(("    %d. %-20s %s/h"):format(i, e.zone, plain(e.perHour, true)))
    end
    if fm.nextGoal then
        REPORT(("    Next goal: %d skill (%d more) unlocks %s, +%s/h; quickest: %s"):format(
            fm.nextGoal.minSkill, fm.gap, fm.nextGoal.zone, plain(fm.gain, true), R.BoostFor(fm.gap) or "keep fishing"))
    end
    REPORT("  Top spots right now (effective skill 325):")
    for i, e in ipairs(R.Rank()) do
        if i > 6 then break end
        REPORT(("    %d. %-20s %-12s %s"):format(i, e.zone, plain(e.perHour, true) .. "/h", e.learned and "(your data)" or "(estimate)"))
    end
end

REPORT(("\n%d passed, %d failed"):format(passed, failed))
TEST_FAILED = failed
