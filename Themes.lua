--[[
 Immersive Button Tray - theme layer
 Modern (flat, borderless-ish) or Classic (Blizzard tooltip border) skinning
 for the tray panel, the pinned strip and the individual buttons. Applied on
 every rebuild so newly-created buttons get themed too.
--]]

IBT = IBT or {}
ImmersiveButtonTrayDB = ImmersiveButtonTrayDB or {}

local STYLE = "modern"

local function normStyle(s)
    return (s == "classic") and "classic" or "modern"
end

function IBT.ResolveStyle()
    STYLE = normStyle(ImmersiveButtonTrayDB.style)
end

function IBT.CurrentStyle()
    return normStyle(ImmersiveButtonTrayDB.style)
end

-- pixel-perfect edge size, borrowed math from pfUI (MIT)
local pixelSize
local function GetPixel()
    if pixelSize then return pixelSize end
    local scale = tonumber(GetCVar("uiScale")) or 1
    local _, _, _, h = string.find(GetCVar("gxResolution") or "", "(.+)x(.+)")
    h = tonumber(h)
    pixelSize = h and (768 / h / scale) or 1
    if pixelSize > 1 then pixelSize = 1 end
    if pixelSize < 0.5 then pixelSize = pixelSize * 2 end
    return pixelSize
end

-- flat modern backdrop for a container (tray / pinned strip)
function IBT.ThemePanel(f, alpha)
    if not f then return end
    if STYLE == "classic" then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.09, 0.09, 0.09, alpha or 0.9)
        f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    else
        local px = GetPixel()
        f:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
            edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = px,
            insets = { left = -px, right = -px, top = -px, bottom = -px },
        })
        f:SetBackdropColor(0.06, 0.06, 0.06, alpha or 0.85)
        f:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
    end
end

-- theme a single entry button box; records the resting border colour and tints
-- the hover overlay so IBT.ButtonHoverOn/Off can accent it on mouseover
function IBT.ThemeButton(b)
    if not b then return end
    local bga = ImmersiveButtonTrayDB.bgAlpha or 0.9
    if STYLE == "classic" then
        b:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        b:SetBackdropColor(0.12, 0.12, 0.12, bga)
        b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        b._normBorder = { 0.5, 0.5, 0.5 }
        if b.hover then b.hover:SetVertexColor(1.0, 0.82, 0.0); b.hover:SetAlpha(0.09) end
    else
        local px = GetPixel()
        b:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
            edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = px,
            insets = { left = -px, right = -px, top = -px, bottom = -px },
        })
        b:SetBackdropColor(0.12, 0.12, 0.12, bga)
        b:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        b._normBorder = { 0.28, 0.28, 0.28 }
        if b.hover then b.hover:SetVertexColor(1.0, 0.82, 0.0); b.hover:SetAlpha(0.07) end
    end
end

-- crop an icon texture into a clean square (trim the default border)
function IBT.CropIcon(tex)
    if not tex then return end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- ---------------------------------------------------------------------------
-- theme switching
-- ---------------------------------------------------------------------------
StaticPopupDialogs["IMMERSIVEBUTTONTRAY_RELOAD"] = {
    text = "Theme changed. A UI reload makes it fully clean. Reload now?",
    button1 = "Reload", button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function IBT.SetTheme(s)
    ImmersiveButtonTrayDB.style = normStyle(s)
    IBT.ResolveStyle()
    if IBT.Rebuild then IBT.Rebuild() end
    StaticPopup_Show("IMMERSIVEBUTTONTRAY_RELOAD")
end
