-- Fishing Coach: "show on map" marker for the For me and Spots tabs.
-- Draws our own red X on the Blizzard world map canvas (WoW: Forever's
-- user-waypoint API is not reliable, so no C_Map.SetUserWaypoint), and opens
-- the world map on that zone. Read-only and display-only: nothing is clicked,
-- moved or automated for the player.
local _, ns = ...
local U = ns.Util

local MapPin = {}
ns.MapPin = MapPin

local marker, target, hooked

local function Canvas()
    if not WorldMapFrame then return nil end
    if type(WorldMapFrame.GetCanvas) == "function" then
        local ok, canvas = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
        if ok and canvas then return canvas end
    end
    return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

local function ShownMapID()
    if not (WorldMapFrame and type(WorldMapFrame.GetMapID) == "function") then return nil end
    local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
    return ok and id or nil
end

local function KeepSize()
    -- The canvas zooms by scaling; undo that so the X keeps its size.
    local parent = marker and marker:GetParent()
    local scale = parent and parent.GetScale and parent:GetScale()
    if scale and scale > 0 then marker:SetScale(1 / scale) end
end

local function CreateMarker(parent)
    marker = CreateFrame("Button", nil, parent)
    marker:SetSize(34, 34)
    marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    marker.glow = marker:CreateTexture(nil, "BACKGROUND")
    marker.glow:SetTexture("Interface\\Cooldown\\star4")
    marker.glow:SetBlendMode("ADD")
    marker.glow:SetVertexColor(1, 0.82, 0, 0.9)
    marker.glow:SetPoint("CENTER")
    marker.glow:SetSize(64, 64)
    marker.x = marker:CreateTexture(nil, "ARTWORK")
    marker.x:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    marker.x:SetAllPoints()
    marker.label = marker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    marker.label:SetShadowOffset(1, -1)
    marker.label:SetPoint("TOP", marker, "BOTTOM", 0, -1)
    marker:SetScript("OnEnter", function(self)
        if not target then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Fishing Coach: " .. target.zone, 1, 0.82, 0)
        GameTooltip:AddLine(target.spot or "", 1, 1, 1, true)
        if target.posSource == "yours" then
            GameTooltip:AddLine("Where you caught the most fish in this zone.", 0.2, 1, 0.2, true)
        else
            GameTooltip:AddLine("Approximate area. Fish here and Fishing Coach pins your real spot.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine("Right-click: remove the marker", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    marker:SetScript("OnLeave", GameTooltip_Hide)
    marker:SetScript("OnClick", function(_, button)
        if button == "RightButton" then MapPin.Clear() end
    end)
    marker:SetScript("OnUpdate", KeepSize)
    marker:Hide()
end

-- Places or hides the X for the map currently shown.
function MapPin.Update()
    if marker then marker:Hide() end
    if not (target and target.x and WorldMapFrame and WorldMapFrame:IsShown()) then return end
    if ShownMapID() ~= target.mapID then return end
    local parent = Canvas()
    if not parent then return end
    if not marker then CreateMarker(parent) end
    if marker:GetParent() ~= parent then marker:SetParent(parent) end
    local w, h = parent:GetWidth(), parent:GetHeight()
    if not w or not h or w <= 1 or h <= 1 then return end
    marker:ClearAllPoints()
    marker:SetPoint("CENTER", parent, "TOPLEFT", w * target.x, -h * target.y)
    marker:SetFrameLevel(((parent.GetFrameLevel and parent:GetFrameLevel()) or 0) + 2000)
    marker.label:SetText(target.zone)
    KeepSize()
    marker:Show()
end

local function Hook()
    if hooked or not WorldMapFrame then return end
    hooked = true
    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function() MapPin.Update() end)
        WorldMapFrame:HookScript("OnHide", function() if marker then marker:Hide() end end)
    end
    if type(WorldMapFrame.OnMapChanged) == "function" and hooksecurefunc then
        pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() MapPin.Update() end)
    end
end

-- Opens the world map on mapID. Not possible in combat (Blizzard rule).
local function OpenMap(mapID)
    if InCombatLockdown and InCombatLockdown() then return false end
    if WorldMapFrame and WorldMapFrame:IsShown() then
        return pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
    end
    if OpenWorldMap and pcall(OpenWorldMap, mapID) then return true end
    if ToggleWorldMap and pcall(ToggleWorldMap) and WorldMapFrame then
        return pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
    end
    return false
end

-- Shows a spot entry (from Recommend.Rank / ForSkill) on the world map.
function MapPin.Show(entry)
    if not (entry and entry.mapID) then
        U.Print("This spot has no map yet.")
        return
    end
    target = { mapID = entry.mapID, x = entry.x, y = entry.y, zone = entry.zone,
               spot = entry.spot, posSource = entry.posSource }
    Hook()
    local opened = OpenMap(entry.mapID)
    C_Timer.After(0, MapPin.Update)
    if not entry.x then
        U.Print(("%s: no exact spot known yet. Fish there once and Fishing Coach marks your spot on the map."):format(entry.zone))
    elseif opened then
        U.Print(("Marked %s (%s) at %.1f, %.1f%s. Right-click the X to remove it."):format(entry.zone, entry.spot or "",
            entry.x * 100, entry.y * 100, entry.posSource == "yours" and ", your spot" or ", approximate"))
    else
        U.Print(("Marked %s at %.1f, %.1f. Open the map (M) after combat to see it."):format(entry.zone, entry.x * 100, entry.y * 100))
    end
end

function MapPin.Clear()
    target = nil
    if marker then marker:Hide() end
end

function MapPin.GetTarget() return target end
function MapPin.GetMarker() return marker end
