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
    g.graffiti.font   = g.graffiti.font   or (Dubz.Config.GraffitiFonts[1] and Dubz.Config.GraffitiFonts[1].id) or "Trebuchet24"

    local function fontValid(id)
        for _, f in ipairs(Dubz.Config.GraffitiFonts or {}) do
            if f.id == id then return true end
        end
        return false
    end

    if not fontValid(g.graffiti.font) then
        g.graffiti.font = (Dubz.Config.GraffitiFonts[1] and Dubz.Config.GraffitiFonts[1].id) or "Trebuchet24"
    end
    g.graffiti.scale  = tonumber(g.graffiti.scale) or 1
    g.graffiti.effect = g.graffiti.effect or "Clean"

    -- extra cosmetics with sane defaults
    g.graffiti.outlineSize   = tonumber(g.graffiti.outlineSize) or 1
    g.graffiti.shadowOffset  = tonumber(g.graffiti.shadowOffset) or 2

    local fontScaleKey = tostring(g.graffiti.scale or 1)
    g.graffiti.fontScaled =
        g.graffiti.fontScaled or
        ("DubzGraff_" .. g.graffiti.font .. "_Base_S" .. fontScaleKey)

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

--------------------------------------------------------
-- Initialize Graffiti Fonts
--------------------------------------------------------

hook.Add("Initialize", "Dubz_RegisterGraffitiFonts", function()

    for _, f in ipairs(Dubz.Config.GraffitiFonts) do
        surface.CreateFont("DubzGraff_" .. f.id .. "_Base", {
            font = f.file,
            size = 40,
            weight = 900,
            antialias = true,
            extended = true
        })
    end

end)

--------------------------------------------------------
-- GANG WAR HUD (GLOBAL FOR ALL GANG MEMBERS)
--------------------------------------------------------

local WarHUD_Active      = false
local WarHUD_MyGang      = ""
local WarHUD_Enemy       = ""
local WarHUD_EndTime     = 0
local WarHUD_Progress    = 0
local WarHUD_Lerp        = 0
local WarCountdown_Active = false
local WarCountdown_End    = 0
local WarCountdown_Enemy  = ""

--------------------------------------------------------
-- WAR START
--------------------------------------------------------
net.Receive("Dubz_GangWar_Start", function()
    local g1   = net.ReadString()
    local g2   = net.ReadString()
    local ends = net.ReadFloat()

    -- Only show HUD if this player belongs to one of the gangs
    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    WarHUD_Active  = true
    WarHUD_MyGang  = Dubz.MyGangId
    WarHUD_Enemy   = (Dubz.MyGangId == g1) and g2 or g1
    WarHUD_EndTime = ends
    WarHUD_Lerp    = 0
    WarCountdown_Active = false
end)

--------------------------------------------------------
-- WAR END (forfeit or time expired)
--------------------------------------------------------
net.Receive("Dubz_GangWar_End", function()
    WarHUD_Active = false
    WarCountdown_Active = false
end)

--------------------------------------------------------
-- OPTIONAL PROGRESS UPDATES (FUTURE EXPANSION)
--------------------------------------------------------
net.Receive("Dubz_GangWar_Update", function()
    WarHUD_Progress = math.Clamp(net.ReadFloat(), 0, 1)
end)

