-- ReelGold: page in Blizzard's Options -> AddOns (Settings API canvas page).
-- Shows the most used settings and a button that opens the full window.
local _, ns = ...
local W, U = ns.Widgets, ns.Util

local Options = {}
ns.Options = Options

local panel, category

local function Build()
    panel = CreateFrame("Frame")
    panel.name = "ReelGold" -- used by the legacy InterfaceOptions fallback

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(36, 36)
    logo:SetPoint("TOPLEFT", 16, -16)
    logo:SetTexture(ns.Icons.fishing)
    logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local title = W.Text(panel, "GameFontNormalHuge", "Reel|cffffd100Gold|r")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -2)
    local sub = W.Text(panel, "GameFontHighlightSmall",
        "Fishing gold per time, best profitable spots and tips for WoW: Forever.")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local open = W.Button(panel, "Open ReelGold", 140, 24, function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
        ns.UI.Toggle("session")
    end)
    open:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
    local spots = W.Button(panel, "Best spots", 110, 24, function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
        ns.UI.Toggle("spots")
    end)
    spots:SetPoint("LEFT", open, "RIGHT", 8, 0)

    local y = -112
    local function header(text, icon)
        local h = W.Text(panel, "GameFontNormal", U.Icon(icon) .. " " .. text)
        h:SetPoint("TOPLEFT", 16, y)
        y = y - 24
    end
    local function check(label, get, set, tip)
        local c = W.Check(panel, label, get, set, tip)
        c:SetPoint("TOPLEFT", 14, y)
        y = y - 26
        return c
    end

    header("Prices", ns.Icons.coin)
    panel.srcBtn = W.Button(panel, "", 260, 22, function()
        local list = ns.Pricing.SOURCES
        local idx = 1
        for i, s in ipairs(list) do if s == ns.db.priceSource then idx = i end end
        ns.db.priceSource = list[idx % #list + 1]
        Options.Refresh()
        ns:FireRefresh()
    end)
    panel.srcBtn:SetPoint("TOPLEFT", 18, y)
    panel.srcStatus = W.Text(panel, "GameFontHighlightSmall")
    panel.srcStatus:SetPoint("LEFT", panel.srcBtn, "RIGHT", 10, 0)
    y = y - 30
    check("Subtract 5% Auction House cut",
        function() return ns.db.applyAHCut end,
        function(v) ns.db.applyAHCut = v; ns:FireRefresh() end)

    y = y - 6
    header("Tracking", ns.Icons.clock)
    local idleL = W.Text(panel, "GameFontHighlightSmall", "Pause session after no catch for (minutes):")
    idleL:SetPoint("TOPLEFT", 20, y - 4)
    panel.idleEdit = W.Edit(panel, 40, true, function(self, text)
        local n = tonumber(text)
        if n and n >= 1 and n <= 60 then ns.db.idleTimeout = n * 60 end
        self:SetText(math.floor(ns.db.idleTimeout / 60))
    end)
    panel.idleEdit:SetPoint("LEFT", idleL, "RIGHT", 10, 0)
    y = y - 32

    header("Display", ns.Icons.gear)
    check("Show HUD (compact gold/time tracker)",
        function() return ns.db.hud.shown end,
        function(v) ns.db.hud.shown = v; ns.HUD.UpdateVisibility() end)
    check("Show HUD only while a fishing pole is equipped",
        function() return ns.db.hud.onlyWithPole end,
        function(v) ns.db.hud.onlyWithPole = v; ns.HUD.UpdateVisibility() end)
    check("Lock HUD position",
        function() return ns.db.hud.locked end,
        function(v) ns.db.hud.locked = v end)
    check("Show minimap button",
        function() return not ns.db.minimap.hide end,
        function(v) ns.db.minimap.hide = not v; ns.Minimap.Update() end)

    local more = W.Text(panel, "GameFontDisableSmall",
        "More settings (TSM price source, manual item prices, learning) are on the Settings tab of the ReelGold window.  Commands: /rgold")
    more:SetPoint("TOPLEFT", 18, y - 10)
    more:SetPoint("RIGHT", -18, 0)

    panel.version = W.Text(panel, "GameFontDisableSmall")
    panel.version:SetPoint("BOTTOMRIGHT", -16, 16)
    panel.version:SetJustifyH("RIGHT")

    panel:SetScript("OnShow", Options.Refresh)
end

function Options.Refresh()
    if not panel then return end
    panel.srcBtn:SetText("Price source: " .. ns.Pricing.SOURCE_LABELS[ns.db.priceSource])
    panel.srcStatus:SetText(ns.Pricing.StatusText())
    if not panel.idleEdit:HasFocus() then panel.idleEdit:SetText(math.floor(ns.db.idleTimeout / 60)) end
    local gv = ns.GameVersion
    panel.version:SetText(("v%s  ·  data %d (%s)"):format(ns.version, gv.DATA_VERSION, gv.DATA_DATE))
end

function Options.Register()
    if panel then return end
    Build()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "ReelGold")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- Opens Options -> AddOns -> ReelGold.
function Options.Open()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and panel then
        InterfaceOptionsFrame_OpenToCategory(panel)
    else
        ns.UI.Toggle("settings")
    end
end
