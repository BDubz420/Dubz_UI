AddCSLuaFile("dubz_menu/gangs/sh_gangs.lua")
include("dubz_menu/gangs/sh_gangs.lua")

util.AddNetworkString("Dubz_GangWar_Start")
util.AddNetworkString("Dubz_GangWar_Update")
util.AddNetworkString("Dubz_GangWar_End")

local CFG = Dubz.Config and Dubz.Config.Gangs or {}

local DATA_DIR = "dubz_ui"
local DATA_FILE = DATA_DIR .. "/gangs.json"

Dubz.GangByMember = Dubz.GangByMember or {} -- sid64 -> gangId

local function normalizeVec(tbl)
    if not istable(tbl) then return { x = 0, y = 0, z = 0 } end
    if tbl.x then
        return { x = tonumber(tbl.x) or 0, y = tonumber(tbl.y) or 0, z = tonumber(tbl.z) or 0 }
    elseif tbl[1] then
        return { x = tonumber(tbl[1]) or 0, y = tonumber(tbl[2]) or 0, z = tonumber(tbl[3]) or 0 }
    end
    return { x = 0, y = 0, z = 0 }
end

local function normalizeAng(tbl)
    if not istable(tbl) then return { p = 0, y = 0, r = 0 } end
    if tbl.p then
        return { p = tonumber(tbl.p) or 0, y = tonumber(tbl.y) or 0, r = tonumber(tbl.r) or 0 }
    elseif tbl[1] then
        return { p = tonumber(tbl[1]) or 0, y = tonumber(tbl[2]) or 0, r = tonumber(tbl[3]) or 0 }
    end
    return { p = 0, y = 0, r = 0 }
end

local function NormalizeTerritory(id, terr)
    if not istable(terr) then return nil end
    terr = terr or {}
    local data = {}
    data.id = tostring(terr.id or id or ("T" .. string.sub(util.CRC(SysTime() .. tostring(math.random())), 1, 8)))
    data.name = tostring(terr.name or terr.TerritoryName or "Territory")
    data.sprayer = tostring(terr.sprayer or terr.owner or "")
    data.time = tonumber(terr.time) or os.time()
    data.pos = normalizeVec(terr.pos or terr.position or {})
    data.ang = normalizeAng(terr.ang or terr.angles or {})
    return data
end

local function GangNotify(ply, msgType, length, msg)
    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, msgType, length, msg)
    else
        ply:ChatPrint(msg)
    end
end

-- Data normalizers ---------------------------------------------------
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

    local base = g.graffiti.color or g.color or { r=255, g=255, b=255 }
    g.graffiti.color = {
        r = math.Clamp(tonumber(base.r) or 255, 0, 255),
        g = math.Clamp(tonumber(base.g) or 255, 0, 255),
        b = math.Clamp(tonumber(base.b) or 255, 0, 255)
    }
end

local function SanitizeGang(gid, gang)
    if not istable(gang) then return nil end

    gang.id   = gang.id   or gid
    gang.name = tostring(gang.name or "Gang")
    gang.desc = tostring(gang.desc or "")

    gang.bank  = math.max(0, tonumber(gang.bank) or 0)
    gang.color = gang.color or { r = 255, g = 255, b = 255 }
    gang.leaderSid64 = Dubz.GetSID64(gang.leaderSid64)

    local sanitizedMembers = {}
    gang.members = gang.members or {}
    for sid64, member in pairs(gang.members) do
        if istable(member) then
            local strSid = Dubz.GetSID64(sid64)
            if strSid and strSid ~= "" then
                sanitizedMembers[strSid] = {
                    name   = tostring(member.name or "Member"),
                    rank   = math.Clamp(tonumber(member.rank) or Dubz.GangRanks.Member, 1, Dubz.GangRanks.Leader),
                    joined = tonumber(member.joined) or os.time()
                }
            end
        end
    end
    if gang.leaderSid64 and gang.leaderSid64 ~= "" and not sanitizedMembers[gang.leaderSid64] then
        sanitizedMembers[gang.leaderSid64] = {
            name   = tostring(gang.leaderName or gang.name or "Leader"),
            rank   = Dubz.GangRanks.Leader,
            joined = os.time()
        }
    end
    gang.members = sanitizedMembers

    gang.rankTitles = gang.rankTitles or table.Copy(Dubz.DefaultRankTitles)

    local terrs = {}
    if istable(gang.territories) then
        for key, terr in pairs(gang.territories) do
            local norm = NormalizeTerritory(key, terr)
            if norm and norm.id ~= "" then
                terrs[norm.id] = norm
            end
        end
    end
    gang.territories = terrs

    NormalizeGraffiti(gang)

    return gang
