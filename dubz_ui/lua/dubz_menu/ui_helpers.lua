
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

-- logging is handled in dubz_shared/sh_dubz_log.lua

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