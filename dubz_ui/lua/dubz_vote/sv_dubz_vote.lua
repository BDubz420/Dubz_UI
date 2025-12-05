----------------------------------------
-- DUBZ VOTE SYSTEM (SERVER SIDE)
-- FINAL PATCHED VERSION
----------------------------------------

Dubz = Dubz or {}
Dubz.Vote = Dubz.Vote or {}
Dubz.Vote.Active = Dubz.Vote.Active or {}
Dubz.Vote.Types  = Dubz.Vote.Types or {}
Dubz.Vote.Config = Dubz.Vote.Config or {}

util.AddNetworkString("Dubz_Vote_Start")
util.AddNetworkString("Dubz_Vote_Cast")
util.AddNetworkString("Dubz_Vote_End")

----------------------------------------
-- Utility Money Helpers
----------------------------------------
local function PlayerCanAfford(ply, amt)
    amt = math.floor(tonumber(amt) or 0)
    if amt <= 0 then return true end

    if DarkRP and ply.canAfford then
        return ply:canAfford(amt)
    end

    local money = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or ply._Dubz_Money or 0
    return money >= amt
end

local function TakePlayerMoney(ply, amt)
    amt = math.abs(math.floor(tonumber(amt) or 0))
    if amt <= 0 then return end

    if DarkRP and ply.addMoney then
        ply:addMoney(-amt)
    else
        ply._Dubz_Money = (ply._Dubz_Money or 0) - amt
    end
end

local function GivePlayerMoney(ply, amt)
    amt = math.floor(tonumber(amt) or 0)
    if amt == 0 then return end

    if DarkRP and ply.addMoney then
        ply:addMoney(amt)
    else
        ply._Dubz_Money = (ply._Dubz_Money or 0) + amt
    end
end

----------------------------------------
-- Time
----------------------------------------
local function GetRemainingTime(vote)
    if not vote or not vote.endTime then return 0 end
    return math.Clamp(math.ceil(math.max(0, vote.endTime - CurTime())), 0, 255)
end