end

local function RebuildGangByMember()
    Dubz.GangByMember = {}

    for gid, gang in pairs(Dubz.Gangs or {}) do
        if istable(gang.members) then
            for sid64, _ in pairs(gang.members) do
                local strSid = Dubz.GetSID64(sid64)
                if strSid and strSid ~= "" then
                    Dubz.GangByMember[strSid] = gid
                end
            end
        elseif gang.leaderSid64 then
            local strSid = Dubz.GetSID64(gang.leaderSid64)
            if strSid and strSid ~= "" then
                Dubz.GangByMember[strSid] = gid
                gang.members = gang.members or {}
                gang.members[strSid] = gang.members[strSid] or {
                    name   = tostring(gang.leaderName or gang.name or "Leader"),
                    rank   = Dubz.GangRanks.Leader,
                    joined = os.time()
                }
            end
        end
    end
end

local function BuildSaveBlob()
    local blob = { version = 1, gangs = {} }

    for gid, gang in pairs(Dubz.Gangs or {}) do
        blob.gangs[gid] = table.Copy(gang)
        SanitizeGang(gid, blob.gangs[gid])

        -- runtime-only data that should never persist between restarts
        blob.gangs[gid].territories = nil
        blob.gangs[gid].wars = nil
    end

    return blob
end

function AddGangTerritory(gid, info)
    if not gid or gid == "" then return nil end
    if not Dubz.Gangs or not Dubz.Gangs[gid] then return nil end
    local g = Dubz.Gangs[gid]
    g.territories = g.territories or {}

    local terr = NormalizeTerritory(nil, info)
    if not terr then return nil end

    while g.territories[terr.id] do
        terr.id = "T" .. string.sub(util.CRC(SysTime() .. tostring(math.random())), 1, 8)
    end

    g.territories[terr.id] = terr
    SaveGangs()
    BroadcastUpdate(gid)

    if Dubz.Log then
        Dubz.Log(string.format("%s claimed territory '%s' for %s", terr.sprayer or "Unknown", terr.name or terr.id, g.name or gid), "INFO", "TERRITORY")
    end

    return terr.id
end

function RemoveGangTerritory(gid, target)
    if not gid or gid == "" then return end
    if not Dubz.Gangs or not Dubz.Gangs[gid] then return end
    local g = Dubz.Gangs[gid]
    if not g.territories then return end

    local removed
    for id, terr in pairs(g.territories) do
        if id == target or (istable(terr) and (terr.name == target)) then
            g.territories[id] = nil
            removed = terr
        end
    end

    if removed then
        SaveGangs()
        BroadcastUpdate(gid)
        if Dubz.Log then
            Dubz.Log(string.format("Territory '%s' removed from %s", removed.name or target, g.name or gid), "WARN", "TERRITORY")
        end
    end
end

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

function SaveGangs()
    if not istable(Dubz.Gangs) then
        Dubz.Gangs = {}
    end

    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end

    local ok, blob = pcall(BuildSaveBlob)
    if not ok then
        print("[Dubz Gangs] Failed to build gangs save blob:", blob)
        return
    end

    local encoded = util.TableToJSON(blob, true)
    if not encoded then
        print("[Dubz Gangs] Failed to encode gangs for saving!")
        return
    end

    file.Write(DATA_FILE, encoded)

    print(string.format("[Dubz Gangs] Saved %d gangs to %s", table.Count(blob.gangs or {}), DATA_FILE))

    RebuildGangByMember()
    RefreshGangNWForAll()
