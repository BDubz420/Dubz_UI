AddCSLuaFile("dubz_menu/gangs/sh_gangs.lua")
include("dubz_menu/gangs/sh_gangs.lua")

local CFG = Dubz.Config and Dubz.Config.Gangs or {}

local DATA_DIR = "dubz_ui"
local DATA_FILE = DATA_DIR .. "/gangs.json"

Dubz.GangByMember = Dubz.GangByMember or {} -- sid64 -> gangId

-- Keep NW vars in sync so HUD / overhead / menus can read gang name + color
local function RefreshGangNWForAll()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local sid = ply:SteamID64()
        local gid = Dubz.GangByMember[sid]
        local g = gid and Dubz.Gangs and Dubz.Gangs[gid] or nil

        local name, vec
        if g then
            local c = g.color or { r = 255, g = 255, b = 255 }
            name = g.name or ""
            vec = Vector((c.r or 255) / 255, (c.g or 255) / 255, (c.b or 255) / 255)
        else
            name = ""
            vec = Vector(1, 1, 1)
        end

        ply:SetNWString("DubzGang", name)
        ply:SetNWVector("DubzGangColor", vec)
    end
end

local function SaveGangs()
    print("[Dubz Gangs] SaveGangs() called")

    if not file.IsDir(DATA_DIR, "DATA") then
        print("[Dubz Gangs] Creating data directory…")
        file.CreateDir(DATA_DIR)
    end

    for gid, g in pairs(Dubz.Gangs or {}) do
        print("[Dubz Gangs] Saving gang:", gid)
        NormalizeGraffiti(g)
    end

    local json = util.TableToJSON(Dubz.Gangs or {}, true)
    print("[Dubz Gangs] Final JSON to save:", json)

    file.Write(DATA_FILE, json)

    print("[Dubz Gangs] Save complete.")
    RefreshGangNWForAll()
end

-- FIXED LoadGangs (ensures graffiti exists BEFORE any sync happens)
local function LoadGangs()
    print("[Dubz Gangs] LoadGangs() called")

    if file.Exists(DATA_FILE, "DATA") then
        local raw = file.Read(DATA_FILE, "DATA") or "{}"
        print("[Dubz Gangs] Raw file content:", raw)

        Dubz.Gangs = util.JSONToTable(raw) or {}
        print("[Dubz Gangs] Loaded", table.Count(Dubz.Gangs), "gangs from file.")
    else
        print("[Dubz Gangs] No gangs file found, starting fresh.")
        Dubz.Gangs = {}
    end

    -- **ENSURE GRAFFITI EXISTS BEFORE ANYTHING ELSE**
    for gid, g in pairs(Dubz.Gangs) do
        print("[Dubz Gangs] Normalize on load:", gid)
        NormalizeGraffiti(g)
    end

    -- Rebuild GangByMember AFTER graffiti is valid
    timer.Simple(0, function()
        print("[Dubz Gangs] Rebuilding GangByMember index…")

        Dubz.GangByMember = {}
        for gid, g in pairs(Dubz.Gangs) do
            if g.members then
                for sid,_ in pairs(g.members) do
                    Dubz.GangByMember[sid] = gid
                    print(" • Member", sid, "→ Gang", gid)
                end
            end
        end
    end)
end
hook.Add("Initialize","Dubz_Gangs_Load_Fixed", function()
    timer.Simple(1, function()
        print("[Dubz Gangs] Loading gang data…")
        LoadGangs()
        print("[Dubz Gangs] Loaded", table.Count(Dubz.Gangs), "gangs.")
    end)
end)

