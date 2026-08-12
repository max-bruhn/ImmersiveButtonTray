--[[
 Immersive Button Tray - core
 Text-only launcher dock. One set of shared layout/design/fade settings.
 Buttons belong to one of two strips: "hotlink" (always shown) or "tray"
 (folds away when idle). Hotlinks render first. SavedVariables are used
 directly (global), so the load-order gotcha does not apply.

 Minimap collection logic adapted from pfUI's addonbuttons (MIT, (c) Shagu).
--]]

IBT = IBT or {}
ImmersiveButtonTrayDB = ImmersiveButtonTrayDB or {}

local DEFAULTS = {
    style        = "modern",   -- modern | classic
    collectMinimap = true,
    buttonWidthMode = "fixed", -- fixed | dynamic
    buttonWidth  = 70,         -- width when fixed (long labels are cropped)
    anchorWidth  = 48,         -- width of the drag handle
    spacing      = 4,
    grow         = "down",     -- down | up
    trayAlign    = "center",   -- center | left | right (tray vs anchor)
    rowsize      = 8,          -- buttons per column before wrapping
    bgAlpha      = 0.9,        -- button background opacity (text is unaffected)
    fadeEnabled  = true,
    fadeDelay    = 4,
    fadeAlpha    = 0.1,        -- fade opacity (0 = fully hidden)
    locked       = true,
    nextId       = 1,
}

function IBT.InitDefaults()
    local db = ImmersiveButtonTrayDB
    local k, v

    -- migrate from the earlier per-group schema into shared globals
    if db.groups and db.groups.tray then
        local g = db.groups.tray
        local keys = { "grow", "rowsize", "spacing", "fadeEnabled", "fadeDelay", "fadeAlpha" }
        local i
        for i = 1, table.getn(keys) do
            local key = keys[i]
            if db[key] == nil and g[key] ~= nil then db[key] = g[key] end
        end
        if db.point == nil and g.point then db.point = g.point end
        db.groups = nil
    end

    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    if db.entries == nil then db.entries = {} end
    db.ignored = nil -- retired: it kept collected buttons stuck on the minimap
    if db.point == nil then db.point = db.togglePoint or { "CENTER", "UIParent", "CENTER", 0, -180 } end

    -- migrate entry.pinned -> entry.group
    local i
    for i = 1, table.getn(db.entries) do
        local e = db.entries[i]
        if e.group == nil then e.group = e.pinned and "hotlink" or "tray" end
    end
end

function IBT.EntryGroup(e)
    return e.group or (e.pinned and "hotlink") or "tray"
end

function IBT.SetEntryGroup(e, g)
    e.group = g
    e.pinned = (g == "hotlink") and true or nil
end

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------
function IBT.Trim(s)
    if not s then return "" end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function IBT.SafeName(id)
    return (string.gsub(id, "[^%w]", ""))
end

-- ---------------------------------------------------------------------------
-- command runner: dispatch a slash line through SlashCmdList
-- ---------------------------------------------------------------------------
function IBT.RunLine(line)
    line = IBT.Trim(line)
    if line == "" then return end
    if string.sub(line, 1, 1) ~= "/" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccIBT|r: commands must start with '/' (" .. line .. ")")
        return
    end
    local sp = string.find(line, "%s")
    local cmd = sp and string.sub(line, 1, sp - 1) or line
    local args = sp and string.sub(line, sp + 1) or ""
    local lcmd = string.lower(cmd)

    local key, func
    for key, func in pairs(SlashCmdList) do
        local i = 1
        while true do
            local g = getglobal("SLASH_" .. key .. i)
            if not g then break end
            if string.lower(g) == lcmd then
                pcall(func, args)
                return
            end
            i = i + 1
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccIBT|r: unknown command " .. cmd)
end

function IBT.RunCommand(text)
    if not text or text == "" then return end
    local start, len = 1, string.len(text)
    while start <= len do
        local nl = string.find(text, "\n", start, true)
        local line = nl and string.sub(text, start, nl - 1) or string.sub(text, start)
        IBT.RunLine(line)
        if not nl then break end
        start = nl + 1
    end
end

-- ---------------------------------------------------------------------------
-- entry bookkeeping
-- ---------------------------------------------------------------------------
function IBT.FindEntry(id)
    local list = ImmersiveButtonTrayDB.entries
    local i
    for i = 1, table.getn(list) do
        if list[i].id == id then return list[i], i end
    end
    return nil
end

