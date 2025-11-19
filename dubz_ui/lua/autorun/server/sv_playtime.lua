-- Persistent playtime + live NW2 for UI (no frequent nettable spam needed)

util.AddNetworkString("Dubz_Playtime_Backfill") -- optional one-shot for late joiners

local DATA_FILE = "dubz_playtime_data.txt"
local totals = {}

-- Load saved totals
if file.Exists(DATA_FILE, "DATA") then
    local raw = file.Read(DATA_FILE, "DATA")
    local ok, tbl = pcall(util.JSONToTable, raw or "")
    if ok and istable(tbl) then totals = tbl end
end

local function SaveTotals()
    file.Write(DATA_FILE, util.TableToJSON(totals, true))
end

-- When player spawns, set base + join time as NW2 for live UI
hook.Add("PlayerInitialSpawn", "Dubz_Playtime_Init", function(ply)
    local sid64 = ply:SteamID64()
    local base = totals[sid64] or 0

    ply.Dubz_JoinTime = CurTime()
    ply:SetNW2Float("Dubz_JoinTime", ply.Dubz_JoinTime)
    ply:SetNW2Float("Dubz_TotalBase", base)

    -- small backfill ping for clients already open
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        net.Start("Dubz_Playtime_Backfill")
            net.WriteEntity(ply)
            net.WriteFloat(base)
            net.WriteFloat(ply.Dubz_JoinTime)
        net.Broadcast()
    end)
end)

-- On disconnect, fold session into total and save
hook.Add("PlayerDisconnected", "Dubz_Playtime_Save", function(ply)
    local sid64 = ply:SteamID64()
    if not sid64 then return end
    local join = ply.Dubz_JoinTime or CurTime()
    local session = CurTime() - join
    totals[sid64] = (totals[sid64] or 0) + session
    SaveTotals()
end)

-- Periodic autosave in case of crash/mapchange
timer.Create("Dubz_Playtime_AutoSave", 300, 0, SaveTotals)