end

local function ExtractGangTable(tbl)
    if not istable(tbl) then return {} end
    if istable(tbl.gangs) then return tbl.gangs end
    return tbl
end

-- FIXED LoadGangs (ensures graffiti exists BEFORE any sync happens)
function LoadGangs()
    if file.Exists(DATA_FILE, "DATA") then
        local raw = file.Read(DATA_FILE, "DATA") or "{}"
        local ok, decoded = pcall(util.JSONToTable, raw)
        if ok and istable(decoded) then
            Dubz.Gangs = ExtractGangTable(decoded)
            print(string.format("[Dubz Gangs] Parsed gangs file '%s'", DATA_FILE))
        else
            print("[Dubz Gangs] Failed to parse gangs file, starting fresh.")
            Dubz.Gangs = {}
        end
    else
        Dubz.Gangs = {}
    end

    for gid, g in pairs(Dubz.Gangs) do
        if not SanitizeGang(gid, g) then
            Dubz.Gangs[gid] = nil
        else
            g.territories = {}
            g.wars = {}
            print(string.format("[Dubz Gangs] Loaded gang %-20s members=%d bank=%s", gid, table.Count(g.members or {}), tostring(g.bank or 0)))
        end
    end

    RebuildGangByMember()
    RefreshGangNWForAll()

    print(string.format("[Dubz Gangs] Finished load, %d gangs active",
        table.Count(Dubz.Gangs)))
end

hook.Add("Initialize","Dubz_Gangs_Load_Fixed", function()
    timer.Simple(1, function()
        LoadGangs()
        print("[Dubz Gangs] Loaded", table.Count(Dubz.Gangs or {}), "gangs.")
    end)
end)


-- Sync helpers
function SendFullSync(ply)
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

    local r = 0
    if g and g.members and g.members[sid] then
        r = g.members[sid].rank or 1
    end
    print(string.format("[Dubz Gangs] MyStatus -> %s gid=%s rank=%d", ply:Nick(), gid or "", r or 0))

    net.Start("Dubz_Gang_MyStatus")
        net.WriteString(gid or "")
        net.WriteUInt(r, 3)
    net.Send(ply)
end

function BroadcastUpdate(gid)
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

        local leaderSid = gang.leaderSid64
        if leaderSid and leaderSid ~= "" then
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:SteamID64() == leaderSid then
                    if DarkRP and DarkRP.notify then
                        DarkRP.notify(ply, 0, 6, string.format("Territory income added $%d to the gang bank.", bankAmount))
                    else
                        ply:ChatPrint(string.format("[Gang] Territory income added $%d to the gang bank.", bankAmount))
                    end
                end
            end
        end
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
    for gid, g in pairs(Dubz.Gangs or {}) do
        Dubz.RichestGangs[g.name or gid] = math.max(0, tonumber(g.networth) or 0)
    end
end

Dubz.RebuildRichestGangs = RebuildRichestGangs
_G.RebuildRichestGangs = RebuildRichestGangs

----------------------------------------------------------------------
-- GANG WEALTH CALCULATOR (ONLINE + OFFLINE + BANK)
----------------------------------------------------------------------