-- Ensures graffiti table exists and has all required fields
local function NormalizeGraffiti(g)
    g.graffiti = g.graffiti or {}

    local name = g.name or "Gang"

    g.graffiti.text   = g.graffiti.text   or name
    g.graffiti.font   = g.graffiti.font   or "Trebuchet24"
    g.graffiti.scale  = tonumber(g.graffiti.scale) or 1
    g.graffiti.effect = g.graffiti.effect or "Clean"

    g.graffiti.fontScaled =
        g.graffiti.fontScaled or
        ("DubzGraffiti_Font_" .. math.floor((g.graffiti.scale or 1) * 100))

    local c = g.color or { r=255, g=255, b=255 }
    g.graffiti.color = {
        r = c.r or 255,
        g = c.g or 255,
        b = c.b or 255
    }
end

-- Sync helpers
local function SendFullSync(ply)
    if not IsValid(ply) then return end

    -- Make a CLEAN COPY of the gangs table
    local toSend = {}

    for gid, g in pairs(Dubz.Gangs or {}) do
        NormalizeGraffiti(g)

        -- Copy AFTER normalizing
        toSend[gid] = table.Copy(g)
    end

    print("[Dubz Gangs] Sending full sync to", ply:Nick(), "with", table.Count(toSend), "gangs")

    net.Start("Dubz_Gang_FullSync")
        net.WriteTable(toSend)
    net.Send(ply)

    --------------------------------------------
    -- Player personal gang status + NW vars
    --------------------------------------------
    local sid = ply:SteamID64()
    local gid = Dubz.GangByMember[sid]
    local g   = gid and Dubz.Gangs[gid] or nil

    local name, vec
    if g then
        local c = g.color or { r = 255, g = 255, b = 255 }
        name = g.name or ""
        vec = Vector((c.r or 255) / 255, (c.g or 255) / 255, (c.b or 255) / 255)
    else
        name = ""
        vec = Vector(1, 1, 1)
    end

    ply:SetNWString("DubzGang", name)
    ply:SetNWVector("DubzGangColor", vec)

    net.Start("Dubz_Gang_MyStatus")
        net.WriteString(gid or "")
        local r = 0
        if g and g.members and g.members[sid] then
            r = g.members[sid].rank or 1
        end
        net.WriteUInt(r, 3)
    net.Send(ply)
end

local function BroadcastUpdate(gid)
    if Dubz.Gangs[gid] then
        NormalizeGraffiti(Dubz.Gangs[gid])
    end

    net.Start("Dubz_Gang_Update")
        net.WriteString(gid)
        net.WriteTable(Dubz.Gangs[gid] or {})
    net.Broadcast()
end

-- TERRITORY PAYOUT HANDLER
hook.Add("Dubz_Gang_TerritoryPayout", "Dubz_Gang_TerritoryPayout_Handler", function(gangId, ent, total, onlineMembers)
    if not gangId or not Dubz.Gangs or not Dubz.Gangs[gangId] then return end

    local TCFG = Dubz.Config and Dubz.Config.Territories or {}
    local incomeCfg = TCFG.Income or {}
    if incomeCfg.Enabled == false then return end

    total = math.max(0, tonumber(total) or 0)
    if total <= 0 then return end

    local gang = Dubz.Gangs[gangId]
    onlineMembers = onlineMembers or {}

    local bankFrac    = incomeCfg.GangBankShare or 0.8
    local memberFrac  = incomeCfg.MemberShare or 0.2

    -- clamp so they don't exceed 1.0
    local sumFrac = bankFrac + memberFrac
    if sumFrac > 1 then
        bankFrac   = bankFrac   / sumFrac
        memberFrac = memberFrac / sumFrac
    end

    local bankAmount   = math.floor(total * bankFrac)
    local membersTotal = math.floor(total * memberFrac)

    --------------------------------------------------
    -- Gang bank
    --------------------------------------------------
    if bankAmount > 0 and (Dubz.Config.Gangs.BankEnabled ~= false) then
        gang.bank = math.max(0, (gang.bank or 0) + bankAmount)
        SaveGangs()
        RebuildRichestGangs()
        BroadcastUpdate(gangId)
    end

    --------------------------------------------------
    -- Online members share
    --------------------------------------------------
    if membersTotal > 0 and incomeCfg.GiveOnlineMembers ~= false and #onlineMembers > 0 then
        local per = math.floor(membersTotal / #onlineMembers)
        if per > 0 then
            for _, ply in ipairs(onlineMembers) do
                if IsValid(ply) then
                    AddMoney(ply, per)
                end
            end
        end
    end
end)

-- update dashboard richest gangs (keeps your dashboard in sync)
local function RebuildRichestGangs()
    Dubz.RichestGangs = {}
    for gid, g in pairs(Dubz.Gangs) do
        Dubz.RichestGangs[g.name or gid] = math.floor(tonumber(g.bank or 0) or 0)
    end
end

hook.Add("PlayerInitialSpawn","Dubz_Gangs_InitSync", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then SendFullSync(ply) end
    end)
end)