--------------------------------------------------------
-- WAR VOTE PROMPT
--------------------------------------------------------
net.Receive("Dubz_GangWar_VotePrompt", function()
    local voteId   = net.ReadString()
    local g1       = net.ReadString()
    local g2       = net.ReadString()
    local duration = net.ReadFloat()

    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    if IsValid(Dubz.WarVoteFrame) then Dubz.WarVoteFrame:Remove() end

    local enemy = (Dubz.MyGangId == g1) and g2 or g1

    local fr = vgui.Create("DFrame")
    fr:SetTitle("Gang War Vote")
    fr:SetSize(340, 180)
    fr:Center()
    fr:MakePopup()
    Dubz.WarVoteFrame = fr

    local lbl = vgui.Create("DLabel", fr)
    lbl:SetText(string.format("Vote to start a war with %s", enemy))
    lbl:SetFont("DubzHUD_Body")
    lbl:SizeToContents()
    lbl:SetPos(20, 40)

    local info = vgui.Create("DLabel", fr)
    info:SetFont("DubzHUD_Tag")
    info:SetText("Capture enemy territories and defend your own.")
    info:SizeToContents()
    info:SetPos(20, 64)

    local yes = vgui.Create("DButton", fr)
    yes:SetSize(140, 34)
    yes:SetPos(20, 120)
    yes:SetText("Yes, go to war")
    yes.DoClick = function()
        Dubz.SendGangAction({ cmd = "vote_war", choice = true, voteId = voteId })
        fr:Close()
    end

    local no = vgui.Create("DButton", fr)
    no:SetSize(140, 34)
    no:SetPos(180, 120)
    no:SetText("No")
    no.DoClick = function()
        Dubz.SendGangAction({ cmd = "vote_war", choice = false, voteId = voteId })
        fr:Close()
    end

    timer.Simple(duration, function()
        if IsValid(fr) then fr:Close() end
    end)
end)

--------------------------------------------------------
-- WAR COUNTDOWN / BRIEFING
--------------------------------------------------------
net.Receive("Dubz_GangWar_Countdown", function()
    local g1    = net.ReadString()
    local g2    = net.ReadString()
    local secs  = net.ReadFloat()

    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    WarCountdown_Active = true
    WarCountdown_End    = CurTime() + secs
    WarCountdown_Enemy  = (Dubz.MyGangId == g1) and g2 or g1
end)

--------------------------------------------------------
-- WAR VOTE PROMPT
--------------------------------------------------------
net.Receive("Dubz_GangWar_VotePrompt", function()
    local voteId   = net.ReadString()
    local g1       = net.ReadString()
    local g2       = net.ReadString()
    local duration = net.ReadFloat()

    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    if IsValid(Dubz.WarVoteFrame) then Dubz.WarVoteFrame:Remove() end

    local enemy = (Dubz.MyGangId == g1) and g2 or g1

    local fr = vgui.Create("DFrame")
    fr:SetTitle("Gang War Vote")
    fr:SetSize(340, 180)
    fr:Center()
    fr:MakePopup()
    Dubz.WarVoteFrame = fr

    local lbl = vgui.Create("DLabel", fr)
    lbl:SetText(string.format("Vote to start a war with %s", enemy))
    lbl:SetFont("DubzHUD_Body")
    lbl:SizeToContents()
    lbl:SetPos(20, 40)

    local info = vgui.Create("DLabel", fr)
    info:SetFont("DubzHUD_Tag")
    info:SetText("Capture enemy territories and defend your own.")
    info:SizeToContents()
    info:SetPos(20, 64)

    local yes = vgui.Create("DButton", fr)
    yes:SetSize(140, 34)
    yes:SetPos(20, 120)
    yes:SetText("Yes, go to war")
    yes.DoClick = function()
        Dubz.SendGangAction({ cmd = "vote_war", choice = true, voteId = voteId })
        fr:Close()
    end

    local no = vgui.Create("DButton", fr)
    no:SetSize(140, 34)
    no:SetPos(180, 120)
    no:SetText("No")
    no.DoClick = function()
        Dubz.SendGangAction({ cmd = "vote_war", choice = false, voteId = voteId })
        fr:Close()
    end

    timer.Simple(duration, function()
        if IsValid(fr) then fr:Close() end
    end)
end)

--------------------------------------------------------
-- WAR COUNTDOWN / BRIEFING
--------------------------------------------------------
net.Receive("Dubz_GangWar_Countdown", function()
    local g1    = net.ReadString()
    local g2    = net.ReadString()
    local secs  = net.ReadFloat()

    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    WarCountdown_Active = true
    WarCountdown_End    = CurTime() + secs
    WarCountdown_Enemy  = (Dubz.MyGangId == g1) and g2 or g1
end)

