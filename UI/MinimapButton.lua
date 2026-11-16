-- Fishing Coach: minimap button (no libraries) + Addon Compartment entry.
local _, ns = ...

local MM = {}
ns.Minimap = MM
local btn

local function UpdatePosition()
    local angle = math.rad(ns.db.minimap.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 10
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("Fishing |cffffd100Coach|r")
    local T = ns.Tracker
    GameTooltip:AddDoubleLine("Gold " .. T.UnitLabel(), ns.Util.Money(T.Rate(), true), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session value", ns.Util.Money(T.TotalValue(), true), 1, 0.82, 0, 1, 1, 1)
    local best = ns.Recommend.Rank()[1]
    if best then
        GameTooltip:AddDoubleLine("Best spot", best.zone, 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open  ·  Right-click: toggle HUD", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function Create()
    btn = CreateFrame("Button", "FishingCoachMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetTexture(ns.Icons.logo)
    icon:SetPoint("TOPLEFT", 5, -4)

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ns.HUD.Toggle() else ns.UI.Toggle() end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", ShowTooltip)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    UpdatePosition()
end

function MM.Update()
    if ns.db.minimap.hide then
        if btn then btn:Hide() end
        return
    end
    if not btn then Create() end
    btn:Show()
end

-- Addon Compartment (the addon list button on the minimap), declared in the TOC.
function FishingCoach_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then ns.HUD.Toggle() else ns.UI.Toggle() end
end
function FishingCoach_OnAddonCompartmentEnter(_, menuButtonFrame)
    ShowTooltip(menuButtonFrame)
end
function FishingCoach_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
