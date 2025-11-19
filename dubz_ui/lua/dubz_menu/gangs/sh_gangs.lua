Dubz = Dubz or {}
Dubz.Gangs = Dubz.Gangs or {} -- server: authoritative; client: replicated snapshot

-- Rank values: higher = more power
Dubz.GangRanks = {
    Member  = 1,
    Officer = 2,
    Leader  = 3,
}
Dubz.DefaultRankTitles = {
    [1] = "Member",
    [2] = "Officer",
    [3] = "Leader",
}

-- Net
if SERVER then
    util.AddNetworkString("Dubz_Gang_FullSync")       -- full snapshot for a player
    util.AddNetworkString("Dubz_Gang_MyStatus")      -- your gangId + rank
    util.AddNetworkString("Dubz_Gang_Update")        -- delta updates
    util.AddNetworkString("Dubz_Gang_Invite")        -- invite popup to target
    util.AddNetworkString("Dubz_Gang_Action")        -- client->server actions
end

-- Helpers (shared)
function Dubz.GetSID64(plyOrId)
    if isentity(plyOrId) and plyOrId.SteamID64 then return plyOrId:SteamID64() end
    if isstring(plyOrId) then
        if tonumber(plyOrId) then return tostring(math.floor(tonumber(plyOrId))) end
        if string.find(plyOrId, "STEAM_") and util and util.SteamIDTo64 then
            local ok, sid = pcall(util.SteamIDTo64, plyOrId); if ok and sid ~= "0" then return sid end
        end
        return plyOrId
    end
    return nil
end

function Dubz.GangIsLeader(gang, sid64)
    if not gang or not sid64 then return false end
    local m = gang.members and gang.members[sid64]
    return m and (m.rank or 1) >= Dubz.GangRanks.Leader
end

function Dubz.GangIsOfficer(gang, sid64)
    if not gang or not sid64 then return false end
    local m = gang.members and gang.members[sid64]
    return m and (m.rank or 1) >= Dubz.GangRanks.Officer
end

function Dubz.GangGetTitle(gang, rank)
    local rt = (gang and gang.rankTitles) or Dubz.DefaultRankTitles
    return rt[rank] or Dubz.DefaultRankTitles[rank] or "Member"
end
