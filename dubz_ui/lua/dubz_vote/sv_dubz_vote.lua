if not Dubz or not Dubz.Vote then return end

util.AddNetworkString("Dubz_Vote_Start")
util.AddNetworkString("Dubz_Vote_Cast")
util.AddNetworkString("Dubz_Vote_End")

Dubz.Vote.Active = Dubz.Vote.Active or {}
Dubz.Vote.Types  = Dubz.Vote.Types or {}  -- named handlers (job, gang, etc)

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
    if cancelled then
        Dubz.Vote.Log(string.format("Vote '%s' cancelled (%s)", id, opts and opts.reason or "cancelled"))
    else
        Dubz.Vote.Log(string.format("Vote '%s' finished, winner = %d (%s)", id, winningIndex, vote.options[winningIndex] or "none"))
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
if DarkRP then
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
end

-----------------------------------------------------------------------
-- JOB VOTE CONSOLE COMMAND: "dubz_jobvote jobCommand"
-----------------------------------------------------------------------
if DarkRP then
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
                if v.command == jobCmd then job = v break end
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
end
