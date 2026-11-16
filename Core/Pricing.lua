-- ReelGold: item pricing.
-- Order: manual override > Auctionator / TSM (if installed) > vendor price.
-- Only public price APIs of those addons are read; nothing touches the AH.
local ADDON, ns = ...

local Pricing = {}
ns.Pricing = Pricing

local AH_CUT = 0.95 -- Auction House keeps 5%

Pricing.SOURCES = { "auto", "auctionator", "tsm", "vendor" }
Pricing.SOURCE_LABELS = {
    auto = "Auto (Auctionator > TSM > vendor)",
    auctionator = "Auctionator",
    tsm = "TradeSkillMaster",
    vendor = "Vendor only",
}

function Pricing.HasAuctionator()
    return Auctionator and Auctionator.API and Auctionator.API.v1
        and Auctionator.API.v1.GetAuctionPriceByItemID ~= nil
end

function Pricing.HasTSM()
    return TSM_API and TSM_API.GetCustomPriceValue ~= nil
end

local function FromAuctionator(id)
    if not Pricing.HasAuctionator() then return end
    local ok, p = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON, id)
    if ok and type(p) == "number" and p > 0 then return p end
end

local function FromTSM(id)
    if not Pricing.HasTSM() then return end
    local ok, p = pcall(TSM_API.GetCustomPriceValue, ns.db.tsmSource or "DBMarket", "i:" .. id)
    if ok and type(p) == "number" and p > 0 then return p end
end

function Pricing.GetVendor(id)
    local _, _, _, _, _, _, _, _, _, _, sell = ns.C.GetItemInfo(id)
    return sell or 0
end

local function IsSoulbound(id)
    local bind = select(14, ns.C.GetItemInfo(id))
    return bind == 1 -- LE_ITEM_BIND_ON_ACQUIRE
end

-- Full price picture for one item (all copper, per unit):
--   market = the price as you see it (AH price exactly as Auctionator/TSM
--            report it, or the vendor / manual price)
--   value  = what ReelGold counts: market minus the 5% AH cut when enabled
--   cut    = copper removed by the AH cut (0 if none)
--   source = "Auctionator", "TSM", "Vendor" or "Manual"
--   vendor = vendor sell price, ah = raw AH price or nil
function Pricing.GetDetail(id)
    local d = { vendor = 0, cut = 0 }
    if not id then d.market, d.value, d.source = 0, 0, "?"; return d end
    d.vendor = Pricing.GetVendor(id)
    local override = ns.db.priceOverrides[id]
    if override then
        d.market, d.value, d.source = override, override, "Manual"
        return d
    end
    local src = ns.db.priceSource
    if src ~= "vendor" and not IsSoulbound(id) then
        local ah, label
        if src == "auto" or src == "auctionator" then
            ah = FromAuctionator(id); label = "Auctionator"
        end
        if not ah and (src == "auto" or src == "tsm") then
            ah = FromTSM(id); label = "TSM"
        end
        if ah then
            d.ah = ah
            local net = ns.db.applyAHCut and math.floor(ah * AH_CUT) or ah
            if net >= d.vendor then
                d.market, d.value, d.source, d.cut = ah, net, label, ah - net
                return d
            end
        end
    end
    d.market, d.value, d.source = d.vendor, d.vendor, "Vendor"
    return d
end

-- Returns the counted copper value per unit and where it came from.
function Pricing.Get(id)
    local d = Pricing.GetDetail(id)
    return d.value, d.source
end

function Pricing.SetOverride(id, copper)
    if not id then return end
    if copper and copper > 0 then
        ns.db.priceOverrides[id] = math.floor(copper)
    else
        ns.db.priceOverrides[id] = nil
    end
    ns:FireRefresh()
end

