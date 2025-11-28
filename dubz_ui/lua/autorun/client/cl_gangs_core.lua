--------------------------------------------------------
-- DUBZ GANGS - CLIENT CORE
-- Handles: Networking, Data Cache, Sync, Graffiti Data
--------------------------------------------------------

Dubz = Dubz or {}
Dubz.Gangs = Dubz.Gangs or {}
Dubz.GangRevision = Dubz.GangRevision or 0

local Gangs     = Dubz.Gangs
local MyGangId  = ""
local MyRank    = 0

local function BumpGangRevision()
    Dubz.GangRevision = (Dubz.GangRevision or 0) + 1
end

-- Shared graffiti font bootstrapper (kept global so UI reloads always see it)
if not Dubz.EnsureGraffitiFont then
    function Dubz.EnsureGraffitiFont(g)
        if not g then return "Trebuchet24" end

        g.graffiti = g.graffiti or {}
        g.graffiti.font  = g.graffiti.font or "Trebuchet24"
        g.graffiti.scale = tonumber(g.graffiti.scale) or 1

        Dubz._GraffitiFonts = Dubz._GraffitiFonts or {}
        if not Dubz._GraffitiFonts[g.graffiti.font] then
            surface.CreateFont(g.graffiti.font, {
                font = g.graffiti.font,
                size = 24,
                weight = 600,
                antialias = true
            })
            Dubz._GraffitiFonts[g.graffiti.font] = true
        end

        local name = g.graffiti.fontScaled or ("DubzGraffiti_Font_" .. math.floor(g.graffiti.scale * 100))
        g.graffiti.fontScaled = name

        if not Dubz._GraffitiFonts[name] then
            surface.CreateFont(name, {
                font      = g.graffiti.font,
                size      = math.max(16, math.floor(24 * g.graffiti.scale)),
                weight    = 800,
                antialias = true
            })
            Dubz._GraffitiFonts[name] = true
        end

        return name
    end
end

--------------------------------------------------------
-- HELPER: Send actions to server
--------------------------------------------------------
function Dubz.SendGangAction(tbl)
    net.Start("Dubz_Gang_Action")
    net.WriteTable(tbl)
    net.SendToServer()
end

--------------------------------------------------------
-- HELPER: My Gang / Rank
--------------------------------------------------------
function Dubz.GetMyGang()
    return (MyGangId ~= "" and Gangs[MyGangId]) or nil
end

function Dubz.IsLeaderC()
    local g = Dubz.GetMyGang()
    if not g then return false end
    return MyRank >= (Dubz.GangRanks.Leader or 3)
end

--------------------------------------------------------
-- UI refresh callback
--------------------------------------------------------
function Dubz.RefreshGangUI()
    if IsValid(Dubz.ActiveGangPanel) then
        local pnl = Dubz.ActiveGangPanel
        pnl:InvalidateLayout(true)
        pnl:InvalidateParent(true)

        timer.Simple(0, function()
            if IsValid(pnl) then
                pnl:InvalidateLayout(true)
                pnl:InvalidateParent(true)
            end
        end)
    end
end

--------------------------------------------------------
-- CLIENTSIDE Normalize
-- (Fixes missing graffiti.key fields)
--------------------------------------------------------
local function NormalizeGraffitiClient(g)
    g.graffiti = g.graffiti or {}

    g.graffiti.text   = g.graffiti.text   or g.name or "Gang"
    g.graffiti.font   = g.graffiti.font   or "Trebuchet24"
    g.graffiti.scale  = tonumber(g.graffiti.scale) or 1
    g.graffiti.effect = g.graffiti.effect or "Clean"
    g.graffiti.outlineSize = tonumber(g.graffiti.outlineSize) or 1
    g.graffiti.shadowOffset = tonumber(g.graffiti.shadowOffset) or 2

    g.graffiti.fontScaled =
        g.graffiti.fontScaled or
        ("DubzGraffiti_Font_" .. math.floor(g.graffiti.scale * 100))

    local base = g.graffiti.color or g.color or { r=255, g=255, b=255 }
    g.graffiti.color = {
        r = math.Clamp(tonumber(base.r) or 255, 0, 255),
        g = math.Clamp(tonumber(base.g) or 255, 0, 255),
        b = math.Clamp(tonumber(base.b) or 255, 0, 255)
    }