function IBT.MaxOrder()
    local list = ImmersiveButtonTrayDB.entries
    local m, i = 0
    for i = 1, table.getn(list) do
        if (list[i].order or 0) > m then m = list[i].order end
    end
    return m
end

function IBT.OrderedEntries()
    local list = ImmersiveButtonTrayDB.entries
    local out, i = {}, nil
    for i = 1, table.getn(list) do out[i] = list[i] end
    local a, b
    for a = 2, table.getn(out) do
        local cur = out[a]
        b = a - 1
        while b >= 1 and (out[b].order or 0) > (cur.order or 0) do
            out[b + 1] = out[b]
            b = b - 1
        end
        out[b + 1] = cur
    end
    return out
end

-- hotlinks (by order) then tray (by order)
function IBT.DisplayEntries()
    local ordered = IBT.OrderedEntries()
    local hot, tray, i = {}, {}, nil
    for i = 1, table.getn(ordered) do
        local e = ordered[i]
        if IBT.EntryGroup(e) == "hotlink" then table.insert(hot, e) else table.insert(tray, e) end
    end
    return hot, tray
end

-- reorder within the same group only
function IBT.MoveEntry(id, dir)
    local e = IBT.FindEntry(id)
    if not e then return end
    local grp = IBT.EntryGroup(e)
    local ordered = IBT.OrderedEntries()
    local sub, i = {}, nil
    for i = 1, table.getn(ordered) do
        if IBT.EntryGroup(ordered[i]) == grp then table.insert(sub, ordered[i]) end
    end
    local pos
    for i = 1, table.getn(sub) do if sub[i].id == id then pos = i end end
    if not pos then return end
    local swap = pos + dir
    if swap < 1 or swap > table.getn(sub) then return end
    local a, b = sub[pos], sub[swap]
    local t = a.order; a.order = b.order; b.order = t
end

function IBT.AddCommandEntry()
    local db = ImmersiveButtonTrayDB
    local id = "cmd" .. db.nextId
    db.nextId = db.nextId + 1
    local e = { kind = "command", id = id, label = "New button", group = "tray", order = IBT.MaxOrder() + 1, command = "" }
    table.insert(db.entries, e)
    return e
end

function IBT.AddMinimapEntry(name)
    local e = { kind = "minimap", id = name, label = IBT.DeriveLabel(name), group = "tray", order = IBT.MaxOrder() + 1 }
    table.insert(ImmersiveButtonTrayDB.entries, e)
    return e
end

function IBT.DeleteEntry(id)
    local e, idx = IBT.FindEntry(id)
    if not e then return end
    if e.kind == "minimap" and IBT.RestoreMinimapButton then IBT.RestoreMinimapButton(id) end
    table.remove(ImmersiveButtonTrayDB.entries, idx)
end

function IBT.ToggleHidden(id)
    local e = IBT.FindEntry(id)
    if not e then return end
    e.hidden = not e.hidden
    if e.hidden and IBT.RestoreMinimapButton then IBT.RestoreMinimapButton(id) end
end

-- ---------------------------------------------------------------------------
-- minimap scanner (adapted from pfUI addonbuttons, MIT)
-- ---------------------------------------------------------------------------
local IGNORED = {
    "Note", "JQuest", "Naut_", "MinimapIcon", "GatherMatePin", "WestPointer",
    "Chinchilla_", "SmartMinimapZoom", "QuestieNote", "smm", "pfMiniMapPin",
    "MiniMapBattlefieldFrame", "pfMinimapButton", "GatherNote", "MiniNotePOI",
    "FWGMinimapPOI", "RecipeRadarMinimapIcon", "MiniMapTracking", "CartographerNotesPOI",
    "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "MiniMapMailFrame",
    "MiniMapMailBorder", "GameTimeFrame", "MiniMapTrackingButton", "MiniMapTrackingFrame",
    "MinimapBackdrop", "MinimapCluster", "TimeManagerClockButton", "MiniMapLFGFrame",
    "MiniMapVoiceChatFrame", "BattlefieldMinimap",
    "IBTToggle", "IBTBody", "IBTButton",
}

local function partialIgnored(name)
    local n = string.lower(name)
    local i
    for i = 1, table.getn(IGNORED) do
        local s = string.find(n, string.lower(IGNORED[i]), 1, true)
        if s == 1 then return true end
    end
    return false
end

