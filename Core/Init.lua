-- ReelGold: bootstrap, saved variables, events and slash commands.
local ADDON, ns = ...
local U = ns.Util

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = GetMeta and GetMeta(ADDON, "Version") or "dev"
if ns.version == "@project-version@" then ns.version = "dev" end

local DB_DEFAULTS = {
    schema = 1,
    timeUnit = "hour",
    customMinutes = 30,
    idleTimeout = 300,
    priceSource = "auto",
    tsmSource = "DBMarket",
    applyAHCut = true,
    minLearnCatches = 40,
    onlyFishable = false,
    lastTab = "session",
    seenDataVersion = 0,
    warnedInterface = 0,
    hud = { shown = true, onlyWithPole = true, locked = false },
    main = {},
    minimap = { angle = 200, hide = false },
    priceOverrides = {},
    zoneStats = {},
}

-- Saved variable migrations: add a function for every schema bump so
-- updates never wipe user data.
local MIGRATIONS = {
    -- [2] = function(db) ... end,
}

local function Migrate(db)
    local target = DB_DEFAULTS.schema
    for v = (db.schema or 1) + 1, target do
        if MIGRATIONS[v] then MIGRATIONS[v](db) end
        db.schema = v
    end
end

local refresh = U.Debounce(0.2, function()
    if ns.UI then ns.UI.Refresh() end
    if ns.HUD then ns.HUD.Refresh() end
end)
function ns:FireRefresh() refresh() end

local function VersionNotices()
    local gv = ns.GameVersion
    local _, _, _, clientInterface = GetBuildInfo()
    if clientInterface and clientInterface > gv.TESTED_INTERFACE and ns.db.warnedInterface ~= clientInterface then
        ns.db.warnedInterface = clientInterface
        U.Print(("Your client (interface %d) is newer than the data this version was checked on (%s). Everything keeps working; spot estimates may be refreshed in a coming update - your own catch data is always current.")
            :format(clientInterface, gv.TESTED_CLIENT))
    end
    if ns.db.seenDataVersion ~= gv.DATA_VERSION then
        if ns.db.seenDataVersion > 0 then
            U.Print(("Fishing data updated (data v%d, %s)."):format(gv.DATA_VERSION, gv.DATA_DATE))
        end
        ns.db.seenDataVersion = gv.DATA_VERSION
    end
end

local function PrimeItemCache()
    for id in pairs(ns.Fish) do ns.C.RequestItem(id) end
end

local events = CreateFrame("Frame")
ns.events = events
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        ReelGoldDB = U.CopyDefaults(DB_DEFAULTS, ReelGoldDB)
        Migrate(ReelGoldDB)
        ReelGoldCharDB = ReelGoldCharDB or {}
        ReelGoldCharDB.session = ReelGoldCharDB.session or ns.Tracker.NewSession()
        ns.db, ns.char = ReelGoldDB, ReelGoldCharDB
        events:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        PrimeItemCache()
        ns.Options.Register()
        ns.Minimap.Update()
        ns.HUD.UpdateVisibility()
        VersionNotices()
        events:RegisterEvent("LOOT_READY")
        events:RegisterEvent("LOOT_OPENED")
        events:RegisterEvent("LOOT_CLOSED")
        events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        events:RegisterEvent("UNIT_INVENTORY_CHANGED")
        events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        events:RegisterEvent("SKILL_LINES_CHANGED")

    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        ns.Tracker.OnLootReady()
    elseif event == "LOOT_CLOSED" then
        ns.Tracker.OnLootClosed()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then
        ns.HUD.UpdateVisibility()
        refresh()
    else
        refresh()
    end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_REELGOLD1 = "/reelgold"
SLASH_REELGOLD2 = "/rgold"
SlashCmdList.REELGOLD = function(msg)
    local cmd = strlower(strtrim(msg or ""))
    if cmd == "" or cmd == "show" then
        ns.UI.Toggle()
    elseif cmd == "spots" or cmd == "tips" or cmd == "settings" or cmd == "session" or cmd == "best" then
        ns.UI.Toggle(cmd)
    elseif cmd == "hud" then
        ns.HUD.Toggle()
    elseif cmd == "reset" then
        ns.Tracker.Reset()
        U.Print("Session reset.")
    elseif cmd == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        ns.Minimap.Update()
    elseif cmd == "options" or cmd == "config" then
        ns.Options.Open()
    elseif cmd == "version" then
        local gv = ns.GameVersion
        U.Print(("v%s, data v%d (%s), checked on client %s / interface %d")
            :format(ns.version, gv.DATA_VERSION, gv.DATA_DATE, gv.TESTED_CLIENT, gv.TESTED_INTERFACE))
    else
        U.Print("Commands: /rgold [show | session | best | spots | tips | settings | options | hud | reset | minimap | version]")
    end
end
