Dubz = Dubz or {}
Dubz.Vote = Dubz.Vote or {}
Dubz.Vote.Active = Dubz.Vote.Active or {}
Dubz.Vote.Types  = Dubz.Vote.Types or {}
Dubz.Vote.Config = Dubz.Vote.Config or {}

util.AddNetworkString("Dubz_Vote_Start")
util.AddNetworkString("Dubz_Vote_Cast")
util.AddNetworkString("Dubz_Vote_End")

Dubz.Vote.Active = Dubz.Vote.Active or {}
Dubz.Vote.Types  = Dubz.Vote.Types or {}  -- named handlers (job, gang, etc)

local function PlayerCanAfford(ply, amt)
    amt = math.floor(tonumber(amt) or 0)
    if amt <= 0 then return true end
    if DarkRP and ply.canAfford then
        return ply:canAfford(amt)
    end
    local money = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or (ply._Dubz_Money or 0)
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

local function GetRemainingTime(vote)
    if not vote or not vote.endTime then return 0 end
    return math.Clamp(math.ceil(math.max(0, vote.endTime - CurTime())), 0, 255)
end

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
        net.WriteBool(cancelled and true or false)
    net.Broadcast()
end

local function FinishVote(id, vote, opts)
    Dubz.Vote.Active[id] = nil
    if not vote then return end

    local counts = {}
    for i = 1, #vote.options do counts[i] = 0 end

    for ply, choice in pairs(vote.votes or {}) do
        if IsValid(ply) and counts[choice] ~= nil then
            counts[choice] = counts[choice] + 1
        end
    end

    local topCount = -1
    local winningIndex = 0
    local tied = false
    for i, c in ipairs(counts) do
        if c > topCount then
            winningIndex = i
            topCount = c
            tied = false
        elseif c == topCount then
            tied = true
        end
    end

    if topCount <= 0 or tied then
        winningIndex = 0
    end

    local cancelled = opts and opts.cancelled
    local summary
    if cancelled then
        summary = string.format("Vote '%s' cancelled (%s)", id, opts and opts.reason or "cancelled")
        Dubz.Vote.Log(summary)
        if Dubz.Log then Dubz.Log(summary, "WARN", "VOTE") end
    else
        summary = string.format("Vote '%s' finished, winner = %d (%s)", id, winningIndex, vote.options[winningIndex] or "none")
        Dubz.Vote.Log(summary)
        if Dubz.Log then Dubz.Log(summary, "INFO", "VOTE") end
    end

    if not cancelled then
        local handler = Dubz.Vote.Types[vote.vtype or "generic"]
        if handler and isfunction(handler.OnFinish) then
            handler.OnFinish(vote, counts, winningIndex)
        end
    end

    BroadcastVoteEnd(id, counts, winningIndex, cancelled)
end

-- Register a vote type with a finish callback
function Dubz.Vote.RegisterType(name, def)
    Dubz.Vote.Types[name] = def
end

function Dubz.Vote.Cancel(id, reason)
    local vote = Dubz.Vote.Active[id]
    if not vote then return false end
    FinishVote(id, vote, { cancelled = true, reason = reason })
    return true
end