--------------------------------------------------------
-- WAR VOTE PROMPT
--------------------------------------------------------
net.Receive("Dubz_GangWar_VotePrompt", function()
    local voteId   = net.ReadString()
    local g1       = net.ReadString()
    local g2       = net.ReadString()
    local duration = net.ReadFloat()

    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    if IsValid(Dubz.WarVoteFrame) then Dubz.WarVoteFrame:Remove() end

    local enemy = (Dubz.MyGangId == g1) and g2 or g1

    local fr = vgui.Create("DFrame")
    fr:SetTitle("Gang War Vote")
    fr:SetSize(340, 180)
    fr:Center()
    fr:MakePopup()
    Dubz.WarVoteFrame = fr

    local lbl = vgui.Create("DLabel", fr)
    lbl:SetText(string.format("Vote to start a war with %s", enemy))
    lbl:SetFont("DubzHUD_Body")
    lbl:SizeToContents()
    lbl:SetPos(20, 40)

    local info = vgui.Create("DLabel", fr)
    info:SetFont("DubzHUD_Tag")
    info:SetText("Capture enemy territories and defend your own.")
    info:SizeToContents()
    info:SetPos(20, 64)

    local yes = vgui.Create("DButton", fr)
    yes:SetSize(140, 34)
    yes:SetPos(20, 120)
    yes:SetText("Yes, go to war")
    yes.DoClick = function()
        Dubz.SendGangAction({ cmd = "vote_war", choice = true, voteId = voteId })
        fr:Close()
    end

    local no = vgui.Create("DButton", fr)
    no:SetSize(140, 34)
    no:SetPos(180, 120)
    no:SetText("No")
    no.DoClick = function()
        Dubz.SendGangAction({ cmd = "vote_war", choice = false, voteId = voteId })
        fr:Close()
    end

    timer.Simple(duration, function()
        if IsValid(fr) then fr:Close() end
    end)
end)

--------------------------------------------------------
-- WAR COUNTDOWN / BRIEFING
--------------------------------------------------------
net.Receive("Dubz_GangWar_Countdown", function()
    local g1    = net.ReadString()
    local g2    = net.ReadString()
    local secs  = net.ReadFloat()

    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    WarCountdown_Active = true
    WarCountdown_End    = CurTime() + secs
    WarCountdown_Enemy  = (Dubz.MyGangId == g1) and g2 or g1
end)

--------------------------------------------------------
-- WAR VOTE PROMPT
--------------------------------------------------------
net.Receive("Dubz_GangWar_VotePrompt", function()
    local voteId   = net.ReadString()
    local g1       = net.ReadString()
    local g2       = net.ReadString()
    local duration = net.ReadFloat()

    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    if IsValid(Dubz.WarVoteFrame) then Dubz.WarVoteFrame:Remove() end

    local enemy = (Dubz.MyGangId == g1) and g2 or g1

    local fr = vgui.Create("DFrame")
    fr:SetTitle("Gang War Vote")
    fr:SetSize(340, 180)
    fr:Center()
    fr:MakePopup()
    Dubz.WarVoteFrame = fr

    local lbl = vgui.Create("DLabel", fr)
    lbl:SetText(string.format("Vote to start a war with %s", enemy))
    lbl:SetFont("DubzHUD_Body")
    lbl:SizeToContents()
    lbl:SetPos(20, 40)

    local info = vgui.Create("DLabel", fr)
    info:SetFont("DubzHUD_Tag")
    info:SetText("Capture enemy territories and defend your own.")
    info:SizeToContents()
    info:SetPos(20, 64)

    local yes = vgui.Create("DButton", fr)
    yes:SetSize(140, 34)
    yes:SetPos(20, 120)
    yes:SetText("Yes, go to war")
    yes.DoClick = function()
        Dubz.SendGangAction({ cmd = "vote_war", choice = true, voteId = voteId })
        fr:Close()
    end

    local no = vgui.Create("DButton", fr)
    no:SetSize(140, 34)
    no:SetPos(180, 120)
    no:SetText("No")
    no.DoClick = function()
        Dubz.SendGangAction({ cmd = "vote_war", choice = false, voteId = voteId })
        fr:Close()
    end

    timer.Simple(duration, function()
        if IsValid(fr) then fr:Close() end
    end)
end)

