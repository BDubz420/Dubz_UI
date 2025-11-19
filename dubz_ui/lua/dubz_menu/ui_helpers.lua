
Dubz = Dubz or {}; Dubz.Logs = Dubz.Logs or {}

function Dubz.HookTextEntry(te)
    if not IsValid(te) then return end

    function te:OnGetFocus()
        Dubz.MenuLocked = true
    end

    function te:OnLoseFocus()
        Dubz.MenuLocked = false
    end
end

if not Dubz.Notify then
    function Dubz.Notify(msg, msgType)
        -- Use DarkRP notify if available
        if DarkRP and DarkRP.notify then
            DarkRP.notify(LocalPlayer(), 1, 5, msg)
            return
        end

        -- Sandbox default chat message
        chat.AddText(Color(255,80,80), "[Dubz UI] ", Color(255,255,255), msg)
    end
end

function Dubz.Log(msg, level)
    Dubz.Logs = Dubz.Logs or {}
    local time = os.date("%H:%M:%S")
    level = string.upper(level or "INFO")
    table.insert(Dubz.Logs, 1, {time=time, level=level, msg=tostring(msg)})
    local keep = (Dubz.Config and Dubz.Config.MaxLogs) or 800
    while #Dubz.Logs > keep do table.remove(Dubz.Logs) end
    if Dubz.Config and Dubz.Config.SaveLogsToFile then
        if not file.Exists("dubz_ui","DATA") then file.CreateDir("dubz_ui") end
        file.Append("dubz_ui/logs.txt", string.format("[%s] [%s] %s\n", time, level, msg))
    end
    if Dubz.Config and Dubz.Config.DevMode then
        local col = level=="ERROR" and Color(255,80,80) or (level=="WARN" and Color(255,220,0) or Color(60,255,90))
        MsgC(col, "[DubzUI]["..level.."] ", Color(200,200,200), msg.."\n")
    end
end

function Dubz.GetAccentColor()
    if Dubz.Config and Dubz.Config.AccentRainbow then
        local hue = (CurTime() * (Dubz.Config.RainbowSpeed or 0.2)) % 1
        local c = HSVToColor(hue * 360, 1, 1)
        return Color(c.r, c.g, c.b)
    end
    return (Dubz.Colors and Dubz.Colors.Accent) or Color(37,150,190)
end

function Dubz.DrawBubble(x,y,w,h,bg)
    draw.RoundedBox(10, x, y, w, h, bg or Color(0,0,0,120))
end

if CLIENT then
    function Dubz.GetGangName(ply)
        ply = ply or LocalPlayer()
        if not IsValid(ply) then return nil end

        local name = ply:GetNWString("DubzGang", "")
        if name == "" then return nil end
        return name
    end

    function Dubz.GetGangColor(ply)
        ply = ply or LocalPlayer()
        if not IsValid(ply) then return Color(255, 255, 255) end

        local v = ply:GetNWVector("DubzGangColor", Vector(1, 1, 1))
        return Color(v.x * 255, v.y * 255, v.z * 255)
    end
end