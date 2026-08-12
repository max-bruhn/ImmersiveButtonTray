--[[
 Immersive Button Tray - render layer (text-only)
 One draggable handle anchors the dock. Below/above it (per grow) sits the body:
 hotlink buttons first (always shown), then tray buttons (shown only while the
 dock is expanded). Collected minimap buttons keep an invisible copy of the real
 addon frame on top to catch clicks; the addon's own hover handlers are removed
 so its icon can't flash in behind the text label.
--]]

IBT = IBT or {}
ImmersiveButtonTrayDB = ImmersiveButtonTrayDB or {}
IBT.buttons = IBT.buttons or {}
IBT.expanded = false  -- opened only by clicking the handle; auto-folds when idle

local BTN_H = 26      -- fixed button height so every button is uniform

-- ---------------------------------------------------------------------------
-- placement
-- ---------------------------------------------------------------------------
function IBT.PlacePoint(f, pt)
    if not f or not pt then return end
    local rel = (pt[2] and getglobal(pt[2])) or UIParent
    f:ClearAllPoints()
    f:SetPoint(pt[1], rel, pt[3], pt[4], pt[5])
end

function IBT.SavePoint(f)
    local p, _, rp, x, y = f:GetPoint()
    ImmersiveButtonTrayDB.point = { p or "CENTER", "UIParent", rp or "CENTER", x or 0, y or 0 }
end

-- ---------------------------------------------------------------------------
-- buttons
-- ---------------------------------------------------------------------------
-- subtle theme-matched hover: a soft accent overlay + accent border
function IBT.ButtonHoverOn(b)
    if not b then return end
    if b.hover then b.hover:Show() end
    if b.SetBackdropBorderColor then b:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.5) end
end

function IBT.ButtonHoverOff(b)
    if not b then return end
    if b.hover then b.hover:Hide() end
    local n = b._normBorder
    if n and b.SetBackdropBorderColor then b:SetBackdropBorderColor(n[1], n[2], n[3], 1) end
end

function IBT.ButtonOnClick()
    local e = this.entry
    if e and e.kind == "command" then IBT.RunCommand(e.command) end
end