local function ComputeGangWealth(gid, g)
    if not g then return end

    local clean = 0
    local dirty = 0

    ------------------------------------------------------
    -- ONLINE MEMBERS — LIVE MONEY
    ------------------------------------------------------
    for sid64, m in pairs(g.members or {}) do
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:SteamID64() == sid64 then
                clean = clean + math.max(0, (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0)
                if ply.GetDirtyMoney then
                    dirty = dirty + math.max(0, ply:GetDirtyMoney())
                end
            end
        end
    end

    ------------------------------------------------------
    -- OFFLINE MEMBERS — CACHED SNAPSHOT
    ------------------------------------------------------
    if g._CachedWealth then
        for sid64, dat in pairs(g._CachedWealth) do
            local online = false
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:SteamID64() == sid64 then
                    online = true
                    break
                end
            end

            if not online then
                clean = clean + math.max(0, tonumber(dat.clean) or 0)
                dirty = dirty + math.max(0, tonumber(dat.dirty) or 0)
            end
        end
    end

    ------------------------------------------------------
    -- BANK
    ------------------------------------------------------
    local bank = math.max(0, tonumber(g.bank) or 0)

    ------------------------------------------------------
    -- FINAL VALUES
    ------------------------------------------------------
    g.cleanMoney = clean
    g.dirtyMoney = dirty
    g.networth   = clean + dirty + bank
end


-- Recompute for all gangs
function Dubz.RecomputeAllGangWealth()
    for gid, g in pairs(Dubz.Gangs or {}) do
        ComputeGangWealth(gid, g)
    end
end

-- Auto refresh every 30s
timer.Create("Dubz_GangWealth_Ticker", 30, 0, function()
    Dubz.RecomputeAllGangWealth()
    for gid, g in pairs(Dubz.Gangs or {}) do
        BroadcastUpdate(gid)
    end
end)

local function FullResync(ply)
    if not IsValid(ply) then return end

    -- Send full gangs table
    SendFullSync(ply)

    -- And send their personal gang status again to ensure client cache is correct
    local sid = ply:SteamID64()
    local gid = Dubz.GangByMember[sid]
    local rank = 0

    if gid and Dubz.Gangs[gid] and Dubz.Gangs[gid].members and Dubz.Gangs[gid].members[sid] then
        rank = Dubz.Gangs[gid].members[sid].rank or 1
    end

    net.Start("Dubz_Gang_MyStatus")
        net.WriteString(gid or "")
        net.WriteUInt(rank, 3)
    net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "Dubz_Gangs_ExtraSync", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        FullResync(ply)
    end)
end)

hook.Add("PlayerSpawn", "Dubz_Gangs_FinalSpawnSync", function(ply)
    timer.Simple(0.3, function()
        if not IsValid(ply) then return end
        FullResync(ply)
    end)
end)

hook.Add("PlayerLoadout", "Dubz_Gangs_LoadoutSync", function(ply)
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        FullResync(ply)
    end)
end)

hook.Add("PlayerFullyLoaded", "Dubz_Gangs_PlayerFullyLoadedSync", function(ply)
    timer.Simple(0.2, function()
        if IsValid(ply) then
            FullResync(ply)
        end
    end)
end)