-- Start a vote
-- id: string
-- data: {
--   question = "string",
--   options = { "Yes", "No", ... },
--   duration = number,
--   type = "job",
--   payload = table (custom stuff)
-- }
function Dubz.Vote.Start(id, data)
    if not isstring(id) or id == "" then return end
    if not data or not istable(data) then return end
    if not data.question or not istable(data.options) or #data.options == 0 then return end

    local options = {}
    for _, opt in ipairs(data.options) do
        options[#options + 1] = tostring(opt or "Option")
    end

    if Dubz.Vote.Active[id] then
        Dubz.Vote.Cancel(id, "restarted")
    end

    local duration = tonumber(data.duration) or Dubz.Vote.Config.DefaultDuration or 15
    duration = math.Clamp(math.floor(duration), 5, 255)

    Dubz.Vote.Active[id] = {
        id       = id,
        question = tostring(data.question),
        options  = options,
        endTime  = CurTime() + duration,
        votes    = {},           -- [ply] = choiceIndex
        duration = duration,
        vtype    = data.type or "generic",
        payload  = data.payload or {},
        started  = CurTime()
    }

    Dubz.Vote.Log("Started vote '" .. id .. "' (" .. data.question .. ")")
    SendVoteStart(Dubz.Vote.Active[id])
end

-- Player cast vote
net.Receive("Dubz_Vote_Cast", function(_, ply)
    local id = net.ReadString()
    local choice = net.ReadUInt(8)

    local v = Dubz.Vote.Active[id]
    if not v then return end
    if CurTime() >= v.endTime then return end
    if choice < 1 or choice > #v.options then return end

    v.votes[ply] = choice
end)

-- Main Think hook
hook.Add("Think", "Dubz_Vote_Think", function()
    for id, v in pairs(Dubz.Vote.Active) do
        if CurTime() >= v.endTime then
            FinishVote(id, v)
        end
    end
end)

hook.Add("PlayerInitialSpawn", "Dubz_Vote_ResendActive", function(ply)
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

-----------------------------------------------------------------------
-- JOB VOTE TYPE (replaces DarkRP job votes)
-----------------------------------------------------------------------
local function RegisterJobVoteType()
    if Dubz.Vote._JobTypeRegistered then return end
    if not DarkRP then return end

    Dubz.Vote.RegisterType("job", {
        OnFinish = function(v, counts, winner)
            local payload = v.payload or {}
            local ply = payload.ply
            local jobCommand = payload.jobCommand
            local job = payload.job

            if not IsValid(ply) or not job then return end

            local yesIndex = payload.yesIndex or 1
            local noIndex = payload.noIndex or 2

            if winner == yesIndex and (counts[yesIndex] or 0) > (counts[noIndex] or 0) then
                -- re-check job validity / max players
                local canSwitch, reason = hook.Call("playerCanChangeTeam", GAMEMODE, ply, job.team, true)
                if canSwitch == false then
                    if reason then DarkRP.notify(ply, 1, 4, tostring(reason)) end
                    return
                end

                ply:changeTeam(job.team, true)
                DarkRP.notifyAll(0, 4, ply:Nick() .. " became " .. (job.name or "a job") .. " via vote.")
            else
                DarkRP.notify(ply, 1, 4, "The vote to become " .. (job.name or "that job") .. " failed.")
            end
        end
    })

    Dubz.Vote._JobTypeRegistered = true
end

hook.Add("DarkRPFinishedLoading", "Dubz_Vote_RegisterJobType", RegisterJobVoteType)
hook.Add("InitPostEntity", "Dubz_Vote_RegisterJobType_Init", RegisterJobVoteType)
RegisterJobVoteType()

Dubz.Vote.RegisterType("darkrp_legacy", {
    OnFinish = function(v, counts, winner)
        local payload = v.payload or {}
        local options = payload.rawOptions or {}
        local target = payload.target
        if winner > 0 and options[winner] and isfunction(options[winner].results) then
            local ok, err = pcall(options[winner].results, target, winner, v, counts, payload.extraArgs)
            if not ok then ErrorNoHalt("[DubzVote] Legacy result error: " .. tostring(err) .. "\n") end
        end
        if isfunction(payload.callback) then
            local ok, err = pcall(payload.callback, winner, counts, v, target, payload.extraArgs)
            if not ok then ErrorNoHalt("[DubzVote] Legacy callback error: " .. tostring(err) .. "\n") end
        end
    end
})

Dubz.Vote.RegisterType("darkrp_question", {
    OnFinish = function(v, counts, winner)
        local payload = v.payload or {}
        local accept = winner == 1
        if isfunction(payload.callback) then
            local ok, err = pcall(payload.callback, accept, payload.target, payload.entity, payload.extraArgs)
            if not ok then ErrorNoHalt("[DubzVote] Question callback error: " .. tostring(err) .. "\n") end
        end
    end
})

Dubz.Vote.RegisterType("lottery", {
    OnFinish = function(v, counts)
        local payload = v.payload or {}
        local entrants = {}
        local price = math.max(0, tonumber(payload.price) or 0)
        local pot = math.max(0, tonumber(payload.basePot) or 0)

        for ply, choice in pairs(v.votes or {}) do
            if choice == 1 and IsValid(ply) and PlayerCanAfford(ply, price) then
                if price > 0 then
                    TakePlayerMoney(ply, price)
                    pot = pot + price
                end
                table.insert(entrants, ply)
            end
        end

        if #entrants == 0 then
            if payload.host and IsValid(payload.host) and DarkRP and DarkRP.notify then
                DarkRP.notify(payload.host, 1, 4, "Nobody joined your lottery.")
            end
            return
        end

        local winner = entrants[math.random(#entrants)]
        if not IsValid(winner) then return end

        if pot <= 0 then pot = #entrants * price end
        if pot > 0 then
            GivePlayerMoney(winner, pot)
        end

        local msg = string.format("%s won the lottery pot of %s!", winner:Nick(), (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(pot)) or ("$"..tostring(pot)))
        if DarkRP and DarkRP.notifyAll then
            DarkRP.notifyAll(0, 4, msg)
        else
            print("[DubzVote] " .. msg)
        end
    end
})

Dubz.Vote.RegisterType("darkrp_mapvote", {
    OnFinish = function(v, counts, winner)
        local payload = v.payload or {}
        local maps = payload.maps or {}
        local targetMap = maps[winner]
        if not targetMap or targetMap == "" then
            return
        end
        if isfunction(payload.callback) then
            local ok, err = pcall(payload.callback, targetMap, v, counts)
            if not ok then ErrorNoHalt("[DubzVote] Map vote callback error: " .. tostring(err) .. "\n") end
        else
            RunConsoleCommand("changelevel", targetMap)
        end
    end
})

-----------------------------------------------------------------------
-- JOB VOTE CONSOLE COMMAND: "dubz_jobvote jobCommand"
-----------------------------------------------------------------------
local function RegisterJobVoteCommand()
    if Dubz.Vote._JobCommandRegistered then return end
    if not DarkRP then return end

    concommand.Add("dubz_jobvote", function(ply, cmd, args)
        if not IsValid(ply) then return end
        local jobCmd = args[1]
        if not jobCmd or jobCmd == "" then return end

        local job
        if DarkRP.getJobByCommand then
            job = DarkRP.getJobByCommand(jobCmd)
        else
            -- fallback manual search
            for _, v in pairs(RPExtraTeams or {}) do
                if v.command == jobCmd then
                    job = v
                    break
                end
            end
        end
        if not job then
            DarkRP.notify(ply, 1, 4, "Invalid job.")
            return
        end

        -- If job doesn't require vote, just change team directly
        if not job.vote then
            local canSwitch, reason = hook.Call("playerCanChangeTeam", GAMEMODE, ply, job.team, true)
            if canSwitch == false then
                if reason then DarkRP.notify(ply, 1, 4, tostring(reason)) end
                return
            end
            ply:changeTeam(job.team, true)
            return
        end

        -- Start vote
        local id = string.format("job_%s_%s_%d", jobCmd, ply:SteamID64(), CurTime())
        local question = string.format("Allow %s to become %s?", ply:Nick(), job.name or jobCmd)

        Dubz.Vote.Start(id, {
            question = question,
            options  = { "Yes", "No" },
            duration = 15,
            type     = "job",
            payload  = {
                ply        = ply,
                job        = job,
                jobCommand = jobCmd,
                yesIndex   = 1,
                noIndex    = 2
            }
        })
    end)

    Dubz.Vote._JobCommandRegistered = true
end

hook.Add("DarkRPFinishedLoading", "Dubz_Vote_RegisterJobCommand", RegisterJobVoteCommand)
hook.Add("InitPostEntity", "Dubz_Vote_RegisterJobCommand_Init", RegisterJobVoteCommand)
RegisterJobVoteCommand()

local function BridgeDarkRPVoting()
    if not DarkRP then return end

    if DarkRP.createVote and not Dubz.Vote._LegacyBridge then
        function DarkRP.createVote(question, voteTbl, callback, time, target, ...)
            local opts = {}
            for i, opt in ipairs(voteTbl or {}) do
                opts[i] = (opt and (opt.vote or opt.name or opt.text or opt.label)) or ("Option " .. i)
            end
            if #opts == 0 then opts = { "Yes", "No" } end
            local id = string.format("legacy_%s_%d", util.CRC(question or "vote"), CurTime())
            Dubz.Vote.Start(id, {
                question = question or "Vote",
                options  = opts,
                duration = time or 20,
                type     = "darkrp_legacy",
                payload  = {
                    rawOptions = voteTbl,
                    callback   = callback,
                    target     = target,
                    extraArgs  = {...}
                }
            })
            return id
        end
        Dubz.Vote._LegacyBridge = true
    end

    if DarkRP.createQuestion and not Dubz.Vote._QuestionBridge then
        function DarkRP.createQuestion(question, target, callback, time, ent, ...)
            local id = string.format("question_%s_%d", util.CRC(question or "question"), CurTime())
            Dubz.Vote.Start(id, {
                question = question or "Question",
                options  = { "Yes", "No" },
                duration = time or 20,
                type     = "darkrp_question",
                payload  = {
                    callback  = callback,
                    target    = target,
                    entity    = ent,
                    extraArgs = {...}
                }
            })
            return id
        end
        Dubz.Vote._QuestionBridge = true
    end

    if DarkRP.startLottery and not Dubz.Vote._LotteryBridge then
        function DarkRP.startLottery(ply)
            local price = (GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.lotterycost) or 250
            local duration = (GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.lotterytime) or 18
            local id = string.format("lottery_%d", CurTime())
            Dubz.Vote.Start(id, {
                question = string.format("%s started a lottery for %s. Join?", IsValid(ply) and ply:Nick() or "Unknown", (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(price)) or ("$"..tostring(price))),
                options  = { "Join", "Skip" },
                duration = math.Clamp(duration, 10, 60),
                type     = "lottery",
                payload  = {
                    price = price,
                    host  = ply
                }
            })
        end
        Dubz.Vote._LotteryBridge = true
    end

    if DarkRP.startMapVote and not Dubz.Vote._MapBridge then
        function DarkRP.startMapVote(ply, maps, callback, time)
            if not istable(maps) or #maps == 0 then return end
            local options = {}
            for _, map in ipairs(maps) do
                table.insert(options, tostring(map))
            end
            local id = string.format("mapvote_%d", CurTime())
            Dubz.Vote.Start(id, {
                question = "Select the next map",
                options  = options,
                duration = math.Clamp(time or 30, 15, 90),
                type     = "darkrp_mapvote",
                payload  = {
                    maps     = options,
                    callback = callback
                }
            })
            return id
        end
        Dubz.Vote._MapBridge = true
    end

    if DarkRP.destroyVotesWithEnt and not Dubz.Vote._DestroyBridge then
        local oldDestroy = DarkRP.destroyVotesWithEnt
        function DarkRP.destroyVotesWithEnt(ent)
            for id, vote in pairs(Dubz.Vote.Active) do
                if vote.payload and vote.payload.entity == ent then
                    Dubz.Vote.Cancel(id, "entity removed")
                end
            end
            if oldDestroy then
                return oldDestroy(ent)
            end
        end
        Dubz.Vote._DestroyBridge = true
    end
end

hook.Add("DarkRPFinishedLoading", "Dubz_Vote_BridgeDarkRP", BridgeDarkRPVoting)
hook.Add("InitPostEntity", "Dubz_Vote_BridgeDarkRP_Init", BridgeDarkRPVoting)
BridgeDarkRPVoting()
