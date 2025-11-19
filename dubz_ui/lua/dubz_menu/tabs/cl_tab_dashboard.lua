-- cl_tab_dashboard.lua (v0.5.1)
-- Dubz UI: live economy dashboard with visuals + persistent leaderboard

--------------------------------------------------------------
-- 📈 Small helper visuals
--------------------------------------------------------------
local function DrawSparkline(x, y, w, h, data, col)
    if not data or #data < 2 then return end
    local maxV, minV = -math.huge, math.huge
    for _,v in ipairs(data) do
        if v > maxV then maxV = v end
        if v < minV then minV = v end
    end
    if maxV == minV then maxV = maxV + 1 end
    surface.SetDrawColor(col or Color(120,200,255))
    local innerW, innerH = w - 2, h - 2
    for i = 2, #data do
        local x1 = x + ((i-2)/(#data-1)) * innerW + 1
        local x2 = x + ((i-1)/(#data-1)) * innerW + 1
        local y1 = y + innerH - ((data[i-1]-minV)/(maxV-minV)) * innerH + 1
        local y2 = y + innerH - ((data[i]-minV)/(maxV-minV)) * innerH + 1
        surface.DrawLine(x1, y1, x2, y2)
    end
end

local function DrawProgressBar(x, y, w, h, frac, bgCol, fgCol)
    frac = tonumber(frac) or 0       -- force numeric
    frac = math.Clamp(frac, 0, 1)    -- safe clamp
    surface.SetDrawColor(bgCol or Color(40,40,40,200))
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(fgCol or Color(120,200,255,255))
    surface.DrawRect(x, y, math.floor(w * frac), h)
end

--------------------------------------------------------------
-- 🧭 Main Dashboard Tab
--------------------------------------------------------------
Dubz.RegisterTab("dashboard","Dashboard","dashboard", function(parent)
    local accent = Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(37,150,190)

    local pnl = vgui.Create("DPanel", parent)
    pnl:Dock(FILL)
    pnl:DockMargin(12,12,12,12)
    pnl:SetPaintBackground(false)

    pnl._state = { money = 0, avg = 0, count = 0, max = game.MaxPlayers() or 0, trend = {}, avgTrend = {} }

    ----------------------------------------------------------
    -- 🧮 Update live stats
    ----------------------------------------------------------
    local function computeStats()
        local total, count = 0, 0
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                count = count + 1
                local m = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
                total = total + math.floor(tonumber(m) or 0)
            end
        end
        pnl._state.money = total
        pnl._state.count = count
        pnl._state.max = game.MaxPlayers() or 0
        pnl._state.avg = (count > 0) and math.floor(total / count) or 0

        table.insert(pnl._state.trend, pnl._state.money)
        table.insert(pnl._state.avgTrend, pnl._state.avg)
        if #pnl._state.trend > 60 then table.remove(pnl._state.trend, 1) end
        if #pnl._state.avgTrend > 60 then table.remove(pnl._state.avgTrend, 1) end
    end

    computeStats()
    timer.Create("Dubz_DashboardUpdate", 0.5, 0, function()
        if not IsValid(pnl) then timer.Remove("Dubz_DashboardUpdate") return end
        computeStats()
    end)

    ----------------------------------------------------------
    -- 🎨 Paint Dashboard
    ----------------------------------------------------------
    function pnl:Paint(w,h)
        local pad = 12
        local bubbleW = math.floor((w - pad*3) / 3)
        local bubbleH = 140

        -- Top bubbles
        Dubz.DrawBubble(pad, pad, bubbleW, bubbleH, Color(24,24,24,220))
        Dubz.DrawBubble(pad*2 + bubbleW, pad, bubbleW, bubbleH, Color(24,24,24,220))
        Dubz.DrawBubble(pad*3 + bubbleW*2, pad, bubbleW, bubbleH, Color(24,24,24,220))

        -- Texts
        draw.SimpleText("Total Money", "DubzHUD_Small", pad+12, pad+10, Color(230,230,230))
        local ttxt = (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(pnl._state.money)) or ("$"..tostring(pnl._state.money))
        draw.SimpleText(ttxt, "DubzHUD_Header", pad+12, pad+40, accent)

        local ax = pad*2 + bubbleW
        draw.SimpleText("Average Player $", "DubzHUD_Small", ax+12, pad+10, Color(230,230,230))
        local atxt = (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(pnl._state.avg)) or ("$"..tostring(pnl._state.avg))
        draw.SimpleText(atxt, "DubzHUD_Header", ax+12, pad+40, accent)

        local px = pad*3 + bubbleW*2
        draw.SimpleText("Players Online", "DubzHUD_Small", px+12, pad+10, Color(230,230,230))
        draw.SimpleText(pnl._state.count.." / "..pnl._state.max, "DubzHUD_Header", px+12, pad+40, accent)

        ------------------------------------------------------
        -- 🕓 Local Date & Time (top right)
        ------------------------------------------------------
        local dateStr = os.date("%A, %B %d, %Y")
        local timeStr = os.date("%I:%M:%S %p")
        local timeX = w - pad - 10
        local timeY = pad + 4

        -- background panel behind time (subtle)
        --draw.RoundedBox(6, timeX - 190, timeY - 2, 180, 40, Color(20,20,20,160))

        draw.SimpleText(dateStr, "DubzHUD_Small", timeX - 100, timeY + 4, Color(200,200,200), TEXT_ALIGN_CENTER)
        draw.SimpleText(timeStr, "DubzHUD_Body", timeX - 100, timeY + 20, accent, TEXT_ALIGN_CENTER)

        ------------------------------------------------------
        -- 👥 Player Count Progress Bar (with notches)
        ------------------------------------------------------
        local barX, barY = px + 12, pad + bubbleH - 30
        local barW, barH = bubbleW - 24, 14

        -- background
        surface.SetDrawColor(Color(28,28,28,220))
        surface.DrawRect(barX, barY, barW, barH)

        -- notch settings
        local maxP = pnl._state.max > 0 and pnl._state.max or 1
        local currentP = math.Clamp(pnl._state.count, 0, maxP)
        local notchCount = maxP
        local notchSpacing = 2
        local notchW = (barW - (notchSpacing * (notchCount - 1))) / notchCount
        local filled = currentP

        -- draw notches
        for i = 1, notchCount do
            local nx = barX + (i - 1) * (notchW + notchSpacing)
            local color
            if i <= filled then
                color = accent
            else
                color = Color(60,60,60,180)
            end
            draw.RoundedBox(2, nx, barY + 1, notchW, barH - 2, color)
        end

        -- thin outline
        surface.SetDrawColor(0,0,0,180)
        surface.DrawOutlinedRect(barX, barY, barW, barH, 1)

        ------------------------------------------------------
        -- 📊 Economy Trend Chart
        ------------------------------------------------------
        local chartX, chartY = pad, pad*2 + bubbleH + 12
        local chartW, chartH = w - pad*2, 120
        Dubz.DrawBubble(chartX, chartY, chartW, chartH, Color(24,24,24,220))
        draw.SimpleText("Economy Trend (Total Wealth)", "DubzHUD_Small", chartX + 12, chartY + 8, Color(200,200,200))

        local data = pnl._state.trend
        if #data >= 2 then
            local maxVal, minVal = 0, math.huge
            for _,v in ipairs(data) do
                if v > maxVal then maxVal = v end
                if v < minVal then minVal = v end
            end
            if maxVal == minVal then maxVal = maxVal + 1 end

            surface.SetDrawColor(accent)
            for i = 2, #data do
                local x1 = chartX + ((i-2)/(#data-1)) * (chartW - 20) + 10
                local x2 = chartX + ((i-1)/(#data-1)) * (chartW - 20) + 10
                local y1 = chartY + chartH - ((data[i-1]-minVal)/(maxVal-minVal)) * (chartH - 30) - 10
                local y2 = chartY + chartH - ((data[i]-minVal)/(maxVal-minVal)) * (chartH - 30) - 10
                surface.DrawLine(x1, y1, x2, y2)
            end
        end

        ------------------------------------------------------
        -- 💰 Top Richest Players (config-integrated + live update)
        ------------------------------------------------------
        local listX, listY, listW = pad, chartY + chartH + 32, w - pad*2
        draw.SimpleText("Top Richest Players", "DubzHUD_Header", listX, listY - 24, accent)

        local updateRate = (Dubz.Config and Dubz.Config.Dashboard and Dubz.Config.Dashboard.UpdateRate) or 0.5
        local showN = (Dubz.Config and Dubz.Config.Dashboard and Dubz.Config.Dashboard.TopRichestCount) or 5

        -- cache to avoid excess work
        pnl._richestCache = pnl._richestCache or {}
        pnl._nextRichestUpdate = pnl._nextRichestUpdate or 0

        if CurTime() >= (pnl._nextRichestUpdate or 0) then
            pnl._nextRichestUpdate = CurTime() + updateRate

            -- normalize keying
            local function ToSID64(anyid)
                if not anyid or anyid == "" then return nil end
                if isnumber(anyid) then
                    return tostring(math.floor(anyid))
                elseif isstring(anyid) and tonumber(anyid) then
                    return tostring(math.floor(tonumber(anyid)))
                elseif isstring(anyid) and string.find(anyid, "STEAM_") then
                    if util and util.SteamIDTo64 then
                        local ok, sid64 = pcall(util.SteamIDTo64, anyid)
                        if ok and sid64 and sid64 ~= "0" then return sid64 end
                    end
                end
                return tostring(anyid)
            end

            local richestMap = {}

            -- 1️⃣ Offline stored data
            for sid, dat in pairs(Dubz.RichestPlayers or {}) do
                local sid64 = ToSID64(sid)
                if sid64 then
                    richestMap[sid64] = {
                        sid64   = sid64,
                        name    = (dat and dat.name) or "Unknown",
                        money   = tonumber(dat and dat.money) or 0,
                        isOnline= false
                    }
                end
            end

            -- 2️⃣ Online override
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply.SteamID64 then
                    local sid64 = tostring(ply:SteamID64())
                    local liveMoney = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
                    richestMap[sid64] = {
                        sid64   = sid64,
                        name    = ply:Nick(),
                        money   = math.floor(tonumber(liveMoney) or 0),
                        isOnline= true
                    }
                end
            end

            -- 3️⃣ Sort descending
            local list = {}
            for _, v in pairs(richestMap) do table.insert(list, v) end
            table.sort(list, function(a,b) return (a.money or 0) > (b.money or 0) end)

            pnl._richestCache = list
        end

        -- 4️⃣ Draw cached leaderboard
        local yoff = 0
        for i = 1, math.min(showN, #(pnl._richestCache or {})) do
            local t = pnl._richestCache[i]
            Dubz.DrawBubble(listX, listY + yoff, listW, 38, Color(24,24,24,220))

            local rcol = (i==1 and Color(255,215,0))
                or (i==2 and Color(192,192,192))
                or (i==3 and Color(205,127,50))
                or Color(200,200,200)

            draw.SimpleText("#"..i, "DubzHUD_Small", listX + 10, listY + yoff + 10, rcol)

            local nameCol  = t.isOnline and Color(120,255,160) or Color(160,160,160,200)
            local moneyCol = t.isOnline and Color(220,255,230) or Color(170,170,170,180)
            local iconCol  = t.isOnline and Color(80,255,120) or Color(120,120,120,150)

            draw.SimpleText(t.name or "Player", "DubzHUD_Body", listX + 100, listY + yoff + 8, nameCol)
            local moneyText = (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(t.money)) or ("$"..tostring(t.money))
            draw.SimpleText(moneyText, "DubzHUD_Body", listX + listW - 10, listY + yoff + 8, moneyCol, TEXT_ALIGN_RIGHT)

            draw.SimpleText("●", "DubzHUD_Small", listX + 80, listY + yoff + 10, iconCol)
            yoff = yoff + 44
        end

        ------------------------------------------------------
        -- 🏴 Richest Gangs (optional)
        ------------------------------------------------------
        if Dubz.Config and Dubz.Config.Gangs and Dubz.Config.Gangs.Enabled and Dubz.Config.Gangs.ShowOnDashboard then
            local gy = listY + yoff + 20
            draw.SimpleText("Top Richest Gangs", "DubzHUD_Header", listX, gy - 24, accent)
            local gangs = {}
            for gname, amt in pairs(Dubz.RichestGangs or {}) do
                table.insert(gangs, { name=gname, money=tonumber(amt) or 0 })
            end
            table.sort(gangs, function(a, b) return (a.money or 0) > (b.money or 0) end)
            local gshow = (Dubz.Config.Gangs.DashboardTopCount) or 5
            local gyoff = 0
            for i = 1, math.min(gshow, #gangs) do
                local t = gangs[i]
                Dubz.DrawBubble(listX, gy + gyoff, listW, 38, Color(24,24,24,220))
                local rcol = (i==1 and Color(255,215,0)) or (i==2 and Color(192,192,192)) or (i==3 and Color(205,127,50)) or Color(230,230,230)
                draw.SimpleText("#"..i, "DubzHUD_Small", listX + 10, gy + gyoff + 10, rcol)
                draw.SimpleText(t.name or "Gang", "DubzHUD_Body", listX + 140, gy + gyoff + 8, Color(230,230,230))
                local moneyText = (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(t.money)) or ("$"..tostring(t.money))
                draw.SimpleText(moneyText, "DubzHUD_Body", listX + listW - 10, gy + gyoff + 8, Color(230,230,230), TEXT_ALIGN_RIGHT)
                gyoff = gyoff + 44
            end
        end
    end
end)
