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

-- Returns copper value per unit and a label of where it came from.
function Pricing.Get(id)
    if not id then return 0, "?" end
    local override = ns.db.priceOverrides[id]
    if override then return override, "Manual" end

    local vendor = Pricing.GetVendor(id)
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
            if ns.db.applyAHCut then ah = math.floor(ah * AH_CUT) end
            if ah >= vendor then return ah, label end
        end
    end
    return vendor, "Vendor"
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

function Pricing.StatusText()
    local parts = {}
    parts[#parts + 1] = (Pricing.HasAuctionator() and "|cff33ff33" or "|cff888888") .. "Auctionator|r"
    parts[#parts + 1] = (Pricing.HasTSM() and "|cff33ff33" or "|cff888888") .. "TSM|r"
    return "Detected: " .. table.concat(parts, "  ")
end
