--[[
 Immersive Button Tray - options panel (tabbed, text-only)
 "Look & Feel" holds every shared layout/design/fade control. "Tray Setup" is
 just the button population list: assign each button to the Hotlinks or Tray
 strip, rename, set a command, sort, hide/delete. Open with /ibt.
--]]

IBT = IBT or {}
ImmersiveButtonTrayDB = ImmersiveButtonTrayDB or {}

local ROWS, ROW_H = 8, 30

-- ---------------------------------------------------------------------------
-- widget helpers
-- ---------------------------------------------------------------------------
local function Flat(f, r, g, b, a)
    f:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false,
        edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
        insets = { left = -1, right = -1, top = -1, bottom = -1 },
    })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
end

local function Btn(parent, w, h, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(h or 18)
    Flat(b, 0.14, 0.14, 0.14, 0.9)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints(b); fs:SetText(text)
    b.label = fs
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function() if not this.active then this:SetBackdropColor(0.22, 0.22, 0.22, 0.9) end end)
    b:SetScript("OnLeave", function() if not this.active then this:SetBackdropColor(0.14, 0.14, 0.14, 0.9) end end)
    return b
end

local function SetActive(b, on)
    if not b then return end
    b.active = on
    b:SetBackdropColor(on and 0.28 or 0.14, on and 0.28 or 0.14, on and 0.28 or 0.14, 0.9)
    b:SetBackdropBorderColor(on and 0.2 or 0.25, on and 0.9 or 0.25, on and 0.8 or 0.25, 1)
end

-- a small up/down arrow button (text caret, reliably rendered by the font);
-- the "v" is nudged up so both carets look vertically centred
local function ArrowBtn(parent, down, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(18); b:SetHeight(18)
    Flat(b, 0.14, 0.14, 0.14, 0.9)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", b, "CENTER", 0, down and 3 or 0)
    fs:SetText(down and "v" or "^")
    fs:SetTextColor(0.9, 0.9, 0.9)
    b.label = fs
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function() this:SetBackdropColor(0.22, 0.22, 0.22, 0.9) end)
    b:SetScript("OnLeave", function() this:SetBackdropColor(0.14, 0.14, 0.14, 0.9) end)
    return b
end

