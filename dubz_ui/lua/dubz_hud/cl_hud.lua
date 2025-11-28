------------------------------------------
-- Utility
------------------------------------------
local function L(val, to, spd)
    return Lerp(FrameTime() * (spd or 8), val, to)
end

-- Smooth interpolation helper
local function SmoothTo(current, target, speed)
    return Lerp(FrameTime() * (speed or 8), current or 0, target or 0)
end

function Dubz_UpdateLawsPanelPosition()
    if not IsValid(lawPanel) then return end

    local votes = table.Count(VotePanels)
    local base = 120      -- where laws normally sit
    local offset = votes * 110

    lawPanel:SetPos(
        ScrW() - lawPanel:GetWide() - 20,
        base + offset
    )
end

------------------------------------------
-- Hide Default HUD Elements
------------------------------------------
hook.Add("HUDShouldDraw","Dubz_HideDefault", function(name)
    local hide = {
        ["DarkRP_HUD"]=true, ["DarkRP_EntityDisplay"]=true, ["DarkRP_ZombieInfo"]=true,
        ["DarkRP_LocalPlayerHUD"]=true, ["CHudHealth"]=true, ["CHudBattery"]=true,
        ["CHudAmmo"]=true, ["CHudSecondaryAmmo"]=true, ["DarkRP_Hungermod"]=true,
        ["DarkRP_LocalPlayerHunger"]=true, ["DarkRP_Energy"]=true
    }
    if hide[name] then return false end
end)


------------------------------------------
-- Payday Tracking / Info (Fixed)
------------------------------------------
local paydayJustHappened = false

local function paydayInfo(ply)
    local delay = (GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.paydelay) or 300

    -- Initialize client-side payday timer if missing
    ply._DubzNextPay = ply._DubzNextPay or (CurTime() + delay)

    local remaining = math.max(0, ply._DubzNextPay - CurTime())

    -- When countdown finishes, mark payday as "just happened" and reset the timer
    if remaining <= 0 then
        paydayJustHappened = true
        ply._DubzNextPay = CurTime() + delay
        remaining = delay
    end

    local progress = 1 - (remaining / delay)
    progress = math.Clamp(progress, 0, 1)

    local salary = (ply.getDarkRPVar and ply:getDarkRPVar("salary")) or ply._DubzSalary or 0

    return progress, salary, remaining, delay
end

hook.Add("playerPaidSalary","DubzHUD_PaydayAlign", function(ply, amount)
    if ply ~= LocalPlayer() then return end
    local delay = (GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.paydelay) or 300

    -- Align local timer with real payday event
    ply._DubzNextPay = CurTime() + delay
    ply._DubzSalary = amount or ((ply.getDarkRPVar and ply:getDarkRPVar("salary")) or 0)

    -- Wallet animation start values
    local currentMoney = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or ply._DubzWalletSmooth or 0
    ply._DubzWalletAnimFrom = currentMoney
    ply._DubzWalletAnimTo = currentMoney + (amount or 0)
    ply._DubzWalletAnimStart = CurTime()
    ply._DubzWalletAnimDur = (Dubz and Dubz.Config and Dubz.Config.HUD and Dubz.Config.HUD.Payday and Dubz.Config.HUD.Payday.AnimateWalletTime) or 0.6

    -- Sound (keep original behavior)
    surface.PlaySound((Dubz and Dubz.Config and Dubz.Config.HUD and Dubz.Config.HUD.Payday and Dubz.Config.HUD.Payday.Sound) or "items/suitchargeok1.wav")
end)

hook.Add("InitPostEntity","DubzHUD_PaydayInit", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local delay = (GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.paydelay) or 300
    ply._DubzNextPay = CurTime() + delay
end)


------------------------------------------
-- Format Money
------------------------------------------
local function formatMoney(n)
    local v = math.floor(tonumber(n) or 0)
    if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(v) end
    return "$"..tostring(v)
end


------------------------------------------
-- 💸 Dollar Sign Particle System (SAFE)
------------------------------------------
local PaydayPops = {}
local MAX_POP = 25
local POP_LIFE = 1.25

surface.CreateFont("DubzHUD_PayPop", {
    font = "Arial",
    size = 22,
    weight = 900
})

