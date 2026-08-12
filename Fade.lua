--[[
 Immersive Button Tray - immersive fade
 Hover the handle or body to un-fade (alpha to full); after the fade delay with
 no cursor over either, the dock fades to the configured opacity and the tray
 folds. Hover only affects the fade and holds the tray open - it never opens it;
 the tray is opened by clicking the handle. MouseIsOver is geometric, so the
 hover zone stays live even at alpha 0.
--]]

IBT = IBT or {}

local FADE_DUR = 0.4  -- fixed fade animation length

local cur = 1
local rest = 0
local started

local function FadeTarget()
    local db = ImmersiveButtonTrayDB
    if not db.fadeEnabled then return 1 end
    return db.fadeAlpha or 0.1
end

local function Hovering()
    if IBT.toggle and IBT.toggle:IsShown() and MouseIsOver(IBT.toggle) then return true end
    if IBT.body and IBT.body:IsShown() and MouseIsOver(IBT.body) then return true end
    return false
end

function IBT.ApplyFade() end

function IBT.StartFadeTicker()
    if started then return end
    started = true
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function()
        local db = ImmersiveButtonTrayDB
        if not db or not IBT.toggle then return end
        if not IBT.toggle:IsShown() then IBT.toggle:Show() end

        local hovering = Hovering()
        local target
        if not db.fadeEnabled then
            target = 1; rest = 0
        elseif hovering then
            target = 1; rest = 0            -- keep bright + hold the tray open
        elseif rest < (db.fadeDelay or 4) then
            rest = rest + arg1; target = 1  -- grace period
        else
            target = FadeTarget()           -- idle: fade out and fold
            IBT.SetExpanded(false)
        end

        if cur ~= target then
            local step = (FADE_DUR > 0) and (arg1 / FADE_DUR) or 1
            if cur < target then
                cur = cur + step; if cur > target then cur = target end
            else
                cur = cur - step; if cur < target then cur = target end
            end
            local a = cur
            if a < 0 then a = 0 elseif a > 1 then a = 1 end
            IBT.toggle:SetAlpha(a)
            if IBT.body then IBT.body:SetAlpha(a) end
        end
    end)
end
