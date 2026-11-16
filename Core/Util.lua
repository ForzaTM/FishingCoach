-- Fishing Coach: shared helpers.
local _, ns = ...

ns.Util = {}
local U = ns.Util

function U.CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = U.CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- Formats copper as "12g 34s 56c" with coin icons. `short` drops copper above 1g.
function U.Money(copper, short)
    copper = math.floor((copper or 0) + 0.5)
    local neg = copper < 0
    if neg then copper = -copper end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = BreakUpLargeNumbers and BreakUpLargeNumbers(g) .. GOLD or g .. GOLD end
    if s > 0 or (g > 0 and not short) then parts[#parts + 1] = s .. SILVER end
    if not (short and g > 0) and (c > 0 or #parts == 0) then parts[#parts + 1] = c .. COPPER end
    return (neg and "-" or "") .. table.concat(parts, " ")
end

function U.Duration(sec)
    sec = math.floor(sec or 0)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return s .. "s"
end

function U.Icon(tex, size)
    return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", tostring(tex), size or 14, size or 14)
end

function U.QualityColor(quality)
    if quality and C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

function U.Print(msg)
    print("|cff33ccffFishing|r |cffffd100Coach|r: " .. tostring(msg))
end

-- Coalesces many refresh requests into one per frame burst.
function U.Debounce(delay, fn)
    local pending = false
    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, function()
            pending = false
            fn()
        end)
    end
end
