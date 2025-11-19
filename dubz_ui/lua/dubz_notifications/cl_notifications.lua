--========================================--
--      DUBZ CUSTOM NOTIFICATION UI
--      Fully replaces DarkRP + legacy UI
--========================================--

if not Dubz then return end
DarkRP = DarkRP or {}
if IsValid(Dubz_NotifyContainer) then Dubz_NotifyContainer:Remove() end

local active = {}
local scrw, scrh = ScrW(), ScrH()

-- USE DEFAULT GARRYS MOD NOTIFICATION ICONS
local icon_types = {
    [0] = { icon = "vgui/notices/hint.png",    color = Color(255,255,255) },
    [1] = { icon = "vgui/notices/error.png",   color = Color(255,255,255) },
    [2] = { icon = "vgui/notices/undo.png",    color = Color(255,255,255) },
    [3] = { icon = "vgui/notices/generic.png", color = Color(255,255,255) },
    [4] = { icon = "vgui/notices/cleanup.png", color = Color(255,255,255) },
}

----------------------------------------
-- Helper: Draw Bubble
----------------------------------------
local function DrawBubble(x, y, w, h, col)
    if Dubz.DrawBubble then
        Dubz.DrawBubble(x, y, w, h, col)
    else
        draw.RoundedBox(10, x, y, w, h, col)
    end
end

----------------------------------------
-- ADD NOTIFICATION (Internal)
----------------------------------------
local function AddDubzNotification(text, typeID, time)
    time = time or 5

    local accent = Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(80,150,255)
    local iconData = icon_types[typeID] or icon_types[0]
    local iconMat = Material(iconData.icon, "smooth")

    surface.SetFont("DubzHUD_Small")
    local tw, th = surface.GetTextSize(text)

    local panelW = math.max(240, tw + 60)
    local panelH = 40

    local pnl = vgui.Create("DPanel")
    pnl:SetSize(panelW, panelH)
    pnl:SetPos(scrw + panelW, scrh * 0.75 - (#active * (panelH + 8)))

    table.insert(active, pnl)

    local targetX = scrw - panelW - 12
    local startY = scrh * 0.75 - ((active and #active or 1) - 1) * (panelH + 8)

    pnl:MoveTo(targetX, startY, 0.12, 0, 0.15)
    pnl:SetAlpha(0)
    pnl:AlphaTo(255, 0.2)

    pnl.DieTime = CurTime() + time
    pnl.BarWidth = panelW -8

    pnl.Paint = function(self, w, h)
        DrawBubble(0, 0, w, h, Dubz.Colors.Background)

        -- Accent strip
        surface.SetDrawColor(accent)
        surface.DrawRect(0, 0, 4, h)

        -- Icon
        surface.SetMaterial(iconMat)
        surface.SetDrawColor(iconData.color)
        surface.DrawTexturedRect(8, h / 2 - 12, 24, 24)

        -- Text
        draw.SimpleText(text, "DubzHUD_Small", 40, h/2, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Time bar
        local frac = math.Clamp((self.DieTime - CurTime()) / time, 0, 1)
        self.BarWidth = Lerp(FrameTime() * 10, self.BarWidth, (w - 40) * frac)

        surface.SetDrawColor(255,255,255)
        surface.DrawRect(4, h - 3, self.BarWidth, 3)
    end

    ----------------------------------------
    -- AUTO REMOVE
    ----------------------------------------
    timer.Simple(time, function()
        if not IsValid(pnl) then return end

        local x, y = pnl:GetPos()
        table.RemoveByValue(active, pnl)

        pnl:MoveTo(scrw + (panelW * 2), y, 0.18, 0, 0.1)
        pnl:AlphaTo(0, 0.15, 0, function() if IsValid(pnl) then pnl:Remove() end end)

        -- Restack
        for k, v in ipairs(active) do
            if IsValid(v) then
                v:MoveTo(scrw - v:GetWide() - 12, scrh * 0.75 - ((k - 1) * (panelH + 8)), 0.1, 0, 0.1)
            end
        end
    end)

    return pnl
end

Dubz.AddNotification = AddDubzNotification

local function mapMsgType(msgType)
    if msgType == "error" then return 1
    elseif msgType == "undo" then return 2
    elseif msgType == "hint" then return 0
    elseif msgType == "cleanup" then return 4
    end
    return tonumber(msgType) or 0
end

function Dubz.Notify(msg, msgType, length)
    AddDubzNotification(tostring(msg or ""), mapMsgType(msgType), length or 5)
end

function notification.AddLegacy(text, type, time)
    AddDubzNotification(text, type, time)
end

function DarkRP.notify(ply, type, time, msg)
    if ply == LocalPlayer() then
        AddDubzNotification(msg, type, time)
    end
end

function DarkRP.notifyAll(type, time, msg)
    AddDubzNotification(msg, type, time)
end

function DarkRP.notifyInDistance(origin, range, type, time, msg)
    if not IsValid(LocalPlayer()) then return end
    if origin:DistToSqr(LocalPlayer():GetPos()) <= (range * range) then
        AddDubzNotification(msg, type, time)
    end
end

print("[DubzUI] Default-Icon Notifications Loaded")