end

--------------------------------------------------------
-- FULL SYNC
--------------------------------------------------------
net.Receive("Dubz_Gang_FullSync", function()
    local tbl = net.ReadTable() or {}
    Dubz.Gangs = tbl
    Gangs = Dubz.Gangs

    for gid, g in pairs(Gangs) do
        NormalizeGraffitiClient(g)
    end

    hook.Run("Dubz_Gangs_FullSync", Gangs)
    BumpGangRevision()
    Dubz.RefreshGangUI()
end)

--------------------------------------------------------
-- MY STATUS
--------------------------------------------------------
net.Receive("Dubz_Gang_MyStatus", function()
    MyGangId = net.ReadString() or ""
    MyRank   = net.ReadUInt(3) or 0

    -- expose to other client files that rely on the globals
    Dubz.MyGangId = MyGangId
    Dubz.MyRank   = MyRank

    hook.Run("Dubz_Gangs_MyStatus", MyGangId, MyRank)
    BumpGangRevision()
    Dubz.RefreshGangUI()
end)

--------------------------------------------------------
-- SINGLE GANG UPDATE
--------------------------------------------------------
net.Receive("Dubz_Gang_Update", function()
    local gid  = net.ReadString()
    local data = net.ReadTable() or {}

    if data and data.id then
        Dubz.Gangs[gid] = data
        NormalizeGraffitiClient(Dubz.Gangs[gid])
    else
        Dubz.Gangs[gid] = nil
    end

    hook.Run("Dubz_Gangs_GangUpdated", gid, Dubz.Gangs[gid])
    BumpGangRevision()
    Dubz.RefreshGangUI()
end)

--------------------------------------------------------
-- GANG INVITE POPUP
--------------------------------------------------------
net.Receive("Dubz_Gang_Invite", function()
    local gid   = net.ReadString()
    local gname = net.ReadString() or "Gang"
    local from  = net.ReadString() or "Leader"

    Derma_Query(
        from .. " invited you to join '" .. gname .. "'",
        "Gang Invite",

        "Accept", function()
            Dubz.SendGangAction({cmd="accept_invite"})
        end,

        "Decline", function()
            Dubz.SendGangAction({cmd="decline_invite"})
        end
    )
end)

--------------------------------------------------------
-- GANG BANNERS (join/leave)
--------------------------------------------------------
local banners = {}
net.Receive("Dubz_Gang_Banner", function()
    local msg = net.ReadString() or ""
    local col = net.ReadColor() or Color(255,255,255)
    if msg == "" then return end
    table.insert(banners, {
        msg   = msg,
        col   = col,
        start = CurTime(),
        dur   = 4
    })
end)

hook.Add("HUDPaint", "Dubz_Gang_Banner_Draw", function()
    if #banners == 0 then return end
    local now = CurTime()
    local y = 32
    for i = #banners, 1, -1 do
        local b = banners[i]
        local t = (now - b.start)
        if t > b.dur then
            table.remove(banners, i)
        else
            local alpha = 1
            if t > b.dur - 0.8 then
                alpha = math.Clamp((b.dur - t) / 0.8, 0, 1)
            end
            local w, h = 320, 36
            local x = (ScrW() - w) * 0.5
            surface.SetAlphaMultiplier(alpha)
            if Dubz.DrawBubble then
                Dubz.DrawBubble(x, y, w, h, Color(18,18,18,220))
            else
                draw.RoundedBox(8, x, y, w, h, Color(18,18,18,220))
            end
            draw.SimpleText(b.msg, "DubzHUD_Small", x + w/2, y + h/2 - 2, Color(b.col.r, b.col.g, b.col.b, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            surface.SetAlphaMultiplier(1)
            y = y + h + 6
        end
    end
end)
