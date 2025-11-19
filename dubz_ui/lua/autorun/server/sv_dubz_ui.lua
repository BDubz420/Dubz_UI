if SERVER then

    --------------------------------------------------------
    -- 1. AddCSLuaFile all CLIENT + SHARED gang files
    --------------------------------------------------------
    local files = {
        "autorun/dubz_ui_config.lua",
        "autorun/client/cl_dubz_ui.lua",
        "dubz_ui/themes.lua",
        "dubz_hud/cl_hud.lua",
        "dubz_menu/cl_menu.lua",
        "dubz_menu/tabs/cl_tab_dashboard.lua",
        "dubz_menu/tabs/cl_tab_players.lua",
        "dubz_menu/tabs/cl_tab_jobs.lua",
        "dubz_menu/tabs/cl_tab_market.lua",
        "dubz_menu/tabs/cl_tab_gangs.lua",
        "dubz_menu/gangs/sh_gangs.lua",
        "dubz_menu/cl_admin.lua",
        "dubz_menu/ui_helpers.lua",
        "dubz_overhead/cl_overhead.lua",
        "dubz_vote/cl_dubz_vote.lua",
        "dubz_vote/sh_dubz_vote.lua",
        "dubz_notifications/cl_notifications.lua"
    }
    for _, p in ipairs(files) do AddCSLuaFile(p) end

    --------------------------------------------------------
    -- LOAD SERVER VOTE LOGIC
    --------------------------------------------------------    

    include("dubz_vote/sh_dubz_vote.lua")
    include("dubz_vote/sv_dubz_vote.lua")

    --------------------------------------------------------
    -- TERRITORY SYSTEM
    -------------------------------------------------------- 
    AddCSLuaFile("entities/ent_dubz_graffiti_spot.lua")

    --------------------------------------------------------
    -- 2. LOAD SERVER GANG LOGIC
    --------------------------------------------------------
    include("dubz_menu/gangs/sv_gangs.lua")
    include("dubz_menu/gangs/sh_gangs.lua")

    --------------------------------------------------------
    -- 3. RICHEST DATA NETWORK STRING
    --------------------------------------------------------
    util.AddNetworkString("Dubz_RichestSync")

    --------------------------------------------------------
    -- 4. LEADERBOARD PERSISTENCE
    --------------------------------------------------------
    local DIR = "dubz_ui"
    local PATH = DIR.."/leaderboards.json"

    local function safeRead()
        if not file.Exists(DIR, "DATA") then file.CreateDir(DIR) end
        if not file.Exists(PATH, "DATA") then return { players = {}, gangs = {} } end
        local raw = file.Read(PATH, "DATA")
        local ok, tbl = pcall(util.JSONToTable, raw or "{}")
        if ok and istable(tbl) then
            tbl.players = tbl.players or {}
            tbl.gangs   = tbl.gangs or {}
            return tbl
        end
        return { players = {}, gangs = {} }
    end

    local function safeWrite(tbl)
        if not file.Exists(DIR, "DATA") then file.CreateDir(DIR) end
        file.Write(PATH, util.TableToJSON(tbl or {players={}, gangs={}}, true))
    end

    local function gatherPlayers()
        local out = {}
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            local sid64 = ply:SteamID64()
            local money = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
            out[sid64] = {
                name = ply:Nick(),
                money = math.floor(tonumber(money) or 0)
            }
        end
        return out
    end

    local function gatherGangs()
        if not (Dubz.Config and Dubz.Config.Gangs and Dubz.Config.Gangs.Enabled) then return {} end
        local gangs = {}
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            local g = ply:GetNWString("DubzGang","")
            if g ~= "" then
                local money = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
                gangs[g] = (gangs[g] or 0) + math.floor(tonumber(money) or 0)
            end
        end
        return gangs
    end

    local function broadcast()
        local blob = safeRead()
        local json = util.TableToJSON(blob)
        local comp = util.Compress(json or "{}")
        net.Start("Dubz_RichestSync")
            net.WriteUInt(#comp, 16)
            net.WriteData(comp, #comp)
        net.Broadcast()
    end

    local function recomputeAndSave()
        local blob = safeRead()

        -- merge online players
        for sid64, dat in pairs(gatherPlayers()) do
            blob.players[sid64] = blob.players[sid64] or {}
            blob.players[sid64].name = dat.name
            blob.players[sid64].money = dat.money
        end

        blob.gangs = gatherGangs()

        safeWrite(blob)
        broadcast()
    end

    hook.Add("PlayerInitialSpawn","DubzLB_Send", function(ply)
        timer.Simple(2, function()
            if not IsValid(ply) then return end
            local blob = safeRead()
            local json = util.TableToJSON(blob)
            local comp = util.Compress(json or "{}")
            net.Start("Dubz_RichestSync")
                net.WriteUInt(#comp, 16)
                net.WriteData(comp, #comp)
            net.Send(ply)
        end)
    end)

    hook.Add("PlayerDisconnected","DubzLB_SaveOnLeave", function()
        timer.Simple(0.5, function() recomputeAndSave() end)
    end)

    timer.Create("DubzLB_Auto", 30, 0, function() recomputeAndSave() end)

    --------------------------------------------------------
    -- RICHEST SNAPSHOT
    --------------------------------------------------------
    Dubz.RichestPlayers = Dubz.RichestPlayers or {}

    local function SaveRichest()
        if not file.IsDir("dubz_ui", "DATA") then file.CreateDir("dubz_ui") end
        file.Write("dubz_ui/richest_players.txt", util.TableToJSON(Dubz.RichestPlayers, true))
    end

    local function LoadRichest()
        if file.Exists("dubz_ui/richest_players.txt", "DATA") then
            Dubz.RichestPlayers = util.JSONToTable(file.Read("dubz_ui/richest_players.txt", "DATA") or "{}") or {}
        end
    end

    hook.Add("Initialize", "Dubz_LoadRichest", LoadRichest)

    hook.Add("PlayerDisconnected", "Dubz_SaveMoneyOnLeave", function(ply)
        local sid64 = ply:SteamID64()
        local m = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
        Dubz.RichestPlayers[sid64] = {
            name = ply:Nick(),
            money = math.floor(tonumber(m) or 0)
        }
        SaveRichest()
    end)

    timer.Create("Dubz_PeriodicRichestSnapshot", 60, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local sid64 = ply:SteamID64()
                local m = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
                Dubz.RichestPlayers[sid64] = {
                    name = ply:Nick(),
                    money = math.floor(tonumber(m) or 0)
                }
            end
        end
        SaveRichest()
    end)

end
