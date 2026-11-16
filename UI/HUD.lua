-- ReelGold: compact movable tracker (gold per time unit, active time, best catch).
local _, ns = ...
local W, U = ns.Widgets, ns.Util

local HUD = {}
ns.HUD = HUD
local f

function HUD.GetFrame() return f end

local function Create()
    f = W.Panel(UIParent, 222, 62)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not ns.db.hud.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.hud.point = { point, relPoint, x, y }
    end)
    local pt = ns.db.hud.point
    if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("TOP", 0, -140) end

    f.icon = W.ItemIcon(f, 34)
    f.icon:SetPoint("LEFT", 8, 0)
    f.icon:EnableMouse(false)
    f.rate = W.Text(f, "GameFontNormal")
    f.rate:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, 2)
    f.line2 = W.Text(f, "GameFontHighlightSmall")
    f.line2:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.line3 = W.Text(f, "GameFontHighlightSmall")
    f.line3:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 8, -2)
    for _, fs in ipairs({ f.rate, f.line2, f.line3 }) do
        fs:SetPoint("RIGHT", f, "RIGHT", -22, 0)
        fs:SetWordWrap(false)
    end

    -- Close button (X) in the top right corner.
    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetSize(22, 22)
    f.close:SetPoint("TOPRIGHT", 1, 1)
    f.close:SetScript("OnClick", function() HUD.Close() end)
    f.close:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hide HUD", 1, 1, 1)
        GameTooltip:AddLine("Show it again with /rgold hud, a right-click on the minimap button, or in Settings.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    f.close:SetScript("OnLeave", GameTooltip_Hide)

    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.UI.Toggle("session") end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("ReelGold", 1, 0.82, 0)
        GameTooltip:AddLine("Drag to move, right-click to open.", 0.8, 0.8, 0.8)
        local tips = ns.Recommend.ContextTips()
        if #tips > 0 then GameTooltip:AddLine(" ") end
        for i = 1, math.min(4, #tips) do
            GameTooltip:AddLine(U.Icon(tips[i].icon) .. " " .. tips[i].text, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 1 then elapsed = 0; HUD.Refresh() end
    end)
end

function HUD.Refresh()
    if not f or not f:IsShown() then return end
    local T = ns.Tracker
    local s = T.Session()
    f.rate:SetText(U.Money(T.Rate(), true) .. " |cff999999" .. T.UnitLabel() .. "|r")
    local idle = (s.catches > 0 and T.IsIdle()) and " |cff999999(paused)|r" or ""
    f.line2:SetText(("%s  ·  %d catches%s"):format(U.Duration(T.ActiveSeconds()), s.catches, idle))

    local top = T.SortedItems(s.items)[1]
    if top then
        f.icon:SetItem(top.id)
        f.line3:SetText("Total " .. U.Money(T.TotalValue(), true))
    else
        local hasPole, hasLure = ns.C.GetPoleState()
        f.icon:SetTex(ns.Icons.fishing)
        f.line3:SetText(hasPole and not hasLure and "|cffffaa00No lure!|r" or "Cast your line...")
    end
end

function HUD.UpdateVisibility()
    local want = ns.db.hud.shown
    if want and ns.db.hud.onlyWithPole then
        local hasPole = ns.C.GetPoleState()
        want = hasPole or not ns.Tracker.IsIdle()
    end
    if want and not f then Create() end
    if f then f:SetShown(want) end
    HUD.Refresh()
end


function HUD.Close()
    ns.db.hud.shown = false
    HUD.UpdateVisibility()
    U.Print("HUD hidden. Show it again with /rgold hud or a right-click on the minimap button.")
    if ns.UI then ns.UI.Refresh() end
end

function HUD.Toggle()
    ns.db.hud.shown = not ns.db.hud.shown
    HUD.UpdateVisibility()
end