-- Days since Auctionator last saw the item on the AH (nil = never / >21 days).
function Pricing.GetAuctionAge(id)
    if not (Pricing.HasAuctionator() and Auctionator.API.v1.GetAuctionAgeByItemID) then return nil end
    local ok, age = pcall(Auctionator.API.v1.GetAuctionAgeByItemID, ADDON, id)
    if ok and type(age) == "number" then return age end
end

----------------------------------------------------------------------
-- Price updates: Auctionator scans, AH closing, manual button
----------------------------------------------------------------------
Pricing.lastUpdate = nil      -- time() of the last price refresh
Pricing.lastReason = nil      -- "scan", "ah", "manual" or "login"
local hookedAuctionator = false
-- Auctionator calls back after full scans AND after normal AH searches, so the
-- chat message is shown at most once per Auction House visit.
local announcedThisVisit = false

-- How many known fish currently have an auction price: n, total.
function Pricing.Coverage()
    local n, total = 0, 0
    for id in pairs(ns.Fish) do
        total = total + 1
        local src = select(2, Pricing.Get(id))
        if src == "Auctionator" or src == "TSM" then n = n + 1 end
    end
    return n, total
end

-- Re-reads all prices and redraws every ReelGold view.
-- reason: "scan" (Auctionator finished processing), "ah" (AH closed),
-- "manual" (button / slash), "login".
function Pricing.Refresh(reason)
    Pricing.lastUpdate = time()
    Pricing.lastReason = reason or "manual"
    ns:FireRefresh()
    if reason == "ah" then announcedThisVisit = false end
    if reason == "manual" or (reason == "scan" and not announcedThisVisit) then
        if reason == "scan" then announcedThisVisit = true end
        local n, total = Pricing.Coverage()
        local src = ns.db.priceSource == "vendor" and "vendor prices only"
            or (n > 0 and ("%d of %d fish have Auction House prices"):format(n, total))
            or "no Auction House prices yet: open the Auction House and run an Auctionator scan"
        ns.Util.Print(("Prices updated%s: %s."):format(reason == "scan" and " from Auctionator" or "", src))
    end
end

-- Hook Auctionator's "database updated" callback (full scans and processed
-- searches). Safe to call repeatedly; only hooks once.
function Pricing.HookSources()
    if hookedAuctionator or not Pricing.HasAuctionator() then return end
    local register = Auctionator.API.v1.RegisterForDBUpdate
    if type(register) ~= "function" then return end
    local ok = pcall(register, ADDON, function() Pricing.Refresh("scan") end)
    hookedAuctionator = ok
end

function Pricing.IsHooked() return hookedAuctionator end

-- Short status for the window title bar, e.g. "Auctionator 18/27 · 2m ago".
function Pricing.ShortStatus()
    local label
    if ns.db.priceSource == "vendor" then
        label = "Vendor prices"
    else
        local n, total = Pricing.Coverage()
        local src = (ns.db.priceSource == "tsm" or (ns.db.priceSource == "auto" and not Pricing.HasAuctionator() and Pricing.HasTSM())) and "TSM"
            or (Pricing.HasAuctionator() and "Auctionator") or (Pricing.HasTSM() and "TSM") or nil
        if not src then
            label = "Vendor prices"
        else
            label = ("%s %d/%d"):format(src, n, total)
        end
    end
    local age = ""
    if Pricing.lastUpdate then
        local s = time() - Pricing.lastUpdate
        local m = math.floor(s / 60)
        age = (s < 60 and "  ·  just now")
            or (m < 60 and ("  ·  %dm ago"):format(m))
            or ("  ·  %dh %dm ago"):format(math.floor(m / 60), m % 60)
    end
    return label .. age
end

function Pricing.StatusText()
    local parts = {}
    parts[#parts + 1] = (Pricing.HasAuctionator() and "|cff33ff33" or "|cff888888") .. "Auctionator|r"
    parts[#parts + 1] = (Pricing.HasTSM() and "|cff33ff33" or "|cff888888") .. "TSM|r"
    return "Detected: " .. table.concat(parts, "  ")
end