local function SpawnDollarPop(x, y)
    if not x or not y then return end
    if #PaydayPops >= MAX_POP then return end

    PaydayPops[#PaydayPops + 1] = {
        x      = x + math.Rand(-16, 16),
        y      = y + math.Rand(-8, 8),
        vel    = math.Rand(26, 45),
        born   = CurTime(),
        drift  = math.Rand(-12, 12),
    }
end

local function DrawPaydayPops()
    local now = CurTime()

    for i = #PaydayPops, 1, -1 do
        local p = PaydayPops[i]
        if not p then
            table.remove(PaydayPops, i)
            continue
        end

        local life = (now - p.born) / POP_LIFE
        if life >= 1 then
            table.remove(PaydayPops, i)
            continue
        end

        local alpha = 255 * (1 - life)
        p.y = p.y - (FrameTime() * p.vel)
        p.x = p.x + FrameTime() * p.drift

        draw.SimpleText(
            "$",
            "DubzHUD_PayPop",
            p.x,
            p.y,
            Color(60,255,90,alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end
end


------------------------------------------
-- Payday Bar Color + Text Fade
------------------------------------------
local function PaydayColor(t)
    t = math.Clamp(t or 0, 0, 1)
    if t < 0.5 then
        local k = t / 0.5
        return Color(
            Lerp(k, 255, 255), -- R stays 255
            Lerp(k, 60, 255),  -- G: 60 → 255
            60,
            230
        )
    else
        local k = (t - 0.5) / 0.5
        return Color(
            Lerp(k, 255, 60),  -- R: 255 → 60
            Lerp(k, 255, 255), -- G stays 255
            60,
            230
        )
    end
end

local function PaydayTextColor(progress)
    progress = math.Clamp(progress or 0, 0, 1)
    local shade = Lerp(progress, 255, 0) -- 255 → 0
    return Color(shade, shade, shade, 255)
end


------------------------------------------
-- HUD PAINT
------------------------------------------
hook.Add("HUDPaint","Dubz_ModernHUD", function()
    if not Dubz or not Dubz.Config or not Dubz.Config.HUD or not Dubz.Config.HUD.Enabled then return end
    local cfg = Dubz.Config.HUD
    local ply = LocalPlayer(); if not IsValid(ply) then return end

    local accent = Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(37,150,190)
    local x = cfg.Margin or 20
    local h = cfg.Height or 148
    local w = cfg.Width or 420
    local y = ScrH() - h - (cfg.Margin or 20)

    ------------------------------------------
    -- Agenda (top-left)
    ------------------------------------------
    local topMargin = cfg.Margin or 20
    local agendaText = (ply.getDarkRPVar and ply:getDarkRPVar("agenda")) or ""
    if agendaText ~= "" then
        local agendaW, agendaH = 260, 84
        Dubz.DrawBubble(x, topMargin, agendaW, agendaH, Color(20,20,20,200))
        local agendaTbl = ply.getAgendaTable and ply:getAgendaTable()
        local agendaTitle = (agendaTbl and agendaTbl.Title) or "Agenda"
        draw.SimpleText(agendaTitle, "DubzHUD_Small", x + 12, topMargin + 8, Color(255,255,255))
        draw.DrawText(agendaText, "DubzHUD_Small", x + 12, topMargin + 28, Color(220,220,220), TEXT_ALIGN_LEFT)
    end

    ------------------------------------------
    -- Announcement (top-center)
    ------------------------------------------
    local announcement = ""
    if DarkRP and DarkRP.getGlobalVar then
        announcement = DarkRP.getGlobalVar("DarkRP_Announcement") or ""
    else
        announcement = GetGlobalString("DarkRP_Announcement", "")
    end
    announcement = string.Trim(tostring(announcement or ""))
    if announcement ~= "" then
        local aw = 360
        local ah = 52
        local ax = (ScrW() / 2) - (aw / 2)
        local ay = topMargin
        Dubz.DrawBubble(ax, ay, aw, ah, Color(18,18,18,220))
        draw.SimpleText("Announcement", "DubzHUD_Small", ax + 12, ay + 8, accent)
        draw.DrawText(announcement, "DubzHUD_Small", ax + 12, ay + 26, Color(240,240,240), TEXT_ALIGN_LEFT)
    end

    ------------------------------------------
    -- Lockdown Banner
    ------------------------------------------
    local locked = (DarkRP and DarkRP.getGlobalVar and DarkRP.getGlobalVar("DarkRP_LockDown")) or GetGlobalBool("DarkRP_LockDown", false)
    if locked then
        local lw = ScrW() * 0.35
        local lx = (ScrW() - lw) / 2
        local ly = topMargin + 64
        draw.RoundedBox(8, lx, ly, lw, 36, Color(160,20,20,220))
        draw.SimpleText("LOCKDOWN IN EFFECT", "DubzHUD_Body", lx + lw/2, ly + 8, Color(255,255,255), TEXT_ALIGN_CENTER)
    end

    ------------------------------------------
    -- Main HUD Container
    ------------------------------------------
    draw.RoundedBox(cfg.CornerRadius or 12, x, y, w, h, Dubz.Colors.Background or Color(0,0,0,160))
    draw.RoundedBox(0, x, y, cfg.AccentBarWidth or 6, h, accent)

    -- Name + Job
    local lx = x + (cfg.AccentBarWidth or 6) + (cfg.Padding or 12)
    local ly = y + (cfg.Padding or 12)

    local gang = Dubz.GetGangName and Dubz.GetGangName(ply) or nil
    local gangCol = gang and (Dubz.GetGangColor and Dubz.GetGangColor(ply)) or nil
    local nameText = ply:Nick() or "Player"
    local jobText = (ply.getDarkRPVar and ply:getDarkRPVar("job")) or "Citizen"
    local jobCol = (team and team.GetColor and team.GetColor(ply:Team())) or Color(200,200,200)

    if gang then
        draw.SimpleText("["..gang.."] ", "DubzHUD_Small", lx, ly+1, gangCol or Color(180,90,255))
        surface.SetFont("DubzHUD_Small")
        local gw,_ = surface.GetTextSize("["..gang.."] ")
        draw.SimpleText(nameText.." | ", "DubzHUD_Header", lx + gw, ly, Color(255,255,255))
        surface.SetFont("DubzHUD_Header")
        local nw,_ = surface.GetTextSize(nameText.." | ")
        draw.SimpleText(jobText, "DubzHUD_Header", lx + gw + nw, ly, jobCol)
    else
        draw.SimpleText(nameText.." | ", "DubzHUD_Header", lx, ly, Color(255,255,255))
        surface.SetFont("DubzHUD_Header")
        local nw,_ = surface.GetTextSize(nameText.." | ")
        draw.SimpleText(jobText, "DubzHUD_Header", lx + nw, ly, jobCol)
    end
    ly = ly + 28

    ------------------------------------------
    -- Smooth Health / Armor / Hunger tracking
    ------------------------------------------
    Dubz._rt = Dubz._rt or { hp = 0, ar = 0, hg = 0 }
    Dubz._rt.hp = SmoothTo(Dubz._rt.hp, math.Clamp(ply:Health(), 0, 100), cfg.SmoothSpeed)
    Dubz._rt.ar = SmoothTo(Dubz._rt.ar, math.Clamp(ply:Armor(), 0, 100), cfg.SmoothSpeed)

    local barW, barH = w - ((cfg.AccentBarWidth or 6) + (cfg.Padding or 12) * 2), 18

    -- Status bar renderer (kept local due to lx/ly closure)
    local function bar(label, frac, col)
        frac = math.Clamp(frac or 0, 0, 1)
        if frac > 0.995 then frac = 1 end

        draw.RoundedBox(6, lx, ly, barW, barH, Color(0,0,0,80))
        local fillW = barW * frac
        draw.RoundedBox(6, lx, ly, fillW, barH, col)
        draw.SimpleText(label, "DubzHUD_Small", lx + 6, ly + 2, Color(255,255,255,220))
        draw.SimpleText(string.format("%d%%", math.Round(frac * 100)), "DubzHUD_Small",
            lx + barW - 8, ly + 2, Color(255,255,255,200), TEXT_ALIGN_RIGHT)
        ly = ly + barH + 6
    end

    bar("Health", (Dubz._rt.hp or 0)/100, Color(200,40,60,200))
    bar("Armor", (Dubz._rt.ar or 0)/100, Color(60,120,200,200))

    ------------------------------------------
    -- Hunger (if enabled)
    ------------------------------------------
    local hcfg = cfg.Hunger or {}
    local hungerEnabled = hcfg.Enabled and ((GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.hungermod) or (ply.getDarkRPVar and ply:getDarkRPVar("Energy") ~= nil))
    if hungerEnabled then
        Dubz._rt.hg = SmoothTo(Dubz._rt.hg, math.Clamp((ply.getDarkRPVar and (ply:getDarkRPVar("Energy") or 0)) or 100, 0, 100), cfg.SmoothSpeed)
        local frac = (Dubz._rt.hg or 0)/100
        if frac > 0.995 then frac = 1 end
        local starving = (frac*100) <= (hcfg.StarvingThreshold or 15)
        local label = starving and (hcfg.StarvingText or "STARVING!") or (hcfg.Label or "Hunger")
        local color = starving and (hcfg.StarvingColor or Color(220,50,50)) or (hcfg.Color or Color(80,200,120,200))
        if hcfg.EnableStarvingWarning and starving then
            local pulse = 0.5 + 0.5 * math.sin(CurTime() * (hcfg.PulseSpeed or 3))
            color = Color(color.r, color.g, color.b, 180 + 60 * pulse)
        end
        bar(label, frac, color)
    end

    ---------------------------------------------------------
    -- MONEY BLOCK FADE (Global for all money)
    ---------------------------------------------------------
    ply._MoneyFade = ply._MoneyFade or 0

    local targetFade = 255  -- fully visible
    local fadeSpeed = 6

    -- Smooth approach to target alpha
    ply._MoneyFade = Lerp(FrameTime() * fadeSpeed, ply._MoneyFade, targetFade)

    local moneyAlpha = math.Clamp(ply._MoneyFade, 0, 255)

    ------------------------------------------
    -- Payday Bar (revised)
    ------------------------------------------
    local progress, salary, remaining, delay = paydayInfo(ply)

    local pbW, pbH = w * 0.55, (cfg.Payday and cfg.Payday.Height) or 20
    local px = x + (cfg.AccentBarWidth or 6) + (cfg.Padding or 12)
    local py = y + h - pbH - (cfg.Padding or 12)

    -- Background
    draw.RoundedBox(8, px, py, pbW, pbH, Color(0,0,0,120))

    -- Fill with red → yellow → green
    local paydayColor = PaydayColor(progress)
    draw.RoundedBox(8, px, py, math.floor(pbW * progress), pbH, paydayColor)

    -- Text fading white → black
    draw.SimpleText(
        string.format("Next Payday: %s (%.0fs)", formatMoney(salary), remaining),
        "DubzHUD_Small",
        px + pbW/2, py + 2,
        PaydayTextColor(progress),
        TEXT_ALIGN_CENTER
    )

    -- Trigger celebration when payday cycle just rolled over
    if paydayJustHappened then
        paydayJustHappened = false

        -- Clear previous pops
        PaydayPops = {}

        -- Spawn celebration burst
        local burstCount = 16
        for i = 1, burstCount do
            local rx = px + math.Rand(0, pbW)
            local ry = py + math.Rand(0, pbH)
            SpawnDollarPop(rx, ry)
        end

        -- Optional external function for extra effects
        if Dubz.PaydayPop then
            Dubz.PaydayPop()
        end
        -- Sound is already handled in playerPaidSalary hook to avoid double audio
    end

    ------------------------------------------
    -- 💸 Live Wallet Animation
    ------------------------------------------
    ply._DubzWalletDisplay = ply._DubzWalletDisplay or 0
    ply._DubzWalletLast = ply._DubzWalletLast or 0
    ply._DubzWalletSmooth = ply._DubzWalletSmooth or 0

    ---------------------------------------------------------
    -- DIRTY MONEY SMOOTHING (Updated for NWInt system)
    ---------------------------------------------------------
    ply._DirtyLast   = ply._DirtyLast   or 0
    ply._DirtySmooth = ply._DirtySmooth or 0

    -- Read synced dirty money from NWInt (persistent)
    local realDirty = ply:GetNWInt("DirtyMoney", 0)

    -- Detect change and animate
    if realDirty ~= ply._DirtyLast then
        ply._DirtyFrom  = ply._DirtySmooth
        ply._DirtyTo    = realDirty
        ply._DirtyStart = CurTime()
        ply._DirtyDur   = 1.0
        ply._DirtyLast  = realDirty
    end

    -- Smooth lerping
    if ply._DirtyFrom and ply._DirtyTo then
        local t = math.Clamp(
            (CurTime() - (ply._DirtyStart or 0)) / (ply._DirtyDur or 1),
            0, 1
        )
        ply._DirtySmooth = Lerp(t, ply._DirtyFrom or realDirty, ply._DirtyTo or realDirty)
    else
        ply._DirtySmooth = Lerp(FrameTime() * 8, ply._DirtySmooth, realDirty)
    end

    local dirtyMoney = ply._DirtySmooth


    ---------------------------------------------------------
    -- CLEAN MONEY SMOOTHING (original)
    ---------------------------------------------------------
    local realMoney = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0

    if realMoney ~= ply._DubzWalletLast then
        ply._DubzWalletFrom        = ply._DubzWalletSmooth
        ply._DubzWalletTo          = realMoney
        ply._DubzWalletChangeStart = CurTime()
        ply._DubzWalletChangeDur   = 1.0
        ply._DubzWalletLast        = realMoney
    end

    if ply._DubzWalletFrom and ply._DubzWalletTo then
        local t = math.Clamp(
            (CurTime() - (ply._DubzWalletChangeStart or 0)) / (ply._DubzWalletChangeDur or 1),
            0, 1
        )
        ply._DubzWalletSmooth = Lerp(t,
            ply._DubzWalletFrom or realMoney,
            ply._DubzWalletTo or realMoney
        )
    else
        ply._DubzWalletSmooth = Lerp(
            FrameTime() * 8,
            ply._DubzWalletSmooth or 0,
            realMoney
        )
    end

    local money = ply._DubzWalletSmooth

    ---------------------------------------------------------
    -- DIRTY MONEY BOUNCE ANIMATION
    ---------------------------------------------------------
    ply._DirtyBounce = ply._DirtyBounce or 0
    ply._DirtyBounceDecay = ply._DirtyBounceDecay or 0

    -- Detect a change in dirty money
    if dirtyMoney ~= ply._DirtyLastBounce then
        ply._DirtyBounce = 1.0      -- full bounce animation trigger
        ply._DirtyBounceDecay = CurTime()
        ply._DirtyLastBounce = dirtyMoney
    end

    -- Bounce scale (eases out smoothly)
    local bounceT = math.Clamp((CurTime() - ply._DirtyBounceDecay) * 4, 0, 1)
    local bounceScale = 1 + (0.25 * (1 - bounceT))  -- grows 25% then shrinks

    ---------------------------------------------------------
    -- UNIFIED CLEAN + DIRTY MONEY DISPLAY (FINAL FIXED)
    -- Correct order, perfect alignment, smooth bounce, fade
    ---------------------------------------------------------

    local alpha = moneyAlpha

    -- Build text
    local cleanText = formatMoney(money)
    local dirtyText = (dirtyMoney and dirtyMoney > 0) and formatMoney(dirtyMoney) or nil

    surface.SetFont("DubzHUD_Money")

    local cleanW     = surface.GetTextSize(cleanText)
    local sepText    = " | "
    local separatorW = surface.GetTextSize(sepText)
    local dirtyW     = dirtyText and surface.GetTextSize(dirtyText) or 0

    -- RIGHT anchor
    local moneyBaseX = x + w - (cfg.Padding or 12)
    local moneyY     = y + h - 30

    ---------------------------------------------------------
    -- BOUNCE FILTER
    ---------------------------------------------------------
    local bounceScale = 1
    if dirtyText then
        local t = math.Clamp((CurTime() - ply._DirtyBounceDecay) * 4, 0, 1)
        bounceScale = 1 + (0.25 * (1 - t))   -- 25% bounce
    end

    ---------------------------------------------------------
    -- POSITION CALCULATIONS (FINAL CORRECT ORDER)
    ---------------------------------------------------------
    -- CLEAN first (right aligned)
    -- Then separator
    -- Then DIRTY (left aligned)
    local dirtyStartX = nil
    if dirtyText then
        dirtyStartX =
            moneyBaseX         -- start from right edge
            - cleanW           -- clean money width
            - separatorW       -- " | "
            - (dirtyW * bounceScale)  -- scaled dirty money width
    end

    ---------------------------------------------------------
    -- SMOOTH PAYDAY BAR SHRINK (based on final combined width)
    ---------------------------------------------------------
    local combinedW = cleanW + (dirtyText and separatorW + dirtyW or 0)

    local desiredBarW = w * 0.55
    local minBarW = 120

    local spaceLeft = (moneyBaseX - combinedW) - px
    local targetPaydayW = math.Clamp(spaceLeft - 20, minBarW, desiredBarW)

    ply._SmoothPaydayW = Lerp(FrameTime() * 8, ply._SmoothPaydayW or desiredBarW, targetPaydayW)
    local pbW = ply._SmoothPaydayW

    ---------------------------------------------------------
    -- DRAW CLEAN MONEY
    ---------------------------------------------------------
    draw.SimpleText(
        cleanText,
        "DubzHUD_Money",
        moneyBaseX,
        moneyY,
        Color(60,255,90,alpha),
        TEXT_ALIGN_RIGHT
    )

    ---------------------------------------------------------
    -- SEPARATE DIRTY MONEY BOX (Perfectly bottom-aligned)
    ---------------------------------------------------------

    if dirtyMoney and dirtyMoney > 0 then
        local padding = 12 -- gap between HUD and box

        -- Calculate dirty money text size
        local text = formatMoney(dirtyMoney)
        surface.SetFont("DubzHUD_Money")
        local tw, th = surface.GetTextSize(text)

        -- Box size
        local boxW = tw + 24
        local boxH = th + 12

        -- HUD bottom
        local hudBottom = y + h

        -- PERFECT vertical alignment:
        local boxX = x + w + padding
        local boxY = y + h - boxH

        -----------------------------------------------------
        -- BOUNCE ANIMATION
        -----------------------------------------------------
        local t = math.Clamp((CurTime() - ply._DirtyBounceDecay) * 4, 0, 1)
        local bounceScale = 1 + (0.25 * (1 - t))

        -- Draw box background
        Dubz.DrawBubble(boxX, boxY, boxW, boxH, Color(0,0,0,160))

        -----------------------------------------------------
        -- BOUNCED DIRTY MONEY TEXT INSIDE THE BOX
        -----------------------------------------------------
        local tx = boxX + boxW/2
        local ty = boxY + boxH/2

        local mat = Matrix()
        mat:Translate(Vector(tx, ty, 0))
        mat:Scale(Vector(bounceScale, bounceScale, 1))
        mat:Translate(Vector(-tx, -ty, 0))

        cam.PushModelMatrix(mat)
            draw.SimpleText(
                text,
                "DubzHUD_Money",
                tx,
                ty,
                Color(255,180,50, moneyAlpha),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        cam.PopModelMatrix()
    end

    ------------------------------------------
    -- Hints above HUD
    ------------------------------------------
    local hints = cfg.Hints or {}
    if hints.Enabled then
        local keyW, keyH = hints.KeyWidth or 26, hints.KeyHeight or 18
        local hy = y - keyH + (hints.Position and hints.Position.y or 0)
        local hx = x + (hints.Position and hints.Position.x or 12)
        local running = 0
        for _, hint in ipairs(hints.Keys or {}) do
            local textGap, gap = hints.TextSpacing or 8, hints.Spacing or 32
            local key = tostring(hint.key or "?")
            local label = tostring(hint.action or "")
            surface.SetFont("DubzHUD_Small")
            local tw,_ = surface.GetTextSize(label)
            local groupW = keyW + textGap + tw
            local gx = hx + running
            draw.RoundedBox(hints.KeyCorner or 5, gx, hy, keyW, keyH, Dubz.GetAccentColor())
            draw.SimpleText(key, "DubzHUD_Small", gx + keyW/2, hy + keyH/2, Color(255,255,255,240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(label, "DubzHUD_Small", gx + keyW + textGap, hy + keyH/2 - 1, Color(230,230,230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            running = running + groupW + gap
        end
    end

    ------------------------------------------
    -- 🔫 AMMO HUD (Bottom-Right Corner)
    ------------------------------------------
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:Clip1() >= 0 then
        ply._ammoClip = SmoothTo(ply._ammoClip, wep:Clip1(), cfg.SmoothSpeed or 8)
        ply._ammoMax  = SmoothTo(ply._ammoMax, wep:GetMaxClip1() or 1, cfg.SmoothSpeed or 8)
        ply._ammoRes  = SmoothTo(ply._ammoRes, ply:GetAmmoCount(wep:GetPrimaryAmmoType()) or 0, cfg.SmoothSpeed or 8)

        local ammoFrac = 0
        if (wep:GetMaxClip1() or 0) > 0 then
            ammoFrac = math.Clamp((ply._ammoClip or 0) / (wep:GetMaxClip1() or 1), 0, 1)
            if ammoFrac > 0.995 then ammoFrac = 1 end
        end

        local abW, abH = 250, 26
        local margin = cfg.Margin or 20
        
        local ax = ScrW() - abW - margin
        local ay = ScrH() - abH - margin

        draw.RoundedBox(8, ax, ay, abW, abH, Color(0,0,0,150))
        draw.RoundedBox(8, ax, ay, math.floor(abW * ammoFrac), abH, accent)

        draw.SimpleText("Ammo", "DubzHUD_Small", ax + 8, ay + 4, Color(255,255,255,220))

        local clip = math.max(0, math.Round(ply._ammoClip or 0))
        local reserve = math.max(0, math.Round(ply._ammoRes or 0))

        draw.SimpleText(
            string.format("%d / %d", clip, reserve),
            "DubzHUD_Small",
            ax + abW - 8, ay + 4,
            Color(255,255,255,220),
            TEXT_ALIGN_RIGHT
        )
    end

    ------------------------------------------
    -- Draw Payday Particles on top
    ------------------------------------------
    DrawPaydayPops()
end)


------------------------------------------
-- Laws Panel
------------------------------------------
local lawPanel, lawsOpen = nil, false

local function ensureLawPanel()
    if IsValid(lawPanel) then return lawPanel end
    lawPanel = vgui.Create("DPanel")
    lawPanel:SetSize(300, 32)

    local offsetX = 40       -- distance from right side
    local offsetY = 200      -- lowered to avoid vote UI

    lawPanel:SetPos(offsetX, offsetY)    
    lawPanel:SetVisible(true)
    lawPanel:SetMouseInputEnabled(false)
    function lawPanel:Paint(w,h)
        Dubz.DrawBubble(0,0,w,h, Color(15,15,15,220))
        draw.SimpleText("Laws of the Land", "DubzHUD_Small", 12, 8, Color(255,255,255))
    end
    lawPanel.List = vgui.Create("DScrollPanel", lawPanel)
    lawPanel.List:Dock(FILL)
    lawPanel.List:DockMargin(12, 30, 12, 8)
    return lawPanel
end

local function fetchLaws()
    if DarkRP and DarkRP.getLaws then
        return DarkRP.getLaws()
    elseif GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.DefaultLaws then
        return GAMEMODE.Config.DefaultLaws
    end
    return {}
end

local function refreshLawPanel()
    local pnl = ensureLawPanel()
    if not IsValid(pnl.List) then return end
    pnl.List:Clear()
    local laws = fetchLaws()
    if #laws == 0 then
        local lbl = pnl.List:Add("DLabel")
        lbl:SetText("No laws posted.")
        lbl:Dock(TOP)
        lbl:SetTall(20)
        lbl:SetTextColor(Color(230,230,230))
    else
        for idx, law in ipairs(laws) do
            local lbl = pnl.List:Add("DLabel")
            lbl:SetText(idx .. ". " .. tostring(law))
            lbl:SetTall(20)
            lbl:SetTextColor(Color(235,235,235))
            lbl:Dock(TOP)
        end
    end
    local target = lawsOpen and math.Clamp(32 + (#laws * 24), 32, ScrH() * 0.6) or 32
    pnl:SizeTo(pnl:GetWide(), target, 0.2, 0, 0.2)
end

local function toggleLaws()
    lawsOpen = not lawsOpen
    refreshLawPanel()
end

hook.Add("PlayerBindPress","Dubz_LawToggle", function(ply, bind, pressed)
    if bind == "gm_showhelp" and pressed then
        toggleLaws()
        return true
    end
end)

hook.Add("OnScreenSizeChanged","Dubz_LawResize", function()
    if IsValid(lawPanel) then
        local offsetX = 40
        local offsetY = 200
        lawPanel:SetPos(ScrW() - lawPanel:GetWide() - offsetX, offsetY)
        if not lawsOpen then
            lawPanel:SetTall(32)
        end
    end
end)

timer.Create("Dubz_LawRefresh", 6, 0, function()
    if lawsOpen and IsValid(lawPanel) then
        refreshLawPanel()
    end
end)