----------------------------------------
-- Networking
----------------------------------------
local function SendVoteStart(vote, target)
    if not vote then return end

    net.Start("Dubz_Vote_Start")
        net.WriteString(vote.id)
        net.WriteString(vote.question)
        net.WriteUInt(#vote.options, 8)

        for _, opt in ipairs(vote.options) do
            net.WriteString(opt)
        end

        net.WriteUInt(math.max(1, GetRemainingTime(vote)), 8)
    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

local function BroadcastVoteEnd(id, counts, winner, cancelled)
    net.Start("Dubz_Vote_End")
        net.WriteString(id)
        net.WriteUInt(#counts, 8)
        for _, c in ipairs(counts) do
            net.WriteUInt(math.Clamp(c, 0, 4095), 12)
        end
        net.WriteUInt(math.Clamp(winner, 0, 255), 8)
        net.WriteBool(cancelled or false)
    net.Broadcast()
end

----------------------------------------
-- Universal Vote Finish
----------------------------------------
local function FinishVote(id, vote, opts)
    Dubz.Vote.Active[id] = nil
    if not vote then return end

    local counts = {}
    for i = 1, #vote.options do
        counts[i] = 0
    end

    for ply, choice in pairs(vote.votes or {}) do
        if IsValid(ply) and counts[choice] ~= nil then
            counts[choice] = counts[choice] + 1
        end
    end

    -- determine winner
    local top = -1
    local winner = 0
    local tie = false

    for i, c in ipairs(counts) do
        if c > top then
            top = c
            winner = i
            tie = false
        elseif c == top then
            tie = true
        end
    end

    if top <= 0 or tie then
        winner = 0
    end

    local cancelled = opts and opts.cancelled

    -- log
    if cancelled then
        local msg = ("Vote '%s' cancelled (%s)"):format(id, opts.reason or "cancelled")
        if Dubz.Log then Dubz.Log(msg, "WARN", "VOTE") end
    else
        local msg = ("Vote '%s' finished. Winner = %d (%s)"):format(
            id, winner, vote.options[winner] or "none"
        )
        if Dubz.Log then Dubz.Log(msg, "INFO", "VOTE") end
    end

    -- call vote handler
    if not cancelled then
        local handler = Dubz.Vote.Types[vote.vtype or "generic"]
        if handler and handler.OnFinish then
            handler.OnFinish(vote, counts, winner)
        end
    end

    BroadcastVoteEnd(id, counts, winner, cancelled)
end

----------------------------------------
-- Registration
----------------------------------------
function Dubz.Vote.RegisterType(name, def)
    Dubz.Vote.Types[name] = def
end

function Dubz.Vote.Cancel(id, reason)
    local v = Dubz.Vote.Active[id]
    if not v then return false end
    FinishVote(id, v, { cancelled = true, reason = reason })
    return true
end

----------------------------------------
-- Start a Vote
----------------------------------------
function Dubz.Vote.Start(id, data)
    if not isstring(id) or id == "" then return end
    if not istable(data) then return end
    if not data.question or not istable(data.options) or #data.options == 0 then return end

    -- auto-replace existing vote
    if Dubz.Vote.Active[id] then
        Dubz.Vote.Cancel(id, "restarted")
    end

    local opts = {}
    for _, o in ipairs(data.options) do
        opts[#opts + 1] = tostring(o or "Option")
    end

    local dur = math.Clamp(math.floor(tonumber(data.duration) or 15), 5, 255)

    Dubz.Vote.Active[id] = {
        id       = id,
        question = data.question,
        options  = opts,
        endTime  = CurTime() + dur,
        votes    = {},
        duration = dur,
        vtype    = data.type or "generic",
        payload  = data.payload or {},
        started  = CurTime()
    }

    SendVoteStart(Dubz.Vote.Active[id])
end

----------------------------------------
-- Auto Skip if All Players Voted
----------------------------------------
local function CheckInstantFinish(id, vote)
    local totalPlayers = 0
    local voted = 0

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            totalPlayers = totalPlayers + 1
        end
    end

    for ply,_ in pairs(vote.votes) do
        if IsValid(ply) then
            voted = voted + 1
        end
    end

    if totalPlayers > 0 and voted >= totalPlayers then
        FinishVote(id, vote)
    end
end

----------------------------------------
-- Receive Player Vote
----------------------------------------
net.Receive("Dubz_Vote_Cast", function(_, ply)
    local id = net.ReadString()
    local choice = net.ReadUInt(8)

    local v = Dubz.Vote.Active[id]
    if not v then return end
    if CurTime() >= v.endTime then return end
    if choice < 1 or choice > #v.options then return end

    v.votes[ply] = choice
    CheckInstantFinish(id, v)
end)

----------------------------------------
-- Cleanup / Think
----------------------------------------
hook.Add("Think", "Dubz_Vote_Think", function()
    for id, v in pairs(Dubz.Vote.Active) do
        if CurTime() >= v.endTime then
            FinishVote(id, v)
        end
    end
end)

hook.Add("PlayerInitialSpawn", "Dubz_Vote_SendActive", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end

        for _, v in pairs(Dubz.Vote.Active) do
            if GetRemainingTime(v) > 0 then
                SendVoteStart(v, ply)
            end
        end
    end)
end)

hook.Add("PlayerDisconnected", "Dubz_Vote_RemoveVotes", function(ply)
    for _, v in pairs(Dubz.Vote.Active) do
        v.votes[ply] = nil
    end
end)

----------------------------------------
-- JOB VOTE
----------------------------------------
Dubz.Vote.RegisterType("job", {
    OnFinish = function(v, counts, winner)
        local payload = v.payload or {}
        local ply = payload.ply
        local job = payload.job

        if not IsValid(ply) then return end
        if not job then return end

        local yes = payload.yesIndex or 1
        local no  = payload.noIndex or 2

        local yesVotes = counts[yes] or 0
        local noVotes  = counts[no] or 0

        if winner ~= yes or yesVotes <= noVotes then
            DarkRP.notify(ply, 1, 4, "The vote to become " .. (job.name or "that job") .. " failed.")
            return
        end

        -- DarkRP final eligibility check
        local can, reason = hook.Call("playerCanChangeTeam", GAMEMODE, ply, job.team, true)
        if can == false then
            DarkRP.notify(ply, 1, 4, tostring(reason or "You can no longer become this job."))
            return
        end

        -- SUCCESS
        ply:changeTeam(job.team, true)
        DarkRP.notifyAll(0, 4, ply:Nick() .. " became " .. (job.name or "a job") .. " via vote.")
    end
})

----------------------------------------
-- LEGACY VOTE TYPE
----------------------------------------
Dubz.Vote.RegisterType("darkrp_legacy", {
    OnFinish = function(v, counts, winner)
        local p = v.payload or {}
        local opts = p.rawOptions or {}
        local target = p.target

        if winner > 0 and opts[winner] and isfunction(opts[winner].results) then
            pcall(opts[winner].results, target, winner, v, counts, p.extraArgs)
        end

        if isfunction(p.callback) then
            pcall(p.callback, winner, counts, v, target, p.extraArgs)
        end
    end
})

----------------------------------------
-- QUESTION VOTE
----------------------------------------
Dubz.Vote.RegisterType("darkrp_question", {
    OnFinish = function(v, counts, winner)
        local p = v.payload or {}
        local accept = (winner == 1)

        if isfunction(p.callback) then
            pcall(p.callback, accept, p.target, p.entity, p.extraArgs)
        end
    end
})

----------------------------------------
-- LOTTERY
----------------------------------------
Dubz.Vote.RegisterType("lottery", {
    OnFinish = function(v, counts)
        local p = v.payload or {}
        local price = math.max(0, tonumber(p.price) or 0)
        local pot = math.max(0, tonumber(p.basePot) or 0)
        local entrants = {}

        for ply, choice in pairs(v.votes or {}) do
            if choice == 1 and IsValid(ply) and PlayerCanAfford(ply, price) then
                TakePlayerMoney(ply, price)
                pot = pot + price
                table.insert(entrants, ply)
            end
        end

        if #entrants == 0 then
            if p.host and IsValid(p.host) then
                DarkRP.notify(p.host, 1, 4, "Nobody joined your lottery.")
            end
            return
        end

        local win = entrants[math.random(#entrants)]
        GivePlayerMoney(win, pot)

        DarkRP.notifyAll(0, 4, win:Nick() .. " won the lottery pot of " .. DarkRP.formatMoney(pot) .. "!")
    end
})

----------------------------------------
-- MAP VOTE
----------------------------------------
Dubz.Vote.RegisterType("darkrp_mapvote", {
    OnFinish = function(v, counts, winner)
        local p = v.payload or {}
        local maps = p.maps or {}

        local map = maps[winner]
        if not map then return end

        if isfunction(p.callback) then
            pcall(p.callback, map, v, counts)
        else
            RunConsoleCommand("changelevel", map)
        end
    end
})

----------------------------------------
-- JOB VOTE COMMAND ( /jobvote )
----------------------------------------
local function RegisterJobVoteCommand()
    if Dubz.Vote._JobCommandRegistered then return end
    if not DarkRP then return end

    concommand.Add("dubz_jobvote", function(ply, cmd, args)
        if not IsValid(ply) then return end

        local jobCmd = args[1]
        if not jobCmd then return end

        local job = DarkRP.getJobByCommand(jobCmd)
        if not job then
            DarkRP.notify(ply, 1, 4, "Invalid job.")
            return
        end

        if not job.vote then
            local can, reason = hook.Call("playerCanChangeTeam", GAMEMODE, ply, job.team, true)
            if can == false then
                DarkRP.notify(ply, 1, 4, tostring(reason))
                return
            end

            ply:changeTeam(job.team, true)
            return
        end

        local id = "job_" .. jobCmd .. "_" .. ply:SteamID64() .. "_" .. CurTime()
        Dubz.Vote.Start(id, {
            question = "Allow " .. ply:Nick() .. " to become " .. (job.name or jobCmd) .. "?",
            options = { "Yes", "No" },
            duration = 15,
            type = "job",
            payload = {
                ply = ply,
                job = job,
                yesIndex = 1,
                noIndex = 2
            }
        })
    end)

    Dubz.Vote._JobCommandRegistered = true
end

----------------------------------------
-- BRIDGE DARKRP (convert default DarkRP votes)
----------------------------------------
local function BridgeDarkRP()
    if not DarkRP then return end

    -- createVote
    if DarkRP.createVote and not Dubz.Vote._LegacyBridge then
        function DarkRP.createVote(question, voteTbl, callback, time, target, ...)
            local opts = {}

            if istable(voteTbl) then
                for i, v in ipairs(voteTbl) do
                    opts[i] = v.vote or v.name or "Option " .. i
                end
            end

            if #opts == 0 then opts = {"Yes","No"} end

            local id = "legacy_" .. util.CRC(question or "vote") .. "_" .. CurTime()

            Dubz.Vote.Start(id, {
                question = question or "Vote",
                options = opts,
                duration = time or 20,
                type = "darkrp_legacy",
                payload = {
                    rawOptions = voteTbl,
                    callback = callback,
                    target = target,
                    extraArgs = {...}
                }
            })
        end

        Dubz.Vote._LegacyBridge = true
    end

    -- createQuestion
    if DarkRP.createQuestion and not Dubz.Vote._QuestionBridge then
        function DarkRP.createQuestion(question, target, callback, time, ent, ...)
            local id = "question_" .. util.CRC(question) .. "_" .. CurTime()

            Dubz.Vote.Start(id, {
                question = question or "Question",
                options = {"Yes","No"},
                duration = time or 20,
                type = "darkrp_question",
                payload = {
                    callback = callback,
                    target = target,
                    entity = ent,
                    extraArgs = {...}
                }
            })
        end

        Dubz.Vote._QuestionBridge = true
    end

    -- startLottery
    if DarkRP.startLottery and not Dubz.Vote._LotteryBridge then
        function DarkRP.startLottery(ply)
            local price = GAMEMODE.Config.lotterycost or 250
            local time = GAMEMODE.Config.lotterytime or 18

            Dubz.Vote.Start("lottery_" .. CurTime(), {
                question = ("%s started a lottery for %s. Join?")
                    :format(ply:Nick(), DarkRP.formatMoney(price)),
                options = {"Join","Skip"},
                duration = time,
                type = "lottery",
                payload = {
                    price = price,
                    host = ply
                }
            })
        end

        Dubz.Vote._LotteryBridge = true
    end

    -- startMapVote
    if DarkRP.startMapVote and not Dubz.Vote._MapBridge then
        function DarkRP.startMapVote(ply, maps, callback, time)
            if not istable(maps) or #maps == 0 then return end

            local opts = {}
            for _, m in ipairs(maps) do opts[#opts+1] = tostring(m) end

            Dubz.Vote.Start("mapvote_" .. CurTime(), {
                question = "Select the next map",
                options = opts,
                duration = time or 30,
                type = "darkrp_mapvote",
                payload = {
                    maps = opts,
                    callback = callback
                }
            })
        end

        Dubz.Vote._MapBridge = true
    end
end

----------------------------------------
-- Initialization
----------------------------------------
local function InitVoteSystem()
    RegisterJobVoteCommand()
    BridgeDarkRP()
end

hook.Add("DarkRPFinishedLoading", "Dubz_Vote_Init", InitVoteSystem)
hook.Add("InitPostEntity", "Dubz_Vote_Init2", InitVoteSystem)
InitVoteSystem()
