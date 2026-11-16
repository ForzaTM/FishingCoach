-- ReelGold: main window (Session / Spots / Tips / Settings).
local ADDON, ns = ...
local W, U = ns.Widgets, ns.Util

local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 470, 520
local LOOT_ROWS, SPOT_ROWS, TIP_ROWS = 7, 7, 6
local frame, tabs, panels, current = nil, {}, {}, "session"

----------------------------------------------------------------------
-- Session tab
----------------------------------------------------------------------
local function BuildSession(p)
    p.header = W.Text(p, "GameFontNormal")
    p.header:SetPoint("TOPLEFT", 14, -12)
    p.header:SetPoint("RIGHT", -14, 0)

    p.status = W.Text(p, "GameFontHighlightSmall")
    p.status:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -4)
    p.status:SetPoint("RIGHT", -14, 0)

    local rateBox = W.Panel(p, WIDTH - 40, 64)
    rateBox:SetPoint("TOPLEFT", 12, -52)
    p.rateIcon = W.ItemIcon(rateBox, 36)
    p.rateIcon:SetPoint("LEFT", 12, 0)
    p.rateIcon:SetTex(ns.Icons.coin)
    p.rate = W.Text(rateBox, "GameFontNormalLarge")
    p.rate:SetPoint("TOPLEFT", p.rateIcon, "TOPRIGHT", 10, -2)
    p.rateLabel = W.Text(rateBox, "GameFontHighlightSmall")
    p.rateLabel:SetPoint("TOPLEFT", p.rate, "BOTTOMLEFT", 0, -4)

    p.unitBtn = W.Button(rateBox, "Per hour", 96, 22, function()
        local units = ns.Tracker.UNITS
        local idx = 1
        for i, u in ipairs(units) do if u == ns.db.timeUnit then idx = i end end
        ns.db.timeUnit = units[idx % #units + 1]
        UI.Refresh()
    end)
    p.unitBtn:SetPoint("TOPRIGHT", -10, -9)
    p.unitBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Time unit", 1, 1, 1)
        GameTooltip:AddLine("Click to switch between per minute, per hour and a custom number of minutes.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    p.unitBtn:SetScript("OnLeave", GameTooltip_Hide)

    p.customEdit = W.Edit(rateBox, 44, true, function(self, text)
        local n = tonumber(text)
        if n and n >= 1 and n <= 1440 then ns.db.customMinutes = math.floor(n) end
        self:SetText(ns.db.customMinutes)
        UI.Refresh()
    end)
    p.customEdit:SetPoint("TOPRIGHT", p.unitBtn, "BOTTOMRIGHT", -30, -4)
    p.customLabel = W.Text(rateBox, "GameFontHighlightSmall", "min")
    p.customLabel:SetPoint("LEFT", p.customEdit, "RIGHT", 4, 0)

    p.stats = {}
    local labels = { "Active fishing time", "Catches", "Catches per hour", "Coins looted", "Total value" }
    for i, label in ipairs(labels) do
        local l = W.Text(p, "GameFontNormalSmall", label)
        l:SetPoint("TOPLEFT", 16, -124 - (i - 1) * 16)
        local v = W.Text(p, "GameFontHighlightSmall")
        v:SetPoint("TOPRIGHT", -16, -124 - (i - 1) * 16)
        v:SetJustifyH("RIGHT")
        p.stats[i] = v
    end

    local lootTitle = W.Text(p, "GameFontNormal", "Catch log")
    lootTitle:SetPoint("TOPLEFT", 16, -210)

    p.rows = {}
    for i = 1, LOOT_ROWS do
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(WIDTH - 40, 24)
        row:SetPoint("TOPLEFT", 14, -230 - (i - 1) * 25)
        row.icon = W.ItemIcon(row, 22)
        row.icon:SetPoint("LEFT")
        row.name = W.Text(row, "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetWidth(190)
        row.name:SetWordWrap(false)
        row.count = W.Text(row, "GameFontHighlightSmall")
        row.count:SetPoint("LEFT", 225, 0)
        row.total = W.Text(row, "GameFontHighlightSmall")
        row.total:SetPoint("RIGHT", -2, 0)
        row.total:SetJustifyH("RIGHT")
        p.rows[i] = row
    end
    p.empty = W.Text(p, "GameFontDisable", "Start fishing - every catch shows up here.")
    p.empty:SetPoint("TOPLEFT", 18, -236)

    p.pager = W.Pager(p, LOOT_ROWS, function() UI.Refresh() end)
    p.pager:Anchor("TOPRIGHT", p, "TOPRIGHT", -14, -206)

    local reset = W.Button(p, "Reset session", 110, 22, function()
        StaticPopup_Show("REELGOLD_RESET")
    end)
    reset:SetPoint("BOTTOMLEFT", 14, 12)
    local hud = W.Button(p, "Toggle HUD", 100, 22, function() ns.HUD.Toggle() end)
    hud:SetPoint("LEFT", reset, "RIGHT", 8, 0)
end

local function RefreshSession(p)
    local T = ns.Tracker
    local s = T.Session()
    local mapID, zone = ns.C.GetPlayerMap()
    local rank, maxRank, mod = ns.C.GetFishingSkill()
    local skillText = rank and ("Skill %d/%d%s"):format(rank, maxRank, (mod and mod > 0) and (" |cff33ff33+" .. mod .. "|r") or "") or "Fishing not learned"
    p.header:SetText(U.Icon(ns.Icons.map) .. " " .. (zone or "?") .. "   " .. U.Icon(ns.Icons.fishing) .. " " .. skillText)

    local hasPole, hasLure, expMs = ns.C.GetPoleState()
    local status
    if not hasPole then
        status = "|cffff5555No fishing pole equipped|r"
    elseif hasLure then
        status = "|cff33ff33Lure active|r" .. (expMs and expMs > 0 and (" (" .. U.Duration(expMs / 1000) .. ")") or "")
    else
        status = "|cffffaa00No lure on your pole|r"
    end
    if s.catches > 0 and T.IsIdle() then status = status .. "   |cff999999Session paused (idle)|r" end
    p.status:SetText(U.Icon(ns.Icons.lure, 12) .. " " .. status)

    p.rate:SetText(U.Money(T.Rate(), true))
    p.rateLabel:SetText("Gold " .. T.UnitLabel() .. "  |cff999999(active fishing time only)|r")
    local u = ns.db.timeUnit
    p.unitBtn:SetText(u == "minute" and "Per minute" or u == "custom" and "Custom" or "Per hour")
    p.customEdit:SetShown(u == "custom")
    p.customLabel:SetShown(u == "custom")
    if not p.customEdit:HasFocus() then p.customEdit:SetText(ns.db.customMinutes) end

    local active = T.ActiveSeconds()
    p.stats[1]:SetText(U.Duration(active))
    p.stats[2]:SetText(s.catches)
    p.stats[3]:SetText(active > 0 and math.floor(s.catches / active * 3600 + 0.5) or 0)
    p.stats[4]:SetText(U.Money(s.money))
    p.stats[5]:SetText(U.Money(T.TotalValue()))

    local list = T.SortedItems(s.items)
    p.pager:SetTotal(#list)
    p.pager.label:SetText(("%d / %d"):format(p.pager.page, p.pager:Pages()))
    p.pager.prev:SetEnabled(p.pager.page > 1)
    p.pager.next:SetEnabled(p.pager.page < p.pager:Pages())
    local offset = (p.pager.page - 1) * LOOT_ROWS
    for i, row in ipairs(p.rows) do
        local it = list[offset + i]
        if it then
            local name, _, quality = ns.C.GetItemInfo(it.id)
            row.icon:SetItem(it.id)
            row.name:SetText(name or ("item:" .. it.id))
            row.name:SetTextColor(U.QualityColor(quality))
            row.count:SetText("x" .. it.count .. "  |cff999999@ " .. U.Money(it.unit, true) .. "|r")
            row.total:SetText(U.Money(it.total, true))
            row:Show()
            if not name then ns.C.RequestItem(it.id) end
        else
            row:Hide()
        end
    end
    p.empty:SetShown(#list == 0)
end

----------------------------------------------------------------------
-- Spots tab
----------------------------------------------------------------------
local function SpotTooltip(row)
    local e = row.entry
    if not e then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(e.zone, 1, 0.82, 0)
    GameTooltip:AddLine(e.spot, 1, 1, 1, true)
    if e.minSkill then GameTooltip:AddLine("Recommended skill: " .. e.minSkill, 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Estimated per hour", U.Money(e.perHour, true), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Catches per hour", math.floor(e.catchesPerHour + 0.5), 1, 0.82, 0, 1, 1, 1)
    if e.learned then
        GameTooltip:AddLine(("Based on YOUR %d catches here."):format(e.catches or 0), 0.2, 1, 0.2)
    else
        GameTooltip:AddLine("Estimate from seed data with your current prices.", 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Main catches:", 1, 0.82, 0)
    for i = 1, math.min(6, #e.loot) do
        local l = e.loot[i]
        local name = ns.C.GetItemInfo(l.id) or ("item:" .. l.id)
        GameTooltip:AddDoubleLine(U.Icon(ns.C.GetItemIcon(l.id)) .. " " .. name,
            ("%d%%  %s/catch"):format(math.floor(l.share * 100 + 0.5), U.Money(l.value, true)), 1, 1, 1, 0.8, 0.8, 0.8)
    end
    if e.tip then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(e.tip, 0.2, 0.8, 1, true)
    end
    GameTooltip:Show()
end

local function BuildSpots(p)
    p.header = W.Text(p, "GameFontNormal")
    p.header:SetPoint("TOPLEFT", 14, -12)

    p.onlyFishable = W.Check(p, "Only spots I can fish",
        function() return ns.db.onlyFishable end,
        function(v) ns.db.onlyFishable = v; UI.Refresh() end,
        "Hide spots that need more fishing skill than you have (including pole/lure bonus).")
    p.onlyFishable:SetPoint("TOPLEFT", 10, -30)

    p.rows = {}
    for i = 1, SPOT_ROWS do
        local row = CreateFrame("Button", nil, p, "BackdropTemplate")
        row:SetSize(WIDTH - 36, 44)
        row:SetPoint("TOPLEFT", 12, -58 - (i - 1) * 47)
        row:SetBackdrop(W.BACKDROP)
        row:SetBackdropColor(0.1, 0.1, 0.12, 0.7)
        row:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
        row.icon = W.ItemIcon(row, 32)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:EnableMouse(false)
        row.title = W.Text(row, "GameFontNormal")
        row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
        row.value = W.Text(row, "GameFontHighlight")
        row.value:SetPoint("TOPRIGHT", -8, -7)
        row.value:SetJustifyH("RIGHT")
        row.sub = W.Text(row, "GameFontHighlightSmall")
        row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
        row.sub:SetPoint("RIGHT", -8, 0)
        row.sub:SetWordWrap(false)
        row:SetScript("OnEnter", SpotTooltip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        p.rows[i] = row
    end
    p.pager = W.Pager(p, SPOT_ROWS, function() UI.Refresh() end)
    p.pager:Anchor("TOPRIGHT", p, "TOPRIGHT", -14, -32)

    local note = W.Text(p, "GameFontDisableSmall",
        "Values update with your price source. Zones you fish get ranked from your own catches.")
    note:SetPoint("BOTTOMLEFT", 14, 14)
    note:SetPoint("RIGHT", -14, 0)
end

local function RefreshSpots(p)
    local list, skill = ns.Recommend.Rank()
    p.header:SetText(U.Icon(ns.Icons.map) .. " Best fishing spots right now"
        .. (skill and ("   |cff999999(effective skill " .. skill .. ")|r") or ""))
    if ns.db.onlyFishable then
        local f = {}
        for _, e in ipairs(list) do if e.canFish then f[#f + 1] = e end end
        list = f
    end
    p.pager:SetTotal(#list)
    p.pager.label:SetText(("%d / %d"):format(p.pager.page, p.pager:Pages()))
    p.pager.prev:SetEnabled(p.pager.page > 1)
    p.pager.next:SetEnabled(p.pager.page < p.pager:Pages())
    local offset = (p.pager.page - 1) * SPOT_ROWS
    local _, currentZone = ns.C.GetPlayerMap()
    for i, row in ipairs(p.rows) do
        local e = list[offset + i]
        row.entry = e
        if e then
            local top = e.loot[1]
            if top then row.icon:SetItem(top.id) else row.icon:SetTex(ns.Icons.fishing) end
            local here = (e.zone == currentZone) and " |cff33ff33(you are here)|r" or ""
            row.title:SetText(("%d. %s%s"):format(offset + i, e.zone, here))
            row.value:SetText(U.Money(e.perHour, true) .. "|cff999999/h|r")
            local parts = { e.spot }
            if e.minSkill then
                parts[#parts + 1] = (e.canFish and "|cff33ff33" or "|cffff5555") .. "skill " .. e.minSkill .. "|r"
            end
            parts[#parts + 1] = e.learned and "|cff33ff33your data|r" or "|cff999999estimate|r"
            row.sub:SetText(table.concat(parts, "  ·  "))
            row:Show()
        else
            row:Hide()
        end
    end
end

----------------------------------------------------------------------
-- "For me" tab: best spots for your current skill + next unlock
----------------------------------------------------------------------
local BEST_CARDS, CARD_H = 3, 104

local function BuildBest(p)
    p.header = W.Text(p, "GameFontNormal")
    p.header:SetPoint("TOPLEFT", 14, -12)
    p.header:SetPoint("RIGHT", -14, 0)
    p.sub = W.Text(p, "GameFontDisableSmall")
    p.sub:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -3)
    p.sub:SetPoint("RIGHT", -14, 0)

    p.cards = {}
    for i = 1, BEST_CARDS do
        local c = CreateFrame("Button", nil, p, "BackdropTemplate")
        c:SetSize(WIDTH - 36, CARD_H)
        c:SetPoint("TOPLEFT", 12, -48 - (i - 1) * (CARD_H + 4))
        c:SetBackdrop(W.BACKDROP)
        c:SetBackdropColor(0.1, 0.1, 0.12, 0.75)
        c:SetBackdropBorderColor(i == 1 and 1 or 0.35, i == 1 and 0.82 or 0.35, i == 1 and 0 or 0.35, 0.9)
        c.icon = W.ItemIcon(c, 40)
        c.icon:SetPoint("TOPLEFT", 8, -8)
        c.icon:EnableMouse(false)
        c.title = W.Text(c, "GameFontNormalLarge")
        c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, -1)
        c.title:SetPoint("RIGHT", -110, 0)
        c.title:SetWordWrap(false)
        c.value = W.Text(c, "GameFontHighlightLarge")
        c.value:SetPoint("TOPRIGHT", -10, -9)
        c.value:SetJustifyH("RIGHT")
        c.spot = W.Text(c, "GameFontHighlightSmall")
        c.spot:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
        c.spot:SetPoint("RIGHT", -10, 0)
        c.spot:SetWordWrap(false)
        c.loot = {}
        for j = 1, 4 do
            local ic = W.ItemIcon(c, 20)
            ic:SetPoint("TOPLEFT", 56 + (j - 1) * 92, -56)
            ic.pct = W.Text(c, "GameFontHighlightSmall")
            ic.pct:SetPoint("LEFT", ic, "RIGHT", 4, 0)
            c.loot[j] = ic
        end
        c.tip = W.Text(c, "GameFontHighlightSmall")
        c.tip:SetPoint("BOTTOMLEFT", 10, 8)
        c.tip:SetPoint("RIGHT", -10, 0)
        c.tip:SetTextColor(0.2, 0.8, 1)
        c.tip:SetWordWrap(false)
        c:SetScript("OnEnter", SpotTooltip)
        c:SetScript("OnLeave", GameTooltip_Hide)
        p.cards[i] = c
    end

    local goal = W.Panel(p, WIDTH - 36, 66)
    goal:SetPoint("TOPLEFT", 12, -48 - BEST_CARDS * (CARD_H + 4))
    goal:SetBackdropBorderColor(0.2, 0.8, 0.2, 0.8)
    goal.icon = goal:CreateTexture(nil, "ARTWORK")
    goal.icon:SetSize(30, 30)
    goal.icon:SetPoint("LEFT", 10, 0)
    goal.icon:SetTexture(ns.Icons.book)
    goal.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    goal.text = W.Text(goal, "GameFontHighlightSmall")
    goal.text:SetPoint("LEFT", goal.icon, "RIGHT", 10, 0)
    goal.text:SetPoint("RIGHT", -10, 0)
    goal.text:SetJustifyV("MIDDLE")
    goal.text:SetHeight(58)
    p.goal = goal

    p.empty = W.Text(p, "GameFontHighlight")
    p.empty:SetPoint("TOPLEFT", 18, -60)
    p.empty:SetPoint("RIGHT", -18, 0)
end

local function RefreshBest(p)
    local r = ns.Recommend.ForSkill(BEST_CARDS)
    local _, currentZone = ns.C.GetPlayerMap()
    if not r.rank then
        p.header:SetText(U.Icon(ns.Icons.fishing) .. " Best spots for your skill")
        p.sub:SetText("")
        p.empty:SetText("You haven't learned Fishing yet. Visit a fishing trainer in any capital or starting area, then come back here.")
        p.empty:Show()
        for _, c in ipairs(p.cards) do c:Hide() end
        p.goal:Hide()
        return
    end
    p.empty:Hide()
    local bonus = (r.mod and r.mod > 0) and (" |cff33ff33(+" .. r.mod .. " from pole, lure and gear)|r") or ""
    p.header:SetText(U.Icon(ns.Icons.fishing) .. (" Best spots for your skill: |cffffffff%d|r%s"):format(r.skill, bonus))
    p.sub:SetText(("Fishing %d/%d.  Ranked by gold per hour with your prices; hover a card for details."):format(r.rank, r.maxRank or 0))

    for i, c in ipairs(p.cards) do
        local e = r.best[i]
        c.entry = e
        if e then
            if e.loot[1] then c.icon:SetItem(e.loot[1].id) else c.icon:SetTex(ns.Icons.fishing) end
            local here = (e.zone == currentZone) and "  |cff33ff33(you are here)|r" or ""
            c.title:SetText(("%d. %s%s"):format(i, e.zone, here))
            c.value:SetText(U.Money(e.perHour, true) .. "|cff999999/h|r")
            local parts = { e.spot }
            if e.minSkill then parts[#parts + 1] = "skill " .. e.minSkill end
            parts[#parts + 1] = e.learned and "|cff33ff33your data|r" or "|cff999999estimate|r"
            c.spot:SetText(table.concat(parts, "  ·  "))
            for j, ic in ipairs(c.loot) do
                local l = e.loot[j]
                if l then
                    ic:SetItem(l.id)
                    ic.pct:SetText(math.floor(l.share * 100 + 0.5) .. "%")
                    ic:Show(); ic.pct:Show()
                else
                    ic:Hide(); ic.pct:Hide()
                end
            end
            c.tip:SetText(e.tip or "")
            c:Show()
        else
            c:Hide()
        end
    end

    if #r.best == 0 then
        p.empty:SetText("Your skill is below every listed money spot. Level up in any starting-zone lake or river "
            .. "(every catch gives skill), then the first spots open up.")
        p.empty:Show()
    end

    local g = r.nextGoal
    if g then
        local how = ns.Recommend.BoostFor(r.gap)
        local train = (r.maxRank and r.rank >= r.maxRank and r.maxRank < 300) and " Train your next fishing rank first." or ""
        p.goal.text:SetText(("|cff33ff33Next goal:|r reach |cffffffff%d|r effective skill (%d more) to unlock |cffffd100%s|r, about %s per hour (+%s)."
            .. "%s%s"):format(g.minSkill, r.gap, g.zone, U.Money(g.perHour, true), U.Money(r.gain, true),
            how and ("\nQuickest way: " .. how .. ".") or "\nKeep fishing to raise your skill.", train))
    else
        p.goal.text:SetText("|cff33ff33Top of the table:|r no better-paying spot needs more skill than you have. Fish here, and your own catches will refine the ranking.")
    end
    p.goal:Show()
end

----------------------------------------------------------------------
-- Tips tab
----------------------------------------------------------------------
local function BuildTips(p)
    p.header = W.Text(p, "GameFontNormal", U.Icon(ns.Icons.book) .. " Fishing tips")
    p.header:SetPoint("TOPLEFT", 14, -12)
    p.rows = {}
    for i = 1, TIP_ROWS do
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(WIDTH - 40, 58)
        row:SetPoint("TOPLEFT", 14, -40 - (i - 1) * 60)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("TOPLEFT", 0, -2)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.text = W.Text(row, "GameFontHighlightSmall")
        row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
        row.text:SetPoint("RIGHT", 0, 0)
        row.text:SetJustifyV("TOP")
        row.text:SetHeight(56)
        p.rows[i] = row
    end
    p.pager = W.Pager(p, TIP_ROWS, function() UI.Refresh() end)
    p.pager:Anchor("TOPRIGHT", p, "TOPRIGHT", -14, -10)
end

local function RefreshTips(p)
    local list = {}
    for _, t in ipairs(ns.Recommend.ContextTips()) do list[#list + 1] = t end
    for _, t in ipairs(ns.Tips) do list[#list + 1] = t end
    p.pager:SetTotal(#list)
    p.pager.label:SetText(("%d / %d"):format(p.pager.page, p.pager:Pages()))
    p.pager.prev:SetEnabled(p.pager.page > 1)
    p.pager.next:SetEnabled(p.pager.page < p.pager:Pages())
    local offset = (p.pager.page - 1) * TIP_ROWS
    for i, row in ipairs(p.rows) do
        local t = list[offset + i]
        if t then
            row.icon:SetTexture(t.icon or ns.Icons.fishing)
            row.text:SetText((t.context and "|cffffd100Now:|r " or "") .. t.text)
            row:Show()
        else
            row:Hide()
        end
    end
end

----------------------------------------------------------------------
-- Settings tab
----------------------------------------------------------------------
local function BuildSettings(p)
    local y = -12
    local function line(h) local cur = y; y = y - (h or 26); return cur end

    local title = W.Text(p, "GameFontNormal", U.Icon(ns.Icons.coin) .. " Prices")
    title:SetPoint("TOPLEFT", 14, line(22))

    p.srcBtn = W.Button(p, "", 250, 22, function()
        local list = ns.Pricing.SOURCES
        local idx = 1
        for i, s in ipairs(list) do if s == ns.db.priceSource then idx = i end end
        ns.db.priceSource = list[idx % #list + 1]
        ns:FireRefresh()
    end)
    p.srcBtn:SetPoint("TOPLEFT", 16, line(24))
    p.srcStatus = W.Text(p, "GameFontHighlightSmall")
    p.srcStatus:SetPoint("LEFT", p.srcBtn, "RIGHT", 8, 0)

    local tsmL = W.Text(p, "GameFontHighlightSmall", "TSM price source:")
    tsmL:SetPoint("TOPLEFT", 18, line(26) - 4)
    p.tsmEdit = W.Edit(p, 140, false, function(self, text)
        text = strtrim(text or "")
        if text ~= "" then ns.db.tsmSource = text end
        self:SetText(ns.db.tsmSource)
        ns:FireRefresh()
    end)
    p.tsmEdit:SetPoint("LEFT", tsmL, "RIGHT", 10, 0)

    local cut = W.Check(p, "Subtract 5% Auction House cut",
        function() return ns.db.applyAHCut end,
        function(v) ns.db.applyAHCut = v; ns:FireRefresh() end)
    cut:SetPoint("TOPLEFT", 12, line(28))

    -- Manual price override with drag & drop of an item.
    local ovL = W.Text(p, "GameFontNormalSmall", "Manual price (drop an item or type its ID):")
    ovL:SetPoint("TOPLEFT", 18, line(20))
    p.ovIcon = W.ItemIcon(p, 26)
    p.ovIcon:SetPoint("TOPLEFT", 18, line(32))
    p.ovIcon:SetTex(ns.Icons.question)
    local function setOvItem(id)
        p.ovID = id
        p.ovIcon:SetItem(id)
        p.ovIdEdit:SetText(id or "")
        local cur = id and ns.db.priceOverrides[id]
        p.ovGold:SetText(cur and string.format("%.2f", cur / 10000) or "")
    end
    local function onDrop()
        local kind, id = GetCursorInfo()
        if kind == "item" and id then setOvItem(id); ClearCursor() end
    end
    p.ovIcon:SetScript("OnReceiveDrag", onDrop)
    p.ovIcon:SetScript("OnClick", onDrop)
    p.ovIdEdit = W.Edit(p, 70, true, function(_, text)
        local id = tonumber(text)
        if id and id ~= p.ovID then setOvItem(id) end
    end)
    p.ovIdEdit:SetPoint("LEFT", p.ovIcon, "RIGHT", 12, 0)
    p.ovGold = W.Edit(p, 70, false)
    p.ovGold:SetPoint("LEFT", p.ovIdEdit, "RIGHT", 12, 0)
    local gl = W.Text(p, "GameFontHighlightSmall", "gold")
    gl:SetPoint("LEFT", p.ovGold, "RIGHT", 4, 0)
    local set = W.Button(p, "Set", 50, 22, function()
        local txt = (p.ovGold:GetText() or ""):gsub(",", ".")
        local g = tonumber(txt)
        if p.ovID and g then
            ns.Pricing.SetOverride(p.ovID, g * 10000)
            U.Print("Price set.")
        end
    end)
    set:SetPoint("LEFT", gl, "RIGHT", 8, 0)
    local clr = W.Button(p, "Clear", 54, 22, function()
        if p.ovID then ns.Pricing.SetOverride(p.ovID, nil); setOvItem(p.ovID) end
    end)
    clr:SetPoint("LEFT", set, "RIGHT", 4, 0)

    line(8)
    local t2 = W.Text(p, "GameFontNormal", U.Icon(ns.Icons.clock) .. " Tracking")
    t2:SetPoint("TOPLEFT", 14, line(24))

    local idleL = W.Text(p, "GameFontHighlightSmall", "Pause session after no catch for (minutes):")
    idleL:SetPoint("TOPLEFT", 18, line(26) - 4)
    p.idleEdit = W.Edit(p, 40, true, function(self, text)
        local n = tonumber(text)
        if n and n >= 1 and n <= 60 then ns.db.idleTimeout = n * 60 end
        self:SetText(math.floor(ns.db.idleTimeout / 60))
    end)
    p.idleEdit:SetPoint("LEFT", idleL, "RIGHT", 10, 0)

    local learnL = W.Text(p, "GameFontHighlightSmall", "Use my own zone data after this many catches:")
    learnL:SetPoint("TOPLEFT", 18, line(26) - 4)
    p.learnEdit = W.Edit(p, 40, true, function(self, text)
        local n = tonumber(text)
        if n and n >= 5 then ns.db.minLearnCatches = n end
        self:SetText(ns.db.minLearnCatches)
    end)
    p.learnEdit:SetPoint("LEFT", learnL, "RIGHT", 10, 0)

    line(6)
    local t3 = W.Text(p, "GameFontNormal", U.Icon(ns.Icons.gear) .. " Display")
    t3:SetPoint("TOPLEFT", 14, line(24))
    local hudC = W.Check(p, "Show HUD (compact gold/time tracker)",
        function() return ns.db.hud.shown end,
        function(v) ns.db.hud.shown = v; ns.HUD.UpdateVisibility() end)
    hudC:SetPoint("TOPLEFT", 12, line(26))
    local autoC = W.Check(p, "Show HUD only while a fishing pole is equipped",
        function() return ns.db.hud.onlyWithPole end,
        function(v) ns.db.hud.onlyWithPole = v; ns.HUD.UpdateVisibility() end)
    autoC:SetPoint("TOPLEFT", 12, line(26))
    local lockC = W.Check(p, "Lock HUD position",
        function() return ns.db.hud.locked end,
        function(v) ns.db.hud.locked = v end)
    lockC:SetPoint("TOPLEFT", 12, line(26))
    local mmC = W.Check(p, "Show minimap button",
        function() return not ns.db.minimap.hide end,
        function(v) ns.db.minimap.hide = not v; ns.Minimap.Update() end)
    mmC:SetPoint("TOPLEFT", 12, line(26))

    local wipe = W.Button(p, "Forget zone data", 130, 22, function() StaticPopup_Show("REELGOLD_WIPE_ZONES") end)
    wipe:SetPoint("BOTTOMLEFT", 14, 12)
    p.version = W.Text(p, "GameFontDisableSmall")
    p.version:SetPoint("BOTTOMRIGHT", -14, 18)
    p.version:SetJustifyH("RIGHT")
end

local function RefreshSettings(p)
    p.srcBtn:SetText("Source: " .. ns.Pricing.SOURCE_LABELS[ns.db.priceSource])
    p.srcStatus:SetText(ns.Pricing.StatusText())
    if not p.tsmEdit:HasFocus() then p.tsmEdit:SetText(ns.db.tsmSource) end
    if not p.idleEdit:HasFocus() then p.idleEdit:SetText(math.floor(ns.db.idleTimeout / 60)) end
    if not p.learnEdit:HasFocus() then p.learnEdit:SetText(ns.db.minLearnCatches) end
    local gv = ns.GameVersion
    p.version:SetText(("v%s  ·  data %d (%s, client %s)"):format(ns.version, gv.DATA_VERSION, gv.DATA_DATE, gv.TESTED_CLIENT))
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
local TABS = {
    { key = "session",  label = "Session",  icon = ns.Icons.coin,  build = BuildSession,  refresh = RefreshSession },
    { key = "best",     label = "For me",   icon = ns.Icons.pole,  build = BuildBest,     refresh = RefreshBest },
    { key = "spots",    label = "Spots",    icon = ns.Icons.map,   build = BuildSpots,    refresh = RefreshSpots },
    { key = "tips",     label = "Tips",     icon = ns.Icons.book,  build = BuildTips,     refresh = RefreshTips },
    { key = "settings", label = "Settings", icon = ns.Icons.gear,  build = BuildSettings, refresh = RefreshSettings },
}

local function SelectTab(key)
    current = key
    ns.db.lastTab = key
    for _, t in ipairs(TABS) do
        panels[t.key]:SetShown(t.key == key)
        tabs[t.key]:SetAlpha(t.key == key and 1 or 0.6)
    end
    UI.Refresh()
end

local function Create()
    frame = W.Panel(UIParent, WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.main.point = { point, relPoint, x, y }
    end)
    local pt = ns.db.main.point
    if pt then frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else frame:SetPoint("CENTER") end
    tinsert(UISpecialFrames, "ReelGoldMainFrame")
    _G.ReelGoldMainFrame = frame

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(26, 26)
    logo:SetPoint("TOPLEFT", 10, -8)
    logo:SetTexture(ns.Icons.fishing)
    logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local title = W.Text(frame, "GameFontNormalLarge", "Reel|cffffd100Gold|r")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local prev
    for _, t in ipairs(TABS) do
        local tabW = math.floor((WIDTH - 28 - 4 * (#TABS - 1)) / #TABS)
        local b = W.Button(frame, t.label, tabW, 24, function() SelectTab(t.key) end)
        b:SetText("   " .. t.label)
        local ic = b:CreateTexture(nil, "OVERLAY")
        ic:SetSize(16, 16)
        ic:SetPoint("LEFT", 8, 0)
        ic:SetTexture(t.icon)
        ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 14, -40) end
        prev = b
        tabs[t.key] = b

        local p = CreateFrame("Frame", nil, frame)
        p:SetPoint("TOPLEFT", 4, -68)
        p:SetPoint("BOTTOMRIGHT", -4, 4)
        p:Hide()
        t.build(p)
        panels[t.key] = p
    end

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 1 then
            elapsed = 0
            if current == "session" then UI.Refresh() end
        end
    end)
    frame:Hide()
    SelectTab(ns.db.lastTab or "session")
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    for _, t in ipairs(TABS) do
        if t.key == current then t.refresh(panels[t.key]) end
    end
end

function UI.Toggle(tab)
    if not frame then Create() end
    if tab then
        frame:Show()
        SelectTab(tab)
    elseif frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        UI.Refresh()
    end
end

StaticPopupDialogs["REELGOLD_RESET"] = {
    text = "Reset the current ReelGold fishing session?",
    button1 = YES, button2 = NO,
    OnAccept = function() ns.Tracker.Reset() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs["REELGOLD_WIPE_ZONES"] = {
    text = "Forget all learned zone statistics? Spot ranking will go back to estimates.",
    button1 = YES, button2 = NO,
    OnAccept = function() wipe(ns.db.zoneStats); ns:FireRefresh() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