-- Utility
local function NewGangId()
    return "G" .. math.floor(os.time()) .. "_" .. string.sub(util.CRC(SysTime() .. math.random()), 1, 6)
end

local function EnsureGang(gid)
    return gid and Dubz.Gangs[gid]
end

-- Permissions
local function IsLeader(ply, gid)
    local sid = ply:SteamID64()
    local g = EnsureGang(gid)
    return g and Dubz.GangIsLeader(g, sid)
end

local function IsOfficer(ply, gid) -- used for optional invite perms
    local sid = ply:SteamID64()
    local g = EnsureGang(gid)
    return g and Dubz.GangIsOfficer(g, sid)
end

local function CanInvite(ply, gid)
    if not CFG.AllowOfficerInvite then
        return IsLeader(ply, gid)
    end
    local sid = ply:SteamID64()
    local g = EnsureGang(gid)
    if not g or not g.members then return false end
    local m = g.members[sid]
    return m and (m.rank or 1) >= Dubz.GangRanks.Officer
end

local function CanWithdrawFromBank(ply, gid)
    if not CFG.BankEnabled then return false end

    local minRankName = CFG.MinBankWithdrawRank or "Leader"
    local minRank = Dubz.GangRanks[minRankName] or Dubz.GangRanks.Leader

    local sid = ply:SteamID64()
    local g = EnsureGang(gid)
    if not g or not g.members then return false end

    local m = g.members[sid]
    local r = m and (m.rank or 1) or 0
    return r >= minRank
end

-- MONEY helpers
local function CanAfford(ply, amt)
    if DarkRP and ply.canAfford then return ply:canAfford(amt) end
    local m = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
    return m >= amt
end
local function AddMoney(ply, amt)
    if DarkRP and ply.addMoney then ply:addMoney(amt) return end
    -- fallback local var
    ply._Dubz_Money = (ply._Dubz_Money or 0) + amt
end
local function TakeMoney(ply, amt)
    if DarkRP and ply.addMoney then ply:addMoney(-math.abs(amt)) return end
    ply._Dubz_Money = (ply._Dubz_Money or 0) - math.abs(amt)
end

-- INVITES
local PendingInvites = {} -- targetSid64 -> {from=leaderSid64, gid=gid, expire=time}

local function SendInvite(target, fromPly, gid)
    local sidT = target:SteamID64()
    PendingInvites[sidT] = {
        from = fromPly:SteamID64(),
        gid = gid,
        expire = CurTime() + (CFG.InviteExpire or 120)
    }
    net.Start("Dubz_Gang_Invite")
        net.WriteString(gid)
        net.WriteString(Dubz.Gangs[gid].name or "Gang")
        net.WriteString(fromPly:Nick() or "Leader")
    net.Send(target)
end