function IBT.IsButtonValid(frame)
    if not frame or not frame.GetName or not frame:GetName() then return false end
    if not frame:IsVisible() then return false end
    if frame:GetHeight() > 40 or frame:GetWidth() > 40 then return false end
    if not frame:IsFrameType("Button") and not frame:IsFrameType("Frame") then return false end
    if partialIgnored(frame:GetName()) then return false end

    if frame:IsFrameType("Button") then
        if frame:GetScript("OnClick") or frame:GetScript("OnMouseDown") or frame:GetScript("OnMouseUp") then
            return true
        end
    elseif frame:IsFrameType("Frame") then
        local ln = string.lower(frame:GetName())
        if string.find(ln, "icon") or string.find(ln, "button") then
            if frame:GetScript("OnMouseDown") or frame:GetScript("OnMouseUp") then return true end
        end
    end
    return false
end

function IBT.ScanMinimap()
    local found = {}
    local function scan(parent)
        if not parent or not parent.GetChildren then return end
        local kids = { parent:GetChildren() }
        local i
        for i = 1, table.getn(kids) do
            local c = kids[i]
            if IBT.IsButtonValid(c) then
                found[c:GetName()] = true
            elseif c and c.GetNumChildren and c:GetNumChildren() > 0 then
                local gk = { c:GetChildren() }
                local j
                for j = 1, table.getn(gk) do
                    if IBT.IsButtonValid(gk[j]) then found[gk[j]:GetName()] = true end
                end
            end
        end
    end
    scan(Minimap)
    scan(MinimapBackdrop)
    return found
end

function IBT.SyncMinimapEntries()
    if not ImmersiveButtonTrayDB.collectMinimap then return end
    local found = IBT.ScanMinimap()
    local name
    for name in pairs(found) do
        if not IBT.FindEntry(name) then IBT.AddMinimapEntry(name) end
    end
end

function IBT.DeriveLabel(name)
    local s = name
    s = string.gsub(s, "LibDBIcon10_", "")
    s = string.gsub(s, "MinimapButton", "")
    s = string.gsub(s, "MiniMapButton", "")
    s = string.gsub(s, "Minimap", "")
    s = string.gsub(s, "MiniMap", "")
    s = string.gsub(s, "Button", "")
    s = string.gsub(s, "Frame", "")
    s = string.gsub(s, "Icon", "")
    s = IBT.Trim(s)
    if s == "" then s = name end
    return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

-- ---------------------------------------------------------------------------
-- lifecycle
-- ---------------------------------------------------------------------------
IBT.built = false
function IBT.BuildAll()
    if IBT.built then return end
    IBT.built = true
    if IBT.ResolveStyle then IBT.ResolveStyle() end
    if IBT.BuildFrames then IBT.BuildFrames() end
    if IBT.BuildOptions then IBT.BuildOptions() end
    IBT.SyncMinimapEntries()
    if IBT.Rebuild then IBT.Rebuild() end
    if IBT.ApplyLock then IBT.ApplyLock() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        IBT.InitDefaults()
    elseif event == "PLAYER_ENTERING_WORLD" then
        IBT.InitDefaults()
        local waited, rescan = 0, 0
        local driver = CreateFrame("Frame")
        driver:SetScript("OnUpdate", function()
            waited = waited + arg1
            if not IBT.built then
                if waited < 0.6 then return end
                IBT.BuildAll()
                return
            end
            rescan = rescan + arg1
            if rescan < 5 then return end
            rescan = 0
            local before = table.getn(ImmersiveButtonTrayDB.entries)
            IBT.SyncMinimapEntries()
            if table.getn(ImmersiveButtonTrayDB.entries) ~= before and IBT.Rebuild then
                IBT.Rebuild()
            elseif IBT.ReapplyMinimap then
                IBT.ReapplyMinimap()
            end
        end)
    end
end)

SLASH_IMMERSIVEBUTTONTRAY1 = "/ibt"
SlashCmdList["IMMERSIVEBUTTONTRAY"] = function(msg)
    msg = string.lower(IBT.Trim(msg or ""))
    if msg == "lock" then
        ImmersiveButtonTrayDB.locked = true
        if IBT.ApplyLock then IBT.ApplyLock() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccIBT|r: locked.")
    elseif msg == "unlock" then
        ImmersiveButtonTrayDB.locked = false
        if IBT.ApplyLock then IBT.ApplyLock() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccIBT|r: unlocked - drag the handle to move the dock, then /ibt lock.")
    else
        if IBT.OpenOptions then IBT.OpenOptions() end
    end
end
