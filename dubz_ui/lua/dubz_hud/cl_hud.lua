local function L(val, to, spd)
    return Lerp(FrameTime() * (spd or 8), val, to)
end

-- hide default items (redundant safety)
hook.Add("HUDShouldDraw","Dubz_HideDefault", function(name)
    local hide = {
        ["DarkRP_HUD"]=true, ["DarkRP_EntityDisplay"]=true, ["DarkRP_ZombieInfo"]=true,
        ["DarkRP_LocalPlayerHUD"]=true, ["CHudHealth"]=true, ["CHudBattery"]=true,
        ["CHudAmmo"]=true, ["CHudSecondaryAmmo"]=true, ["DarkRP_Hungermod"]=true,
        ["DarkRP_LocalPlayerHunger"]=true, ["DarkRP_Energy"]=true
    }
    if hide[name] then return false end
end)

-- Payday tracking and animation
local function paydayInfo(ply)
    local delay = (GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.paydelay) or 300
    ply._DubzNextPay = ply._DubzNextPay or (CurTime() + delay)
    ply._DubzSalary = (ply.getDarkRPVar and (ply:getDarkRPVar("salary") or 0)) or 0
    if CurTime() >= ply._DubzNextPay then
        surface.PlaySound(Dubz.Config.HUD.Payday.Sound or "items/suitchargeok1.wav")
        local newMoney = ((ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0) + (ply._DubzSalary or 0)
        ply._DubzWalletAnimFrom = ply._DubzWalletAnimTo or ((ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0)
        ply._DubzWalletAnimTo = newMoney
        ply._DubzWalletAnimStart = CurTime()
        ply._DubzWalletAnimDur = Dubz.Config.HUD.Payday.AnimateWalletTime or 0.6
        ply._DubzNextPay = CurTime() + delay
    end
    local remaining = math.max(0, ply._DubzNextPay - CurTime())
    local progress = 1 - math.Clamp(remaining / delay, 0, 1)
    return progress, ply._DubzSalary, remaining, delay
end

local function formatMoney(n)
    local v = math.floor(tonumber(n) or 0)
    if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(v) end
    return "$"..tostring(v)
end

hook.Add("HUDPaint","Dubz_ModernHUD", function()
    if not Dubz or not Dubz.Config or not Dubz.Config.HUD or not Dubz.Config.HUD.Enabled then return end
    local cfg = Dubz.Config.HUD
    local ply = LocalPlayer(); if not IsValid(ply) then return end

    local accent = Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(37,150,190)
    local x = cfg.Margin or 20
    local h = cfg.Height or 148
    local w = cfg.Width or 420
    local y = ScrH() - h - (cfg.Margin or 20)

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

    ------------------------------------------------------
    -- Smooth Health / Armor / Hunger tracking
    ------------------------------------------------------
    local function SmoothTo(current, target, speed)
        return Lerp(FrameTime() * (speed or 8), current or 0, target or 0)
    end

    Dubz._rt = Dubz._rt or { hp = 0, ar = 0, hg = 0 }
    Dubz._rt.hp = SmoothTo(Dubz._rt.hp, math.Clamp(ply:Health(), 0, 100), cfg.SmoothSpeed)
    Dubz._rt.ar = SmoothTo(Dubz._rt.ar, math.Clamp(ply:Armor(), 0, 100), cfg.SmoothSpeed)

    local barW, barH = w - ((cfg.AccentBarWidth or 6) + (cfg.Padding or 12) * 2), 18

    ------------------------------------------------------
    -- Unified Status Bar Renderer (snaps at 100%)
    ------------------------------------------------------
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

    ------------------------------------------------------
    -- Hunger (if enabled)
    ------------------------------------------------------
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

    ------------------------------------------------------
    -- Payday Bar
    ------------------------------------------------------
    local progress, salary = paydayInfo(ply)
    local pbW, pbH = w /2, cfg.Payday.Height or 20
    local px = x + (cfg.AccentBarWidth or 6) + (cfg.Padding or 12)
    local py = y + h - pbH - (cfg.Padding or 12)
    draw.RoundedBox(8, px, py, pbW, pbH, Color(0,0,0,120))

    local paydayColor = Color(255 * (1 - progress), 255 * progress, 0, 220)
    draw.RoundedBox(8, px, py, math.floor(pbW * progress), pbH, paydayColor)
    draw.SimpleText("Next Payday: " .. formatMoney(salary), "DubzHUD_Small",px + pbW / 2, py, Color(240, 240, 240), TEXT_ALIGN_CENTER)

    ------------------------------------------------------
    -- 💸 Live Wallet Animation
    ------------------------------------------------------
    ply._DubzWalletDisplay = ply._DubzWalletDisplay or 0
    ply._DubzWalletLast = ply._DubzWalletLast or 0
    ply._DubzWalletSmooth = ply._DubzWalletSmooth or 0

    local realMoney = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
    if realMoney ~= ply._DubzWalletLast then
        ply._DubzWalletFrom = ply._DubzWalletSmooth
        ply._DubzWalletTo = realMoney
        ply._DubzWalletChangeStart = CurTime()
        ply._DubzWalletChangeDur = 1.0
        ply._DubzWalletLast = realMoney
    end

    if ply._DubzWalletFrom and ply._DubzWalletTo then
        local t = math.Clamp((CurTime() - (ply._DubzWalletChangeStart or 0)) / (ply._DubzWalletChangeDur or 1), 0, 1)
        ply._DubzWalletSmooth = Lerp(t, ply._DubzWalletFrom or realMoney, ply._DubzWalletTo or realMoney)
    else
        ply._DubzWalletSmooth = Lerp(FrameTime() * 8, ply._DubzWalletSmooth or 0, realMoney)
    end

    local money = ply._DubzWalletSmooth
    draw.SimpleText(formatMoney(money), "DubzHUD_Money", pbW * 1.75, y + h - 30, Color(60, 255, 90), TEXT_ALIGN_RIGHT)

    -- Hints above HUD
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

    ------------------------------------------------------
    -- 🔫 AMMO HUD (Bottom-Right Corner)
    ------------------------------------------------------
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

        -- Position (bottom-right)
        local abW, abH = 250, 26
        local margin = cfg.Margin or 20
        
        local ax = ScrW() - abW - margin
        local ay = ScrH() - abH - margin

        -- Background
        draw.RoundedBox(8, ax, ay, abW, abH, Color(0,0,0,150))
        -- Fill
        draw.RoundedBox(8, ax, ay, math.floor(abW * ammoFrac), abH, accent)

        -- Label
        draw.SimpleText("Ammo", "DubzHUD_Small", ax + 8, ay + 4, Color(255,255,255,220))

        -- Clip / Reserve
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
end)
