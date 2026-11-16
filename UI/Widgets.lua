-- ReelGold: small widget factory built only on long-lived Blizzard templates
-- (UIPanelButtonTemplate, UICheckButtonTemplate, InputBoxTemplate,
-- BackdropTemplate) so the UI survives client updates.
local _, ns = ...

local W = {}
ns.Widgets = W

W.BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function W.Panel(parent, w, h)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetBackdrop(W.BACKDROP)
    f:SetBackdropColor(0.05, 0.07, 0.10, 0.92)
    f:SetBackdropBorderColor(0.45, 0.45, 0.50, 1)
    return f
end

function W.Text(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    return fs
end

function W.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 90, h or 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function W.Check(parent, label, getter, setter, tooltip)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    local fs = W.Text(c, "GameFontHighlightSmall", label)
    fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.label = fs
    c:SetScript("OnShow", function(self) self:SetChecked(getter()) end)
    c:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    if tooltip then
        c:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", GameTooltip_Hide)
    end
    c:SetChecked(getter())
    return c
end

function W.Edit(parent, w, numeric, onCommit)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w or 60, 20)
    e:SetAutoFocus(false)
    if numeric then e:SetNumeric(true) end
    local function commit(self)
        self:ClearFocus()
        if onCommit then onCommit(self, self:GetText()) end
    end
    e:SetScript("OnEnterPressed", commit)
    e:SetScript("OnEditFocusLost", function(self) if onCommit then onCommit(self, self:GetText()) end end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

-- Square item icon with border, quality tint and item tooltip.
function W.ItemIcon(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 22, size or 22)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.border:SetBlendMode("ADD")
    b.border:SetPoint("CENTER")
    b.border:SetSize((size or 22) * 1.8, (size or 22) * 1.8)
    b.border:Hide()
    function b:SetItem(id)
        self.itemID = id
        self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        self.icon:SetTexture(id and ns.C.GetItemIcon(id) or ns.Icons.question)
        local quality = id and select(3, ns.C.GetItemInfo(id))
        if quality and quality >= 2 then
            self.border:SetVertexColor(ns.Util.QualityColor(quality))
            self.border:Show()
        else
            self.border:Hide()
        end
    end
    -- full = true shows the whole texture (our round logo) instead of the
    -- usual icon crop that hides the square border of WoW icons.
    function b:SetTex(tex, full)
        self.itemID = nil
        self.icon:SetTexture(tex)
        if full then self.icon:SetTexCoord(0, 1, 0, 1) else self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
        self.border:Hide()
    end
    b:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            local info = ns.Fish[self.itemID]
            if info and info.use then GameTooltip:AddLine("ReelGold: " .. info.use, 0.2, 0.8, 1, true) end
            local d = ns.Pricing.GetDetail(self.itemID)
            local src = d.source
            local M = ns.Util.Money
            GameTooltip:AddLine(" ")
            if d.ah then
                GameTooltip:AddDoubleLine("AH price (" .. (src == "Vendor" and "Auctionator/TSM" or src) .. ")", M(d.ah), 1, 0.82, 0, 1, 1, 1)
                if d.cut > 0 then
                    GameTooltip:AddDoubleLine("After 5% AH cut", M(d.value), 1, 0.82, 0, 1, 1, 1)
                end
            elseif src ~= "Manual" then
                GameTooltip:AddLine("No AH price yet: run an Auctionator scan", 0.7, 0.7, 0.7)
            end
            if src == "Manual" then
                GameTooltip:AddDoubleLine("Your price", M(d.value), 1, 0.82, 0, 1, 1, 1)
            end
            GameTooltip:AddDoubleLine("Vendor price", M(d.vendor), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
            GameTooltip:AddDoubleLine("ReelGold counts", M(d.value) .. " (" .. (src == "Vendor" and "vendor" or src) .. ")",
                0.2, 1, 0.2, 0.2, 1, 0.2)
            if src == "Auctionator" then
                local age = ns.Pricing.GetAuctionAge(self.itemID)
                local txt = age == nil and "older than 3 weeks" or age == 0 and "today"
                    or age == 1 and "1 day ago" or (age .. " days ago")
                GameTooltip:AddDoubleLine("Last seen on the AH", txt, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- A simple pager: fixed rows, Prev/Next buttons and mouse wheel.
function W.Pager(parent, rowsPerPage, onPage)
    local p = { page = 1, total = 0, rows = rowsPerPage }
    local prev = W.Button(parent, "<", 28, 20, function() p:Go(p.page - 1) end)
    local next_ = W.Button(parent, ">", 28, 20, function() p:Go(p.page + 1) end)
    local label = W.Text(parent, "GameFontNormalSmall")
    p.prev, p.next, p.label = prev, next_, label
    function p:Pages() return math.max(1, math.ceil(self.total / self.rows)) end
    function p:Go(n)
        self.page = math.min(math.max(1, n), self:Pages())
        label:SetText(("%d / %d"):format(self.page, self:Pages()))
        prev:SetEnabled(self.page > 1)
        next_:SetEnabled(self.page < self:Pages())
        onPage(self.page)
    end
    function p:SetTotal(t)
        self.total = t
        if self.page > self:Pages() then self.page = self:Pages() end
    end
    function p:Anchor(point, rel, relPoint, x, y)
        next_:SetPoint(point, rel, relPoint, x, y)
        label:SetPoint("RIGHT", next_, "LEFT", -6, 0)
        prev:SetPoint("RIGHT", label, "LEFT", -6, 0)
    end
    parent:EnableMouseWheel(true)
    parent:SetScript("OnMouseWheel", function(_, delta) p:Go(p.page - delta) end)
    return p
end