hook.Add("playerFullyLoaded", "Dubz_Gangs_playerFullyLoadedSync_DarkRP", function(ply)
    timer.Simple(0.2, function()
        if IsValid(ply) then
            FullResync(ply)
        end
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

local function PromoteNewLeader(gid)
    local g = Dubz.Gangs[gid]
    if not g or not g.members then return end

    local candidatesByRank = {}
    local highestRank = 0

    for sid, m in pairs(g.members) do
        local r = m.rank or Dubz.GangRanks.Member
        if r > highestRank then
            highestRank = r
            candidatesByRank = { sid }
        elseif r == highestRank then
            table.insert(candidatesByRank, sid)
        end
    end

    if #candidatesByRank == 0 then
        return
    end

    local newLeaderSid

    if highestRank <= Dubz.GangRanks.Member then
        -- Everyone is just a Member -> pick randomly
        newLeaderSid = candidatesByRank[math.random(#candidatesByRank)]
    else
        -- Higher ranks exist: pick the oldest join date among the highest rank
        local bestSid = candidatesByRank[1]
        local bestJoined = g.members[bestSid].joined or os.time()

        for _, sid in ipairs(candidatesByRank) do
            local joined = g.members[sid].joined or os.time()
            if joined < bestJoined then
                bestSid = sid
                bestJoined = joined
            end
        end

        newLeaderSid = bestSid
    end

    if not newLeaderSid then return end

    g.leaderSid64 = newLeaderSid
    g.members[newLeaderSid].rank = Dubz.GangRanks.Leader

    print(string.format("[Dubz Gangs] New leader for %s is %s", tostring(gid), tostring(newLeaderSid)))
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

local function BroadcastGangBanner(gid, text, col)
    if not gid or gid == "" or not text or text == "" then return end
    local recipients = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and Dubz.GangByMember[ply:SteamID64()] == gid then
            table.insert(recipients, ply)
        end
    end
    if #recipients == 0 then return end

    net.Start("Dubz_Gang_Banner")
        net.WriteString(text)
        net.WriteColor(col or Color(255,255,255))
    net.Send(recipients)
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
        if not CanAfford(ply, CFG.StartCost or 0) then
            GangNotify(ply, 1, 5, "You cannot afford to create a gang.")
            return
        end
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

            wars = {
                active = false,
                enemy  = nil
            },

            allowWars = true
        }

        Dubz.GangByMember[sid] = gid

        GangNotify(ply, 0, 4, "Gang created successfully!")

        SaveGangs()
        RebuildRichestGangs()
        BroadcastUpdate(gid)
        SendFullSync(ply)
        return
    end

    local gid = Dubz.GangByMember[sid]

    -- LEAVE
    if act.cmd == "leave" and gid then
        local g = Dubz.Gangs[gid]
        if not g then return end

        if g.members then
            g.members[sid] = nil
        end

        Dubz.GangByMember[sid] = nil

        local remaining = 0
        for _ in pairs(g.members or {}) do
            remaining = remaining + 1
        end

        if remaining == 0 then
            Dubz.Gangs[gid] = nil
            for m,_ in pairs(Dubz.GangByMember) do
                if Dubz.GangByMember[m] == gid then
                    Dubz.GangByMember[m] = nil
                end
            end

            SaveGangs()
            RebuildRichestGangs()

            net.Start("Dubz_Gang_Update")
                net.WriteString(gid)
                net.WriteTable({})
            net.Broadcast()

            GangNotify(ply, 3, 5, "You left the gang. The gang has been disbanded.")
            return
        end

        if g.leaderSid64 == sid then
            PromoteNewLeader(gid)
            GangNotify(ply, 2, 5, "You left your gang. A new leader has been chosen.")
        else
            GangNotify(ply, 0, 4, "You left your gang.")
        end

        SaveGangs()
        RebuildRichestGangs()
        BroadcastUpdate(gid)
        SendFullSync(ply)

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

        hook.Run("Dubz_Gang_Disbanded", gid)

        Dubz.Gangs[gid] = nil

        for m,_ in pairs(Dubz.GangByMember) do
            if Dubz.GangByMember[m] == gid then
                Dubz.GangByMember[m] = nil
            end
        end

        SaveGangs()
        RebuildRichestGangs()

        net.Start("Dubz_Gang_Update")
            net.WriteString(gid)
            net.WriteTable({})
        net.Broadcast()

        GangNotify(ply, 3, 5, "You disbanded your gang.")

        return
    end

    -- INVITE
    if act.cmd == "invite" and gid and CanInvite(ply, gid) then
        local target = act.target and player.GetBySteamID64(tostring(act.target)) or nil
        if not IsValid(target) then
            GangNotify(ply, 1, 4, "Invalid target.")
            return
        end

        local g = Dubz.Gangs[gid]
        local max = CFG.MaxMembers or 12
        local count = 0
        for _ in pairs(g.members or {}) do count = count + 1 end
        if count >= max then
            GangNotify(ply, 1, 5, "Your gang is full.")
            return
        end

        SendInvite(target, ply, gid)

        GangNotify(ply, 0, 4, "Invite sent!")

        return
    end

    if act.cmd == "accept_invite" then
        local inv = PendingInvites[sid]
        if not inv or inv.expire < CurTime() then
            PendingInvites[sid] = nil
            return
        end

        if Dubz.GangByMember[sid] then
            PendingInvites[sid] = nil
            return
        end

        local g = Dubz.Gangs[inv.gid]
        if not g then
            PendingInvites[sid] = nil
            return
        end

        local max = CFG.MaxMembers or 12
        local count = 0
        for _ in pairs(g.members or {}) do count = count + 1 end
        if count >= max then
            PendingInvites[sid] = nil
            return
        end

        g.members[sid] = { name = ply:Nick(), rank = Dubz.GangRanks.Member, joined = os.time() }
        Dubz.GangByMember[sid] = inv.gid
        PendingInvites[sid] = nil

        SaveGangs()
        RebuildRichestGangs()
        BroadcastUpdate(inv.gid)
        SendFullSync(ply)

        GangNotify(ply, 0, 4, "You joined the gang!")

        return
    end
    if act.cmd == "decline_invite" then
        PendingInvites[sid] = nil
        GangNotify(ply, 0, 4, "You turned down the gang invite.")
        return
    end

    if (act.cmd == "promote" or act.cmd == "demote" or act.cmd == "kick") and gid and IsLeader(ply, gid) then
        local targetSid = Dubz.GetSID64(act.target or "")
        local g = Dubz.Gangs[gid]
        if not g or not targetSid or not g.members or not g.members[targetSid] then return end
        if targetSid == sid then return end

        if act.cmd == "kick" then
            local kickedName = g.members[targetSid] and g.members[targetSid].name or "A member"
            g.members[targetSid] = nil
            Dubz.GangByMember[targetSid] = nil
            BroadcastGangBanner(gid, kickedName .. " was removed", Color(255,120,120))

            GangNotify(ply, 1, 4, "Member removed from the gang.")
        else
            local cur = g.members[targetSid].rank or 1
            if act.cmd == "promote" then
                g.members[targetSid].rank = math.Clamp(cur + 1, 1, Dubz.GangRanks.Leader - 1)
                GangNotify(ply, 0, 4, "Member promoted.")
            else
                g.members[targetSid].rank = math.Clamp(cur - 1, 1, Dubz.GangRanks.Leader - 1)
                GangNotify(ply, 0, 4, "Member demoted.")
            end
        end

        SaveGangs()
        BroadcastUpdate(gid)
        return
    end

    if act.cmd == "setranktitle" and gid and IsLeader(ply, gid) then
        local r = tonumber(act.rank or 0) or 0
        local titleMax = CFG.RankTitleMaxLength or 20
        local title = string.sub(tostring(act.title or ""), 1, titleMax)
        local g = Dubz.Gangs[gid]; if not g then return end

        g.rankTitles = g.rankTitles or table.Copy(Dubz.DefaultRankTitles)

        if r >= 1 and r <= 3 and title ~= "" then
            g.rankTitles[r] = title

            SaveGangs()
            BroadcastUpdate(gid)

            GangNotify(ply, 0, 4, "Rank title updated.")

        end
        return
    end

    if act.cmd == "setdesc" and gid and IsLeader(ply, gid) then
        local g = Dubz.Gangs[gid]; if not g then return end

        local descMax = CFG.DescMaxLength or 160
        local newDesc = tostring(act.desc or ""):Trim()

        g.desc = string.sub(newDesc, 1, descMax)

        SaveGangs()
        BroadcastUpdate(gid)

        GangNotify(ply, 0, 4, "Gang description updated.")

        return
    end

    -- COLOR (leader only)
    if act.cmd == "setcolor" and gid and IsLeader(ply, gid) then
        local g = Dubz.Gangs[gid]; if not g then return end

        local c = act.color or {}
        local r = math.Clamp(tonumber(c.r) or 200, 0, 255)
        local gVal = math.Clamp(tonumber(c.g) or 200, 0, 255)
        local b = math.Clamp(tonumber(c.b) or 200, 0, 255)

        g.color = { r = r, g = gVal, b = b }

        if g.graffiti then
            g.graffiti.color = { r = r, g = gVal, b = b }
        end

        SaveGangs()
        BroadcastUpdate(gid)

        GangNotify(ply, 0, 4, "Gang color updated.")

        return
    end

    -- BANK
    if CFG.BankEnabled and gid then
        if act.cmd == "deposit" and (CFG.AllowDeposit ~= false) then
            local amt = math.max(0, math.floor(tonumber(act.amount or 0) or 0))
            if amt <= 0 or not CanAfford(ply, amt) then
                GangNotify(ply, 1, 4, "Invalid deposit amount.")
                return
            end

            TakeMoney(ply, amt)
            local g = Dubz.Gangs[gid]
            g.bank = math.max(0, (g.bank or 0) + amt)

            SaveGangs()
            RebuildRichestGangs()
            BroadcastUpdate(gid)

            GangNotify(ply, 0, 4, "Deposited $" .. amt .. " into gang bank.")

            return
        end

        if act.cmd == "withdraw" and CanWithdrawFromBank(ply, gid) then
            local amt = math.max(0, math.floor(tonumber(act.amount or 0) or 0))
            local g = Dubz.Gangs[gid]
            if amt <= 0 or (g.bank or 0) < amt then
                GangNotify(ply, 1, 4, "Invalid withdraw amount.")
                return
            end

            g.bank = (g.bank or 0) - amt
            AddMoney(ply, amt)

            SaveGangs()
            RebuildRichestGangs()
            BroadcastUpdate(gid)

            GangNotify(ply, 0, 4, "Withdrew $" .. amt .. " from gang bank.")

            return
        end
    end

    -------------------------------------------------
    -- GRAFFITI TEXT (leader)
    --------------------------------------------------
    if act.cmd == "setgraffiti" and gid and IsLeader(ply, gid) then
        local g = Dubz.Gangs[gid]
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
        -- FONT
        --------------------------------------------------
        if act.font and act.font ~= "" then
            g.graffiti.font = tostring(act.font)
        end

        --------------------------------------------------
        -- SCALE + SCALED FONT NAME
        --------------------------------------------------
        if act.scale then
            g.graffiti.scale = tonumber(act.scale) or 1
        end

        if act.fontScaled and act.fontScaled ~= "" then
            g.graffiti.fontScaled = tostring(act.fontScaled)
        else
            g.graffiti.fontScaled = "DubzGraffiti_Font_" .. math.floor((g.graffiti.scale or 1) * 100)
        end

        --------------------------------------------------
        -- EFFECT
        --------------------------------------------------
        if act.effect then
            g.graffiti.effect = tostring(act.effect)
        end

        --------------------------------------------------
        -- CUSTOM COLOR
        --------------------------------------------------
        if istable(act.color) then
            g.graffiti.color = {
                r = math.Clamp(tonumber(act.color.r) or 255, 0, 255),
                g = math.Clamp(tonumber(act.color.g) or 255, 0, 255),
                b = math.Clamp(tonumber(act.color.b) or 255, 0, 255)
            }
        elseif g.color then
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

        GangNotify(ply, 0, 4, "Graffiti updated successfully.")

        return
    end

    -- WARS (non-persistent basic system)
    if CFG.Wars and CFG.Wars.Enabled then
        if act.cmd == "declare_war" and gid and IsLeader(ply, gid) then
            local enemy = tostring(act.enemy or "")
            if not Dubz.Gangs[enemy] or enemy == gid then
                GangNotify(ply, 1, 5, "Invalid enemy gang.")
                return
            end

            local g = Dubz.Gangs[gid]

            -- Checks
            local members = 0
            for _ in pairs(g.members or {}) do members = members + 1 end
            if members < (CFG.Wars.MinMembers or 3) then
                GangNotify(ply, 1, 5, "Your gang does not meet minimum member requirement.")
                return
            end

            if not CanAfford(ply, CFG.Wars.DeclareCost or 0) then
                GangNotify(ply, 1, 5, "You cannot afford to start a gang war.")
                return
            end

            TakeMoney(ply, CFG.Wars.DeclareCost or 0)

            g.wars = g.wars or {}
            g.wars.active = true
            g.wars.enemy = enemy
            g.wars.started = CurTime()
            g.wars.ends = CurTime() + (CFG.Wars.Duration or 1800)

            local e = Dubz.Gangs[enemy]
            e.wars = e.wars or {}
            e.wars.active = true
            e.wars.enemy = gid
            e.wars.started = g.wars.started
            e.wars.ends = g.wars.ends

            SaveGangs()
            BroadcastUpdate(gid)
            BroadcastUpdate(enemy)

            -- NEW: War HUD Start
            net.Start("Dubz_GangWar_Start")
                net.WriteString(gid)
                net.WriteString(enemy)
                net.WriteFloat(g.wars.ends)
            net.Broadcast()

            GangNotify(ply, 0, 5, "War declared against " .. (e.name or enemy) .. "!")

            return
        end

        if act.cmd == "accept_war" and gid and IsLeader(ply, gid) then
            -- already “active” on both when declared; keep for UI parity if you want a pending state.
            return
        end

        if act.cmd == "forfeit_war" and gid and IsLeader(ply, gid) then
            local g = Dubz.Gangs[gid]
            if not g or not g.wars or not g.wars.active then
                GangNotify(ply, 1, 5, "Your gang is not currently in a war.")
                return
            end

            local enemy = g.wars.enemy
            local e = Dubz.Gangs[enemy]
            if not e then return end

            local tribute = math.floor((g.bank or 0) * (CFG.Wars.TributePercent or 0.1))

            g.bank = math.max(0, (g.bank or 0) - tribute)
            e.bank = math.max(0, (e.bank or 0) + tribute)

            g.wars = {}
            e.wars = {}

            SaveGangs()
            RebuildRichestGangs()
            BroadcastUpdate(gid)
            BroadcastUpdate(enemy)

            net.Start("Dubz_GangWar_End")
                net.WriteString(gid)
            net.Broadcast()

            net.Start("Dubz_GangWar_End")
                net.WriteString(enemy)
            net.Broadcast()

            GangNotify(ply, 1, 6, "Your gang forfeited the war and paid tribute.")

            return
        end

        -- Auto-end wars by time (think)
        hook.Add("Think", "Dubz_Gangs_WarTicker", function()
            for gid, g in pairs(Dubz.Gangs) do
                if g.wars and g.wars.active and (g.wars.ends or 0) <= CurTime() then

                    local enemy = g.wars.enemy
                    local e = Dubz.Gangs[enemy]

                    if e then
                        local tributeFrom, tributeTo = g, e

                        if (g.bank or 0) >= (e.bank or 0) then
                            tributeFrom, tributeTo = e, g
                        end

                        local tribute = math.floor((tributeFrom.bank or 0) *
                            (CFG.Wars.TributePercent or 0.1))

                        tributeFrom.bank = math.max(0, (tributeFrom.bank or 0) - tribute)
                        tributeTo.bank = math.max(0, (tributeTo.bank or 0) + tribute)

                        g.wars = {}
                        e.wars = {}

                        SaveGangs()
                        RebuildRichestGangs()
                        BroadcastUpdate(gid)
                        BroadcastUpdate(enemy)

                        -- END HUD for both
                        net.Start("Dubz_GangWar_End")
                            net.WriteString(gid)
                        net.Broadcast()

                        net.Start("Dubz_GangWar_End")
                            net.WriteString(enemy)
                        net.Broadcast()

                        -- Notify only the leaders
                        for _, ply in ipairs(player.GetAll()) do
                            if IsValid(ply) then
                                local sid = ply:SteamID64()
                                if sid == g.leaderSid64 then
                                    GangNotify(ply, 0, 5, "Your war has ended!")
                                elseif sid == e.leaderSid64 then
                                    GangNotify(ply, 0, 5, "Your war has ended!")
                                end
                            end
                        end

                    else
                        g.wars = {}
                        SaveGangs()
                        BroadcastUpdate(gid)

                        net.Start("Dubz_GangWar_End")
                            net.WriteString(gid)
                        net.Broadcast()
                    end
                end
            end
        end)
    end
end)

hook.Add("PlayerDisconnected", "Dubz_Gang_CacheWealth", function(ply)
    local sid = ply:SteamID64()
    local gid = Dubz.GangByMember[sid]
    if not gid or not Dubz.Gangs[gid] then return end

    local g = Dubz.Gangs[gid]
    g._CachedWealth = g._CachedWealth or {}

    g._CachedWealth[sid] = {
        clean = math.max(0, (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0),
        dirty = math.max(0, ply.GetDirtyMoney and ply:GetDirtyMoney() or 0)
    }

    Dubz.RecomputeAllGangWealth()
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