local function Check(parent, label, x, y, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetWidth(20); c:SetHeight(20)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local t = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetPoint("LEFT", c, "RIGHT", 2, 0); t:SetText(label)
    c:SetChecked(get() and 1 or nil)
    c:SetScript("OnClick", function()
        set(this:GetChecked() and true or false)
        if IBT.Rebuild then IBT.Rebuild() end
    end)
    return c
end

local function Slider(parent, name, label, x, y, lo, hi, step, get, set)
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetWidth(150); s:SetHeight(15)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetMinMaxValues(lo, hi); s:SetValueStep(step)
    getglobal(name .. "Low"):SetText(""); getglobal(name .. "High"):SetText("")
    getglobal(name .. "Text"):SetText(label)
    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    val:SetPoint("LEFT", s, "RIGHT", 8, 0)
    local function fmt(v)
        if step >= 1 then return tostring(math.floor(v + 0.5)) end
        return string.format("%.2f", v)
    end
    s:SetValue(get()); val:SetText(fmt(get()))
    s:SetScript("OnValueChanged", function()
        local v = this:GetValue()
        if step >= 1 then v = math.floor(v + 0.5) else v = math.floor(v * 100 + 0.5) / 100 end
        set(v); val:SetText(fmt(v))
        if IBT.Rebuild then IBT.Rebuild() end
    end)
    return s
end

-- ---------------------------------------------------------------------------
-- popups
-- ---------------------------------------------------------------------------
StaticPopupDialogs["IBT_RENAME"] = {
    text = "Button label:",
    button1 = "Set", button2 = "Cancel", hasEditBox = 1, maxLetters = 40,
    OnShow = function()
        getglobal(this:GetName() .. "EditBox"):SetText((IBT._editEntry and IBT._editEntry.label) or "")
        getglobal(this:GetName() .. "EditBox"):HighlightText()
    end,
    OnAccept = function()
        local eb = getglobal(this:GetParent():GetName() .. "EditBox")
        if IBT._editEntry then IBT._editEntry.label = eb:GetText() end
        if IBT.Rebuild then IBT.Rebuild() end
        if IBT.RefreshList then IBT.RefreshList() end
    end,
    EditBoxOnEnterPressed = function()
        local eb = getglobal(this:GetParent():GetName() .. "EditBox")
        if IBT._editEntry then IBT._editEntry.label = eb:GetText() end
        this:GetParent():Hide()
        if IBT.Rebuild then IBT.Rebuild() end
        if IBT.RefreshList then IBT.RefreshList() end
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

StaticPopupDialogs["IBT_COMMAND"] = {
    text = "Command to run (e.g. /luna menu):",
    button1 = "Set", button2 = "Cancel", hasEditBox = 1, maxLetters = 240,
    OnShow = function()
        getglobal(this:GetName() .. "EditBox"):SetText((IBT._editEntry and IBT._editEntry.command) or "")
    end,
    OnAccept = function()
        local eb = getglobal(this:GetParent():GetName() .. "EditBox")
        if IBT._editEntry then IBT._editEntry.command = eb:GetText() end
        if IBT.Rebuild then IBT.Rebuild() end
        if IBT.RefreshList then IBT.RefreshList() end
    end,
    EditBoxOnEnterPressed = function()
        local eb = getglobal(this:GetParent():GetName() .. "EditBox")
        if IBT._editEntry then IBT._editEntry.command = eb:GetText() end
        this:GetParent():Hide()
        if IBT.Rebuild then IBT.Rebuild() end
        if IBT.RefreshList then IBT.RefreshList() end
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

-- ---------------------------------------------------------------------------
-- entry list rows
-- ---------------------------------------------------------------------------
local function MakeRow(parent, index)
    local r = CreateFrame("Frame", nil, parent)
    r:SetWidth(360); r:SetHeight(ROW_H - 4)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)

    r.up = ArrowBtn(r, false, function() IBT.MoveEntry(r.entry.id, -1); IBT.Rebuild(); IBT.RefreshList() end)
    r.up:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.down = ArrowBtn(r, true, function() IBT.MoveEntry(r.entry.id, 1); IBT.Rebuild(); IBT.RefreshList() end)
    r.down:SetPoint("LEFT", r.up, "RIGHT", 3, 0)

    r.grp = Btn(r, 38, 18, "Tray", function()
        local g = IBT.EntryGroup(r.entry)
        IBT.SetEntryGroup(r.entry, (g == "hotlink") and "tray" or "hotlink")
        IBT.Rebuild(); IBT.RefreshList()
    end)
    r.grp:SetPoint("LEFT", r.down, "RIGHT", 8, 0)

    r.name = Btn(r, 150, 18, "", function() IBT._editEntry = r.entry; StaticPopup_Show("IBT_RENAME") end)
    r.name:SetPoint("LEFT", r.grp, "RIGHT", 10, 0)
    r.name.label:SetJustifyH("LEFT")

    r.cmd = Btn(r, 40, 18, "Cmd", function() IBT._editEntry = r.entry; StaticPopup_Show("IBT_COMMAND") end)
    r.cmd:SetPoint("LEFT", r.name, "RIGHT", 8, 0)

    r.del = Btn(r, 36, 18, "Del", function()
        if r.entry.kind == "command" then IBT.DeleteEntry(r.entry.id) else IBT.ToggleHidden(r.entry.id) end
        IBT.Rebuild(); IBT.RefreshList()
    end)
    r.del:SetPoint("LEFT", r.cmd, "RIGHT", 8, 0)

    return r
end

local function FillRow(r, entry)
    r.entry = entry
    local hidden = entry.hidden and true or false
    local grp = IBT.EntryGroup(entry)

    r.grp.label:SetText(grp == "hotlink" and "Hot" or "Tray")
    SetActive(r.grp, grp == "hotlink")

    local dim = hidden and 0.4 or 1
    r.up:SetAlpha(dim); r.down:SetAlpha(dim); r.grp:SetAlpha(dim); r.name:SetAlpha(dim); r.cmd:SetAlpha(dim)

    if hidden then
        r.name.label:SetText("|cff666666" .. (entry.label or entry.id) .. "  (hidden)|r")
    else
        local tag = (entry.kind == "minimap") and "|cff8888ff" or "|cffffd200"
        r.name.label:SetText(tag .. (entry.label or entry.id) .. "|r")
    end

    if entry.kind == "command" then
        r.cmd:Show(); r.del.label:SetText("Del"); SetActive(r.del, false)
    else
        r.cmd:Hide(); r.del.label:SetText("Hide"); SetActive(r.del, hidden)
    end
    r.del:SetAlpha(1)
end

function IBT.RefreshList()
    if not IBT.optScroll then return end
    local hot, tray = IBT.DisplayEntries()
    local entries, i = {}, nil
    for i = 1, table.getn(hot) do table.insert(entries, hot[i]) end
    for i = 1, table.getn(tray) do table.insert(entries, tray[i]) end
    local n = table.getn(entries)
    FauxScrollFrame_Update(IBT.optScroll, n, ROWS, ROW_H)
    local offset = FauxScrollFrame_GetOffset(IBT.optScroll)
    for i = 1, ROWS do
        local r = IBT.optRows[i]
        local idx = i + offset
        if idx <= n then FillRow(r, entries[idx]); r:Show() else r:Hide() end
    end
end

-- ---------------------------------------------------------------------------
-- tabs
-- ---------------------------------------------------------------------------
function IBT.ShowTab(name)
    IBT._tab = name
    if IBT.tabLook then if name == "look" then IBT.tabLook:Show() else IBT.tabLook:Hide() end end
    if IBT.tabSetup then if name == "setup" then IBT.tabSetup:Show() else IBT.tabSetup:Hide() end end
    SetActive(IBT.tabLookBtn, name == "look")
    SetActive(IBT.tabSetupBtn, name == "setup")
    if name == "setup" then IBT.RefreshList() end
end

-- ---------------------------------------------------------------------------
-- build
-- ---------------------------------------------------------------------------
function IBT.BuildOptions()
    if IBT.optPanel then return end
    local db = ImmersiveButtonTrayDB

    local p = CreateFrame("Frame", "IBTOptions", UIParent)
    p:SetWidth(400); p:SetHeight(470)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:SetFrameStrata("DIALOG")
    Flat(p, 0.05, 0.05, 0.05, 0.96)
    p:SetMovable(true); p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", function() this:StartMoving() end)
    p:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    p:Hide()
    IBT.optPanel = p

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", p, "TOP", 0, -8)
    title:SetText("|cff33ffcci|r|cffffd200BT|r  Immersive ButtonTray")

    local close = Btn(p, 18, 18, "x", function() p:Hide() end)
    close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)

    IBT.tabLookBtn = Btn(p, 120, 20, "Look & Feel", function() IBT.ShowTab("look") end)
    IBT.tabLookBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -26)
    IBT.tabSetupBtn = Btn(p, 120, 20, "Tray Setup", function() IBT.ShowTab("setup") end)
    IBT.tabSetupBtn:SetPoint("LEFT", IBT.tabLookBtn, "RIGHT", 6, 0)

    local look = CreateFrame("Frame", nil, p); look:SetAllPoints(p); IBT.tabLook = look
    local setup = CreateFrame("Frame", nil, p); setup:SetAllPoints(p); IBT.tabSetup = setup

    -- ===================== LOOK & FEEL =====================
    -- LEFT COLUMN: theme + layout, top to bottom
    local mBtn, cBtn
    mBtn = Btn(look, 72, 18, "Modern", function() IBT.SetTheme("modern"); SetActive(mBtn, true); SetActive(cBtn, false) end)
    mBtn:SetPoint("TOPLEFT", look, "TOPLEFT", 20, -56)
    cBtn = Btn(look, 72, 18, "Classic", function() IBT.SetTheme("classic"); SetActive(cBtn, true); SetActive(mBtn, false) end)
    cBtn:SetPoint("LEFT", mBtn, "RIGHT", 6, 0)
    SetActive(mBtn, IBT.CurrentStyle() == "modern")
    SetActive(cBtn, IBT.CurrentStyle() == "classic")

    local growBtn
    growBtn = Btn(look, 150, 18, "Grow: " .. db.grow, function()
        db.grow = (db.grow == "down") and "up" or "down"
        this.label:SetText("Grow: " .. db.grow); IBT.Rebuild()
    end)
    growBtn:SetPoint("TOPLEFT", look, "TOPLEFT", 20, -84)

    local alignBtn
    alignBtn = Btn(look, 150, 18, "Tray align: " .. db.trayAlign, function()
        if db.trayAlign == "center" then db.trayAlign = "left"
        elseif db.trayAlign == "left" then db.trayAlign = "right"
        else db.trayAlign = "center" end
        this.label:SetText("Tray align: " .. db.trayAlign); IBT.Relayout()
    end)
    alignBtn:SetPoint("TOPLEFT", look, "TOPLEFT", 20, -110)

    local wBtn = Btn(look, 150, 18, "Width: " .. db.buttonWidthMode, function()
        db.buttonWidthMode = (db.buttonWidthMode == "fixed") and "dynamic" or "fixed"
        this.label:SetText("Width: " .. db.buttonWidthMode); IBT.Rebuild()
    end)
    wBtn:SetPoint("TOPLEFT", look, "TOPLEFT", 20, -136)

    Slider(look, "IBTBtnWidth", "Button width", 20, -170, 20, 200, 1,
        function() return db.buttonWidth end, function(v) db.buttonWidth = v end)
    Slider(look, "IBTAnchorW", "Anchor width", 20, -198, 20, 160, 1,
        function() return db.anchorWidth end, function(v) db.anchorWidth = v end)
    Slider(look, "IBTSpacing", "Spacing", 20, -226, 0, 12, 1,
        function() return db.spacing end, function(v) db.spacing = v end)
    Slider(look, "IBTRows", "Per column", 20, -254, 1, 16, 1,
        function() return db.rowsize end, function(v) db.rowsize = v end)

    -- RIGHT COLUMN: opacity, fade, system
    Slider(look, "IBTBgAlpha", "Background opacity", 210, -66, 0, 1, 0.05,
        function() return db.bgAlpha end, function(v) db.bgAlpha = v end)
    Check(look, "Enable fade", 210, -96, function() return db.fadeEnabled end, function(v) db.fadeEnabled = v end)
    Slider(look, "IBTAlpha", "Fade opacity", 210, -132, 0, 1, 0.05,
        function() return db.fadeAlpha end, function(v) db.fadeAlpha = v end)
    Slider(look, "IBTDelay", "Fade delay (s)", 210, -160, 1, 15, 1,
        function() return db.fadeDelay end, function(v) db.fadeDelay = v end)
    Check(look, "Collect minimap buttons", 210, -190,
        function() return db.collectMinimap end,
        function(v) db.collectMinimap = v; if v then IBT.SyncMinimapEntries() end end)

    local lockBtn
    lockBtn = Btn(look, 150, 18, db.locked and "Unlock frames" or "Lock frames", function()
        db.locked = not db.locked
        this.label:SetText(db.locked and "Unlock frames" or "Lock frames"); IBT.ApplyLock()
    end)
    lockBtn:SetPoint("TOPLEFT", look, "TOPLEFT", 210, -216)

    local resetBtn = Btn(look, 150, 18, "Reset anchor to centre", function() IBT.ResetAnchor() end)
    resetBtn:SetPoint("TOPLEFT", look, "TOPLEFT", 210, -242)

    -- ===================== TRAY SETUP =====================
    local legend = setup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("TOPLEFT", setup, "TOPLEFT", 14, -54)
    legend:SetWidth(372); legend:SetJustifyH("LEFT"); legend:SetSpacing(3)
    legend:SetText("|cffffd200Tray / Hot|r|cffaaaaaa  -  Foldable tray, or a permanent Hotlink\n" ..
        "|r|cffffd200Arrows|r|cffaaaaaa  -  Reorder the button\n" ..
        "|r|cffffd200Name|r|cffaaaaaa  -  Click to rename\n" ..
        "|r|cffffd200Cmd|r|cffaaaaaa  -  Set the slash command it runs\n" ..
        "|r|cffffd200Hide|r|cffaaaaaa  -  Return a collected button to the minimap\n" ..
        "|r|cffffd200Del|r|cffaaaaaa  -  Delete a custom button|r")

    local listBG = CreateFrame("Frame", nil, setup)
    listBG:SetPoint("TOPLEFT", setup, "TOPLEFT", 14, -160)
    listBG:SetWidth(372); listBG:SetHeight(ROWS * ROW_H + 6)
    Flat(listBG, 0.03, 0.03, 0.03, 0.9)

    local holder = CreateFrame("Frame", nil, listBG)
    holder:SetPoint("TOPLEFT", listBG, "TOPLEFT", 6, -4)
    holder:SetWidth(360); holder:SetHeight(ROWS * ROW_H)

    IBT.optRows = {}
    local i
    for i = 1, ROWS do IBT.optRows[i] = MakeRow(holder, i) end

    local scroll = CreateFrame("ScrollFrame", "IBTOptionsScroll", listBG, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listBG, "TOPLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", listBG, "BOTTOMRIGHT", -24, 2)
    scroll:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(ROW_H, IBT.RefreshList) end)
    IBT.optScroll = scroll

    local addBtn = Btn(setup, 200, 20, "+ Add custom command button", function()
        local e = IBT.AddCommandEntry()
        IBT.Rebuild(); IBT.RefreshList()
        IBT._editEntry = e; StaticPopup_Show("IBT_RENAME")
    end)
    addBtn:SetPoint("TOPLEFT", listBG, "BOTTOMLEFT", 0, -8)

    -- footer
    local note = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 12)
    note:SetText("|cff888888Type |r|cff33ffcc/ibt|r|cff888888 to open this menu.|r")
    local ver = GetAddOnMetadata and GetAddOnMetadata("ImmersiveButtonTray", "Version")
    local vt = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    vt:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -10, 12)
    vt:SetText("|cff555555v" .. (ver or "0.1.0") .. "|r")

    IBT.ShowTab("look")
end

function IBT.OpenOptions()
    if not IBT.optPanel then return end
    if IBT.optPanel:IsVisible() then
        IBT.optPanel:Hide()
    else
        IBT.ShowTab(IBT._tab or "look")
        IBT.optPanel:Show()
    end
end