function IBT.ButtonOnEnter()
    IBT.ButtonHoverOn(this)
    local e = this.entry
    if not e or e.kind ~= "command" then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.label or "")
    if e.command and e.command ~= "" then GameTooltip:AddLine(e.command, 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

function IBT.ButtonOnLeave()
    IBT.ButtonHoverOff(this)
    GameTooltip:Hide()
end

function IBT.GetButton(id)
    if IBT.buttons[id] then return IBT.buttons[id] end
    local b = CreateFrame("Button", "IBTButton_" .. IBT.SafeName(id), UIParent)
    b:SetWidth(26); b:SetHeight(26)
    local hv = b:CreateTexture(nil, "ARTWORK")
    hv:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    hv:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    hv:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    hv:Hide()
    b.hover = hv
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetTextColor(0.92, 0.92, 0.92)
    b.text = t
    b:SetScript("OnClick", IBT.ButtonOnClick)
    b:SetScript("OnEnter", IBT.ButtonOnEnter)
    b:SetScript("OnLeave", IBT.ButtonOnLeave)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    IBT.buttons[id] = b
    return b
end

-- The real minimap frame catches clicks. It is parented to a separate, never-
-- faded holder (NOT the body) and anchored over the text button, so the body's
-- fade animation can't recompute its alpha and flash the icon. Its own alpha is
-- pinned to 0, and an OnShow guard re-pins it, so it stays permanently invisible.
local function ForceAlpha0() this:SetAlpha(0) end
function IBT.AttachMinimap(b, e)
    local real = getglobal(e.id)
    if not real then return end
    -- cache the addon's own state ONCE (before we override it) so we can put it
    -- back if the button is later returned to the minimap
    if not b._mmSaved then
        b._mmSaved = {
            enter = real:GetScript("OnEnter"),
            leave = real:GetScript("OnLeave"),
            dragStart = real:GetScript("OnDragStart"),
            dragStop = real:GetScript("OnDragStop"),
            update = real:GetScript("OnUpdate"),
            show = real:GetScript("OnShow"),
            movable = (real.IsMovable and real:IsMovable()) or false,
            point = { real:GetPoint() },
            parent = real:GetParent(),
        }
    end
    b.mmReal = real
    real:SetScript("OnDragStart", nil)
    real:SetScript("OnDragStop", nil)
    real:SetScript("OnUpdate", nil)
    -- our own hover handlers (replacing the addon's, which would flash the icon)
    real:SetScript("OnEnter", function() IBT.ButtonHoverOn(b) end)
    real:SetScript("OnLeave", function() IBT.ButtonHoverOff(b) end)
    real:SetScript("OnShow", ForceAlpha0)
    if real.SetMovable then real:SetMovable(false) end
    real:SetParent(IBT.realHolder or UIParent)
    real:SetFrameStrata("HIGH")
    real:SetFrameLevel(500)
    real:ClearAllPoints()
    real:SetAllPoints(b) -- cross-parent anchor: follows the button's position
    real:SetAlpha(0)
    real:Show()
end

function IBT.RestoreMinimapButton(id)
    local real = getglobal(id)
    if not real then return end
    local b = IBT.buttons and IBT.buttons[id]
    local s = b and b._mmSaved
    real:SetScript("OnShow", s and s.show or nil) -- restore the addon's own OnShow (or clear our guard)
    if s then
        real:SetScript("OnEnter", s.enter)
        real:SetScript("OnLeave", s.leave)
        real:SetScript("OnDragStart", s.dragStart)
        real:SetScript("OnDragStop", s.dragStop)
        real:SetScript("OnUpdate", s.update)
        if real.SetMovable then real:SetMovable(s.movable) end
    end
    real:SetParent((s and s.parent) or Minimap)
    real:ClearAllPoints()
    real:SetAlpha(1)
    if s and s.point and s.point[1] then
        real:SetPoint(s.point[1], s.point[2] or Minimap, s.point[3] or "CENTER", s.point[4] or 0, s.point[5] or 0)
    else
        real:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    end
    real:Show()
    -- drop our cached refs so the rebuild hide-loop won't re-hide it, and a later
    -- re-collect starts fresh
    if b then b.mmReal = nil; b._mmSaved = nil end
end

function IBT.ReapplyMinimap()
    if not IBT.buttons then return end
    local ordered = IBT.OrderedEntries()
    local i
    for i = 1, table.getn(ordered) do
        local e = ordered[i]
        if e.kind == "minimap" and not e.hidden then
            local b = IBT.buttons[e.id]
            if b and b:IsShown() then IBT.AttachMinimap(b, e) end
        end
    end
end

-- set the label, cropping to full characters when the width is fixed
function IBT.ConfigureButton(b, e)
    local db = ImmersiveButtonTrayDB
    b.entry = e
    b:SetHeight(BTN_H)

    local label = e.label or e.id
    b.text:SetText(label)

    local w
    if db.buttonWidthMode == "fixed" then
        w = db.buttonWidth
        local avail = w - 10
        if b.text:GetStringWidth() > avail then
            local s = label
            while string.len(s) > 1 and b.text:GetStringWidth() > avail do
                s = string.sub(s, 1, string.len(s) - 1)
                b.text:SetText(s)
            end
        end
    else
        w = b.text:GetStringWidth() + 12
        if w < 24 then w = 24 end
    end
    b.text:ClearAllPoints(); b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:SetWidth(w); b._w = w

    IBT.ThemeButton(b)
    if e.kind == "minimap" then IBT.AttachMinimap(b, e) end
end

-- ---------------------------------------------------------------------------
-- layout: columns of `rowsize` buttons, growing down (default) or up
-- ---------------------------------------------------------------------------
function IBT.LayoutList(container, list)
    local db = ImmersiveButtonTrayDB
    local pad, sp, rows = 0, db.spacing, db.rowsize
    local n = table.getn(list)
    if n == 0 then
        container:SetWidth(1); container:SetHeight(1)
        return
    end
    local rowH = BTN_H
    local cols = math.ceil(n / rows)

    local colW, i = {}, nil
    for i = 1, n do
        local col = math.floor((i - 1) / rows) + 1
        local w = list[i]._w or rowH
        if not colW[col] or w > colW[col] then colW[col] = w end
    end
    local colX, acc, c = {}, 0, nil
    for c = 1, cols do
        colX[c] = acc
        acc = acc + colW[c] + sp
    end
    local usedRows = (n < rows) and n or rows

    container:SetWidth((acc - sp) + pad * 2)
    container:SetHeight(usedRows * rowH + (usedRows - 1) * sp + pad * 2)

    for i = 1, n do
        local b = list[i]
        local col = math.floor((i - 1) / rows)
        local row = math.mod((i - 1), rows)
        b:ClearAllPoints()
        if db.grow == "up" then
            b:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", pad + colX[col + 1], pad + row * (rowH + sp))
        else
            b:SetPoint("TOPLEFT", container, "TOPLEFT", pad + colX[col + 1], -(pad + row * (rowH + sp)))
        end
    end
end

-- ---------------------------------------------------------------------------
-- frames
-- ---------------------------------------------------------------------------
function IBT.BuildFrames()
    if IBT.body then return end

    -- handle (drag anchor + toggle + options)
    local tg = CreateFrame("Button", "IBTToggle", UIParent)
    tg:SetWidth(48); tg:SetHeight(12)
    tg:SetFrameStrata("MEDIUM")
    IBT.PlacePoint(tg, ImmersiveButtonTrayDB.point)
    tg:SetMovable(true); tg:EnableMouse(true)
    tg:SetClampedToScreen(true) -- can't be dragged off-screen
    tg:RegisterForDrag("LeftButton")
    tg:SetScript("OnDragStart", function() if not ImmersiveButtonTrayDB.locked then this:StartMoving() end end)
    tg:SetScript("OnDragStop", function() this:StopMovingOrSizing(); IBT.SavePoint(this) end)
    tg:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tg:SetScript("OnClick", function()
        if arg1 == "RightButton" then IBT.OpenOptions() else IBT.ToggleManual() end
    end)
    tg.dots = {}
    local d
    for d = 1, 3 do
        local dot = tg:CreateTexture(nil, "OVERLAY")
        dot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        dot:SetVertexColor(0.7, 0.7, 0.7, 1)
        dot:SetWidth(2.5); dot:SetHeight(2.5)
        dot:SetPoint("CENTER", tg, "CENTER", (d - 2) * 6, 0)
        tg.dots[d] = dot
    end
    IBT.toggle = tg

    -- body: holds all buttons, anchored to the handle
    local body = CreateFrame("Frame", "IBTBody", UIParent)
    body:SetFrameStrata("MEDIUM")
    IBT.body = body

    -- holder for the invisible click-catchers; never faded, so decoupled from
    -- the body's alpha animation (prevents the collected icons flashing on fade)
    local holder = CreateFrame("Frame", "IBTRealHolder", UIParent)
    holder:SetAllPoints(UIParent)
    holder:SetFrameStrata("HIGH")
    IBT.realHolder = holder

    IBT.ApplyToggleSkin()
    IBT.StartFadeTicker()
end

-- the handle is a plain borderless dark bar - no border, no glow
function IBT.ApplyToggleSkin()
    local tg = IBT.toggle
    if not tg then return end
    tg:SetWidth(ImmersiveButtonTrayDB.anchorWidth or 48)
    tg:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
    tg:SetBackdropColor(0.10, 0.10, 0.10, ImmersiveButtonTrayDB.bgAlpha or 0.9)
end

-- anchor the body under/over the handle at the chosen alignment; the gap is the
-- spacing setting, so spacing 0 puts the first button flush against the handle
function IBT.AnchorBody()
    if not IBT.body or not IBT.toggle then return end
    IBT.body:ClearAllPoints()
    local gap = ImmersiveButtonTrayDB.spacing or 0
    local align = ImmersiveButtonTrayDB.trayAlign or "center"
    local up = (ImmersiveButtonTrayDB.grow == "up")
    local a, rel
    if align == "left" then
        a = up and "BOTTOMLEFT" or "TOPLEFT"
        rel = up and "TOPLEFT" or "BOTTOMLEFT"
    elseif align == "right" then
        a = up and "BOTTOMRIGHT" or "TOPRIGHT"
        rel = up and "TOPRIGHT" or "BOTTOMRIGHT"
    else
        a = up and "BOTTOM" or "TOP"
        rel = up and "TOP" or "BOTTOM"
    end
    IBT.body:SetPoint(a, IBT.toggle, rel, 0, up and gap or -gap)
end

function IBT.ApplyLock()
    IBT.ApplyToggleSkin()
end

-- move the handle back to the centre of the screen
function IBT.ResetAnchor()
    ImmersiveButtonTrayDB.point = { "CENTER", "UIParent", "CENTER", 0, 0 }
    if IBT.toggle then IBT.PlacePoint(IBT.toggle, ImmersiveButtonTrayDB.point) end
    IBT.Relayout()
end

-- expand/fold state
function IBT.SetExpanded(v)
    if IBT.expanded ~= v then
        IBT.expanded = v
        IBT.Relayout()
    end
end

-- left-click the handle: toggle the tray open/closed. This is the ONLY way to
-- open it; hovering never opens it (hover only affects the fade).
function IBT.ToggleManual()
    IBT.SetExpanded(not IBT.expanded)
end

-- the click-catcher lives in the holder (not the button), so we must show/hide
-- it explicitly alongside its button; alpha stays pinned at 0 either way
local function SetRealShown(b, shown)
    if not b.mmReal then return end
    if shown then b.mmReal:SetAlpha(0); b.mmReal:Show() else b.mmReal:Hide() end
end

-- position hotlinks (always) + tray (when expanded) inside the body
function IBT.Relayout()
    if not IBT.body then return end
    local list, i = {}, nil
    local hot = IBT._hotBtns or {}
    local tray = IBT._trayBtns or {}
    for i = 1, table.getn(hot) do hot[i]:Show(); SetRealShown(hot[i], true); table.insert(list, hot[i]) end
    if IBT.expanded then
        for i = 1, table.getn(tray) do tray[i]:Show(); SetRealShown(tray[i], true); table.insert(list, tray[i]) end
    else
        for i = 1, table.getn(tray) do tray[i]:Hide(); SetRealShown(tray[i], false) end
    end

    if table.getn(list) == 0 then IBT.body:Hide(); return end
    IBT.LayoutList(IBT.body, list)
    IBT.AnchorBody()
    IBT.body:Show()
    if IBT.toggle then IBT.body:SetAlpha(IBT.toggle:GetAlpha()) end
end

-- ---------------------------------------------------------------------------
-- master rebuild
-- ---------------------------------------------------------------------------
function IBT.Rebuild()
    if not IBT.body then return end
    IBT.ResolveStyle()

    local id, b
    for id, b in pairs(IBT.buttons) do
        b:Hide()
        if b.mmReal then b.mmReal:Hide() end
    end

    local hot, tray = IBT.DisplayEntries()
    IBT._hotBtns, IBT._trayBtns = {}, {}
    local i
    for i = 1, table.getn(hot) do
        local e = hot[i]
        if not e.hidden then
            local btn = IBT.GetButton(e.id)
            IBT.ConfigureButton(btn, e)
            btn:SetParent(IBT.body)
            table.insert(IBT._hotBtns, btn)
        end
    end
    for i = 1, table.getn(tray) do
        local e = tray[i]
        if not e.hidden then
            local btn = IBT.GetButton(e.id)
            IBT.ConfigureButton(btn, e)
            btn:SetParent(IBT.body)
            table.insert(IBT._trayBtns, btn)
        end
    end

    IBT.ApplyToggleSkin()
    IBT.Relayout()
end