--------------------------------------------------------
-- WAR COUNTDOWN / BRIEFING
--------------------------------------------------------
net.Receive("Dubz_GangWar_Countdown", function()
    local g1    = net.ReadString()
    local g2    = net.ReadString()
    local secs  = net.ReadFloat()

    if Dubz.MyGangId ~= g1 and Dubz.MyGangId ~= g2 then return end

    WarCountdown_Active = true
    WarCountdown_End    = CurTime() + secs
    WarCountdown_Enemy  = (Dubz.MyGangId == g1) and g2 or g1
end)

--------------------------------------------------------
-- MAIN WAR HUD DRAW
--------------------------------------------------------
hook.Add("HUDPaint", "Dubz_GangWar_HUD", function()
    if not WarHUD_Active then return end
    if not Dubz.Gangs or not Dubz.MyGangId or Dubz.MyGangId == "" then return end

    local myGang   = Dubz.Gangs[WarHUD_MyGang]
    local enemyGang = Dubz.Gangs[WarHUD_Enemy]

    if not myGang or not enemyGang then return end

    -- Time remaining
    local remaining = math.max(0, WarHUD_EndTime - CurTime())
    if remaining <= 0 then
        WarHUD_Active = false
        return
    end

    local w = 450
    local h = 58
    local x = ScrW() / 2 - w / 2
    local y = 90

    -- Optional dynamic advantage bar using gang bank
    local myBank    = myGang.bank or 0
    local enemyBank = enemyGang.bank or 0
    local total     = myBank + enemyBank
    local ratio     = (total > 0) and (myBank / total) or 0.5

    WarHUD_Lerp = Lerp(FrameTime() * 6, WarHUD_Lerp, ratio)

    -------------------------------------------------------------------
    -- Background
    -------------------------------------------------------------------
    draw.RoundedBox(10, x, y, w, h, Color(0, 0, 0, 185))

    -------------------------------------------------------------------
    -- Foreground Progress Bar
    -------------------------------------------------------------------
    local col = Color(myGang.color.r, myGang.color.g, myGang.color.b, 230)
    draw.RoundedBox(10, x, y, w * WarHUD_Lerp, h, col)

    -------------------------------------------------------------------
    -- Labels
    -------------------------------------------------------------------
    local mins = math.floor(remaining / 60)
    local secs = math.floor(remaining % 60)

    draw.SimpleText(
        "War vs " .. enemyGang.name,
        "DubzHUD_Header",
        ScrW() / 2, y + 12,
        Color(255,255,255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        string.format("Time Left: %d:%02d", mins, secs),
        "DubzHUD_Small",
        ScrW() / 2, y + 35,
        Color(230,230,230),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
end)

--------------------------------------------------------
-- WAR COUNTDOWN HUD
--------------------------------------------------------
hook.Add("HUDPaint", "Dubz_GangWar_CountdownHUD", function()
    if not WarCountdown_Active then return end
    if not Dubz.MyGangId or Dubz.MyGangId == "" then return end

    local remain = math.max(0, WarCountdown_End - CurTime())
    if remain <= 0 then
        WarCountdown_Active = false
        return
    end

    local w, h = 480, 160
    local x = ScrW() / 2 - w / 2
    local y = ScrH() / 2 - h / 2

    draw.RoundedBox(12, x, y, w, h, Color(8, 8, 8, 220))
    draw.SimpleText("Gang War Incoming!", "DubzHUD_Title", x + w / 2, y + 24, Color(255,80,80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.format("Battle %s in %ds", WarCountdown_Enemy, math.ceil(remain)), "DubzHUD_Header", x + w / 2, y + 60, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText("Do: Capture enemy territories, defend your poles, back up your crew.", "DubzHUD_Tag", x + w / 2, y + 96, Color(220,220,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Don't: Teamkill allies or abandon objectives.", "DubzHUD_Tag", x + w / 2, y + 118, Color(200,200,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

--------------------------------------------------------
-- WAR COUNTDOWN HUD
--------------------------------------------------------
hook.Add("HUDPaint", "Dubz_GangWar_CountdownHUD", function()
    if not WarCountdown_Active then return end
    if not Dubz.MyGangId or Dubz.MyGangId == "" then return end

    local remain = math.max(0, WarCountdown_End - CurTime())
    if remain <= 0 then
        WarCountdown_Active = false
        return
    end

    local w, h = 480, 160
    local x = ScrW() / 2 - w / 2
    local y = ScrH() / 2 - h / 2

    draw.RoundedBox(12, x, y, w, h, Color(8, 8, 8, 220))
    draw.SimpleText("Gang War Incoming!", "DubzHUD_Title", x + w / 2, y + 24, Color(255,80,80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.format("Battle %s in %ds", WarCountdown_Enemy, math.ceil(remain)), "DubzHUD_Header", x + w / 2, y + 60, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText("Do: Capture enemy territories, defend your poles, back up your crew.", "DubzHUD_Tag", x + w / 2, y + 96, Color(220,220,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Don't: Teamkill allies or abandon objectives.", "DubzHUD_Tag", x + w / 2, y + 118, Color(200,200,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

--------------------------------------------------------
-- WAR COUNTDOWN HUD
--------------------------------------------------------
hook.Add("HUDPaint", "Dubz_GangWar_CountdownHUD", function()
    if not WarCountdown_Active then return end
    if not Dubz.MyGangId or Dubz.MyGangId == "" then return end

    local remain = math.max(0, WarCountdown_End - CurTime())
    if remain <= 0 then
        WarCountdown_Active = false
        return
    end

    local w, h = 480, 160
    local x = ScrW() / 2 - w / 2
    local y = ScrH() / 2 - h / 2

    draw.RoundedBox(12, x, y, w, h, Color(8, 8, 8, 220))
    draw.SimpleText("Gang War Incoming!", "DubzHUD_Title", x + w / 2, y + 24, Color(255,80,80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.format("Battle %s in %ds", WarCountdown_Enemy, math.ceil(remain)), "DubzHUD_Header", x + w / 2, y + 60, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText("Do: Capture enemy territories, defend your poles, back up your crew.", "DubzHUD_Tag", x + w / 2, y + 96, Color(220,220,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Don't: Teamkill allies or abandon objectives.", "DubzHUD_Tag", x + w / 2, y + 118, Color(200,200,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

--------------------------------------------------------
-- WAR COUNTDOWN HUD
--------------------------------------------------------
hook.Add("HUDPaint", "Dubz_GangWar_CountdownHUD", function()
    if not WarCountdown_Active then return end
    if not Dubz.MyGangId or Dubz.MyGangId == "" then return end

    local remain = math.max(0, WarCountdown_End - CurTime())
    if remain <= 0 then
        WarCountdown_Active = false
        return
    end

    local w, h = 480, 160
    local x = ScrW() / 2 - w / 2
    local y = ScrH() / 2 - h / 2

    draw.RoundedBox(12, x, y, w, h, Color(8, 8, 8, 220))
    draw.SimpleText("Gang War Incoming!", "DubzHUD_Title", x + w / 2, y + 24, Color(255,80,80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.format("Battle %s in %ds", WarCountdown_Enemy, math.ceil(remain)), "DubzHUD_Header", x + w / 2, y + 60, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText("Do: Capture enemy territories, defend your poles, back up your crew.", "DubzHUD_Tag", x + w / 2, y + 96, Color(220,220,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Don't: Teamkill allies or abandon objectives.", "DubzHUD_Tag", x + w / 2, y + 118, Color(200,200,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

