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

local function BumpGangRevision()
    Dubz.GangRevision = (Dubz.GangRevision or 0) + 1
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
    return (Dubz.MyGangId ~= "" and Gangs[Dubz.MyGangId]) or nil
end

function Dubz.IsLeaderC()
    local g = Dubz.GetMyGang()
    if not g then return false end
    return (Dubz.MyRank or 0) >= (Dubz.GangRanks.Leader or 3)
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
-- CLIENTSIDE graffiti normalize
--------------------------------------------------------
local function NormalizeGraffitiClient(g)
    g.graffiti = g.graffiti or {}

    g.graffiti.text   = g.graffiti.text   or g.name or "Gang"
    g.graffiti.font   = g.graffiti.font   or "Trebuchet24"
    g.graffiti.scale  = tonumber(g.graffiti.scale) or 1
    g.graffiti.effect = g.graffiti.effect or "Clean"

    -- extra cosmetics with sane defaults
    g.graffiti.outlineSize   = tonumber(g.graffiti.outlineSize) or 1
    g.graffiti.shadowOffset  = tonumber(g.graffiti.shadowOffset) or 2
    g.graffiti.bgMat         = g.graffiti.bgMat or "brick/brick_model"

    g.graffiti.fontScaled =
        g.graffiti.fontScaled or
        ("DubzGraffiti_Font_" .. math.floor(g.graffiti.scale * 100))

    g.graffiti.bgMat = g.graffiti.bgMat or "brick/brick_model"

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
            Dubz.SendGangAction({ cmd = "accept_invite" })
        end,

        "Decline", function()
            Dubz.SendGangAction({ cmd = "decline_invite" })
        end
    )
end)

--------------------------------------------------------
-- HUD SUPPORT HELPERS
--------------------------------------------------------

function Dubz.GetGangName(ply)
    if ply ~= LocalPlayer() then return nil end
    if not Dubz.MyGangId or Dubz.MyGangId == "" then return nil end

    local g = Dubz.Gangs[Dubz.MyGangId]
    return g and g.name or nil
end

function Dubz.GetGangColor(ply)
    if ply ~= LocalPlayer() then return Color(255,255,255) end
    if not Dubz.MyGangId or Dubz.MyGangId == "" then return Color(255,255,255) end

    local g = Dubz.Gangs[Dubz.MyGangId]
    if not g or not g.color then return Color(255,255,255) end

    return Color(g.color.r or 255, g.color.g or 255, g.color.b or 255)
end