-- MAIN ACTIONS (client -> server)
-- action: {cmd= "create/leave/disband/invite/accept/decline/promote/demote/kick/deposit/withdraw/setranktitle/setdesc/setcolor/declare_war/accept_war/forfeit_war"}
net.Receive("Dubz_Gang_Action", function(_, ply)
    if not CFG.Enabled then return end
    local act = net.ReadTable() or {}
    local sid = ply:SteamID64()

    -- CREATE
    if act.cmd == "create" then
        if Dubz.GangByMember[sid] then return end

        local nameMax = CFG.NameMaxLength or 24
        local descMax = CFG.DescMaxLength or 160

        local name = string.sub(tostring(act.name or ""), 1, nameMax)
        local col  = act.color or {r=37,g=150,b=190}
        local desc = string.sub(tostring(act.desc or ""), 1, descMax)

        -- Money check
        if not CanAfford(ply, CFG.StartCost or 0) then return end
        TakeMoney(ply, CFG.StartCost or 0)

        local gid = NewGangId()

        Dubz.Gangs[gid] = {
            id = gid,
            name = name ~= "" and name or ("Gang " .. string.sub(gid,-4)),
            color = {r=col.r or 255, g=col.g or 255, b=col.b or 255},
            desc = desc,
            leaderSid64 = sid,
            created = os.time(),
            bank = 0,

            rankTitles = table.Copy(Dubz.DefaultRankTitles),

            members = {
                [sid] = {
                    name   = ply:Nick(),
                    rank   = Dubz.GangRanks.Leader,
                    joined = os.time()
                }
            },

            -- No active war initially
            wars = {
                active = false,
                enemy  = nil
            },

            -- NEW FIELD (default TRUE)
            allowWars = true
        }

        Dubz.GangByMember[sid] = gid

        SaveGangs()
        RebuildRichestGangs()
        BroadcastUpdate(gid)
        SendFullSync(ply)
        return
    end

    local gid = Dubz.GangByMember[sid]

    -- LEAVE
    if act.cmd == "leave" and gid then
        local g = Dubz.Gangs[gid]; if not g then return end
        if g.leaderSid64 == sid then
            -- leader leaving: if alone -> disband; else deny
            local count = 0; for _ in pairs(g.members or {}) do count = count + 1 end
            if count <= 1 then
                Dubz.Gangs[gid] = nil
                for m,_ in pairs(Dubz.GangByMember) do if Dubz.GangByMember[m] == gid then Dubz.GangByMember[m] = nil end end
                SaveGangs(); RebuildRichestGangs()
                net.Start("Dubz_Gang_Update") net.WriteString(gid) net.WriteTable({}) net.Broadcast()
            else
                -- deny; leader must /disband or /promote someone first
                return
            end
        else
            g.members[sid] = nil
            Dubz.GangByMember[sid] = nil
            SaveGangs(); RebuildRichestGangs()
            BroadcastUpdate(gid); SendFullSync(ply)
        end
        return
    end

    -- TOGGLE GANG WARS
    if act.cmd == "set_war_toggle" and gid and IsLeader(ply, gid) then
        local g = Dubz.Gangs[gid]
        if not g then return end

        local enabled = act.enabled
        if enabled == nil then enabled = true end

        g.allowWars = enabled and true or false

        SaveGangs()
        BroadcastUpdate(gid)
        return
    end

    -- DISBAND (leader)
    if act.cmd == "disband" and gid and IsLeader(ply, gid) then
        Dubz.Gangs[gid] = nil
        for m,_ in pairs(Dubz.GangByMember) do if Dubz.GangByMember[m] == gid then Dubz.GangByMember[m] = nil end end
        SaveGangs(); RebuildRichestGangs()
        net.Start("Dubz_Gang_Update") net.WriteString(gid) net.WriteTable({}) net.Broadcast()
        return
    end

    -- INVITE (leader only as requested)
    if act.cmd == "invite" and gid and CanInvite(ply, gid) then
        local target = act.target and player.GetBySteamID64(tostring(act.target)) or nil
        if not IsValid(target) then return end
        local g = Dubz.Gangs[gid]
        local max = CFG.MaxMembers or 12
        local count = 0; for _ in pairs(g.members or {}) do count = count + 1 end
        if count >= max then return end
        SendInvite(target, ply, gid)
        return
    end

    -- ACCEPT / DECLINE invite
    if act.cmd == "accept_invite" then
        local inv = PendingInvites[sid]; if not inv or inv.expire < CurTime() then PendingInvites[sid]=nil return end
        if Dubz.GangByMember[sid] then PendingInvites[sid]=nil return end
        local g = Dubz.Gangs[inv.gid]; if not g then PendingInvites[sid]=nil return end
        local max = CFG.MaxMembers or 12
        local count = 0; for _ in pairs(g.members or {}) do count = count + 1 end
        if count >= max then PendingInvites[sid]=nil return end
        g.members[sid] = {name=ply:Nick(), rank=Dubz.GangRanks.Member, joined=os.time()}
        Dubz.GangByMember[sid] = inv.gid
        PendingInvites[sid] = nil
        SaveGangs(); RebuildRichestGangs()
        BroadcastUpdate(inv.gid)
        SendFullSync(ply)
        return
    end
    if act.cmd == "decline_invite" then
        PendingInvites[sid] = nil
        return
    end

    -- PROMOTE/DEMOTE/KICK (leader only)
    if (act.cmd == "promote" or act.cmd == "demote" or act.cmd == "kick") and gid and IsLeader(ply, gid) then
        local targetSid = Dubz.GetSID64(act.target or "")
        local g = Dubz.Gangs[gid]; if not g or not targetSid or not g.members or not g.members[targetSid] then return end
        if targetSid == sid then return end
        if act.cmd == "kick" then
            g.members[targetSid] = nil
            Dubz.GangByMember[targetSid] = nil
        else
            local cur = g.members[targetSid].rank or 1
            if act.cmd == "promote" then
                g.members[targetSid].rank = math.Clamp(cur + 1, 1, Dubz.GangRanks.Leader - 1) -- cannot promote to Leader
            else
                g.members[targetSid].rank = math.Clamp(cur - 1, 1, Dubz.GangRanks.Leader - 1)
            end
        end
        SaveGangs(); BroadcastUpdate(gid)
        return
    end

    -- RANK TITLE EDIT (leader)
    if act.cmd == "setranktitle" and gid and IsLeader(ply, gid) then
        local r = tonumber(act.rank or 0) or 0
        local titleMax = CFG.RankTitleMaxLength or 20
        local title = string.sub(tostring(act.title or ""), 1, titleMax)
        local g = Dubz.Gangs[gid]; if not g then return end
        g.rankTitles = g.rankTitles or table.Copy(Dubz.DefaultRankTitles)
        if r >= 1 and r <= 3 and title ~= "" then
            g.rankTitles[r] = title
            SaveGangs(); BroadcastUpdate(gid)
        end
        return
    end

    -- DESC (leader only)
    if act.cmd == "setdesc" and gid and IsLeader(ply, gid) then
        local g = Dubz.Gangs[gid]; if not g then return end

        local descMax = CFG.DescMaxLength or 160
        local newDesc = tostring(act.desc or ""):Trim()

        -- Enforce limit
        g.desc = string.sub(newDesc, 1, descMax)

        SaveGangs()
        BroadcastUpdate(gid)
        return
    end

    -- COLOR (leader only)
    if act.cmd == "setcolor" and gid and IsLeader(ply, gid) then
        local g = Dubz.Gangs[gid]; if not g then return end

        local c = act.color or {}
        local r = tonumber(c.r) or 200
        local gVal = tonumber(c.g) or 200
        local b = tonumber(c.b) or 200

        -- Clamp values to safe ranges
        r = math.Clamp(r, 0, 255)
        gVal = math.Clamp(gVal, 0, 255)
        b = math.Clamp(b, 0, 255)

        g.color = {
            r = r,
            g = gVal,
            b = b
        }

        -- ALSO update graffiti color instantly (if your graffiti system uses g.color)
        if g.graffiti then
            g.graffiti.color = { r = r, g = gVal, b = b }
        end

        SaveGangs()
        BroadcastUpdate(gid)
        return
    end

    -- BANK
    if CFG.BankEnabled and gid then
        if act.cmd == "deposit" and (CFG.AllowDeposit ~= false) then
            local amt = math.max(0, math.floor(tonumber(act.amount or 0) or 0))
            if amt <= 0 or not CanAfford(ply, amt) then return end
            TakeMoney(ply, amt)
            local g = Dubz.Gangs[gid]; g.bank = math.max(0, (g.bank or 0) + amt)
            SaveGangs(); RebuildRichestGangs(); BroadcastUpdate(gid); return
        end
        if act.cmd == "withdraw" and CanWithdrawFromBank(ply, gid) then
            local amt = math.max(0, math.floor(tonumber(act.amount or 0) or 0))
            local g = Dubz.Gangs[gid]; if amt <= 0 or (g.bank or 0) < amt then return end
            g.bank = (g.bank or 0) - amt
            AddMoney(ply, amt)
            SaveGangs(); RebuildRichestGangs(); BroadcastUpdate(gid); return
        end
    end

    --------------------------------------------------
    -- GRAFFITI TEXT (leader)
    --------------------------------------------------
    if act.cmd == "setgraffiti" and gid and IsLeader(ply, gid) then
        local g = Dubz.Gangs[gid]; 
        if not g then return end

        g.graffiti = g.graffiti or {}

        --------------------------------------------------
        -- TEXT
        --------------------------------------------------
        local maxLen = (Dubz.Config and Dubz.Config.Graffiti and Dubz.Config.Graffiti.MaxTextLength) or 24
        local txt = tostring(act.text or "")
        txt = string.Trim(txt)
        txt = string.sub(txt, 1, maxLen)
        g.graffiti.text = txt

        --------------------------------------------------
        -- FONT (base font name)
        --------------------------------------------------
        if act.font and act.font ~= "" then
            g.graffiti.font = tostring(act.font)
        end

        --------------------------------------------------
        -- FONT SCALE + SCALED FONT NAME
        --------------------------------------------------
        if act.scale then
            g.graffiti.scale = tonumber(act.scale) or 1
        end

        if act.fontScaled and act.fontScaled ~= "" then
            g.graffiti.fontScaled = tostring(act.fontScaled)
        else
            -- fallback: auto-generate name
            g.graffiti.fontScaled = "DubzGraffiti_Font_" .. math.floor((g.graffiti.scale or 1) * 100)
        end

        --------------------------------------------------
        -- EFFECT (shadow, outline, etc.)
        --------------------------------------------------
        if act.effect then
            g.graffiti.effect = tostring(act.effect)
        end

        --------------------------------------------------
        -- BACKGROUND MATERIAL
        --------------------------------------------------
        if act.bgMat then
            g.graffiti.bgMat = tostring(act.bgMat)
        end

        --------------------------------------------------
        -- COLOR SYNC WITH GANG COLOR
        --------------------------------------------------
        if g.color then
            g.graffiti.color = {
                r = g.color.r or 255,
                g = g.color.g or 255,
                b = g.color.b or 255
            }
        end

        --------------------------------------------------
        -- SAVE + BROADCAST
        --------------------------------------------------
        SaveGangs()
        BroadcastUpdate(gid)
        return
    end

    -- WARS
    if CFG.Wars and CFG.Wars.Enabled then
        if act.cmd == "declare_war" and gid and IsLeader(ply, gid) then
            local enemy = tostring(act.enemy or "")
            if not Dubz.Gangs[enemy] or enemy == gid then return end
            local g = Dubz.Gangs[gid]
            -- checks
            local members = 0 for _ in pairs(g.members or {}) do members = members + 1 end
            if members < (CFG.Wars.MinMembers or 3) then return end
            if not CanAfford(ply, CFG.Wars.DeclareCost or 0) then return end
            TakeMoney(ply, CFG.Wars.DeclareCost or 0)

            g.wars = g.wars or {}
            g.wars.active = true
            g.wars.enemy = enemy
            g.wars.started = CurTime()
            g.wars.ends = CurTime() + (CFG.Wars.Duration or 1800)

            local e = Dubz.Gangs[enemy]; e.wars = e.wars or {}
            e.wars.active = true
            e.wars.enemy = gid
            e.wars.started = g.wars.started
            e.wars.ends = g.wars.ends

            SaveGangs(); BroadcastUpdate(gid); BroadcastUpdate(enemy)
            return
        end

        if act.cmd == "accept_war" and gid and IsLeader(ply, gid) then
            -- already “active” on both when declared; keep for UI parity if you want a pending state.
            return
        end

        if act.cmd == "forfeit_war" and gid and IsLeader(ply, gid) then
            local g = Dubz.Gangs[gid]; if not g or not g.wars or not g.wars.active then return end
            local enemy = g.wars.enemy; local e = Dubz.Gangs[enemy]; if not e then return end

            -- tribute to enemy
            local tribute = math.floor((g.bank or 0) * (CFG.Wars.TributePercent or 0.1))
            g.bank = math.max(0, (g.bank or 0) - tribute)
            e.bank = math.max(0, (e.bank or 0) + tribute)

            g.wars = {}; e.wars = {}
            SaveGangs(); RebuildRichestGangs(); BroadcastUpdate(gid); BroadcastUpdate(enemy)
            return
        end

        -- Auto-end wars by time (think)
        hook.Add("Think","Dubz_Gangs_WarTicker", function()
            for gid, g in pairs(Dubz.Gangs) do
                if g.wars and g.wars.active and (g.wars.ends or 0) <= CurTime() then
                    local enemy = g.wars.enemy
                    local e = Dubz.Gangs[enemy]
                    if e then
                        -- winner = higher bank at end
                        local tributeFrom, tributeTo = g, e
                        if (g.bank or 0) >= (e.bank or 0) then
                            tributeFrom, tributeTo = e, g
                        end
                        local tribute = math.floor((tributeFrom.bank or 0) * (CFG.Wars.TributePercent or 0.1))
                        tributeFrom.bank = math.max(0, (tributeFrom.bank or 0) - tribute)
                        tributeTo.bank = math.max(0, (tributeTo.bank or 0) + tribute)
                        g.wars = {}; e.wars = {}
                        SaveGangs(); RebuildRichestGangs(); BroadcastUpdate(gid); BroadcastUpdate(enemy)
                    else
                        g.wars = {}; SaveGangs(); BroadcastUpdate(gid)
                    end
                end
            end
        end)
    end
end)

util.AddNetworkString("Dubz_Gang_RequestSync")

net.Receive("Dubz_Gang_RequestSync", function(_, ply)
    if not IsValid(ply) then return end
    timer.Simple(0.1, function()
        if IsValid(ply) then
            net.Start("Dubz_Gang_FullSync")
                net.WriteTable(Dubz.Gangs or {})
            net.Send(ply)

            local sid = ply:SteamID64()
            net.Start("Dubz_Gang_MyStatus")
                net.WriteString(Dubz.GangByMember[sid] or "")
                local gid = Dubz.GangByMember[sid]
                local r = 0
                if gid and Dubz.Gangs[gid] and Dubz.Gangs[gid].members and Dubz.Gangs[gid].members[sid] then
                    r = Dubz.Gangs[gid].members[sid].rank or 1
                end
                net.WriteUInt(r, 3)
            net.Send(ply)
        end
    end)
end)