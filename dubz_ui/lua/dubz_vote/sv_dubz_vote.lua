
--[[
if not Dubz or not Dubz.Vote then return end

util.AddNetworkString("Dubz_Vote_Start")
util.AddNetworkString("Dubz_Vote_Cast")
util.AddNetworkString("Dubz_Vote_End")

Dubz.Vote.Active = Dubz.Vote.Active or {}
Dubz.Vote.Types  = Dubz.Vote.Types or {}  -- named handlers (job, gang, etc)

-- Register a vote type with a finish callback
function Dubz.Vote.RegisterType(name, def)
    Dubz.Vote.Types[name] = def
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
    if not data or not istable(data) then return end
    if not data.question or not istable(data.options) or #data.options == 0 then return end

    local duration = tonumber(data.duration) or Dubz.Vote.Config.DefaultDuration
    Dubz.Vote.Active[id] = {
        id       = id,
        question = data.question,
        options  = data.options,
        endTime  = CurTime() + duration,
        votes    = {},           -- [ply] = choiceIndex
        duration = duration,
        vtype    = data.type or "generic",
        payload  = data.payload or {}
    }

    Dubz.Vote.Log("Started vote '" .. id .. "' (" .. data.question .. ")")

    -- Send to all players (you can filter later if needed)
    net.Start("Dubz_Vote_Start")
        net.WriteString(id)
        net.WriteString(data.question)
        net.WriteUInt(#data.options, 8)
        for _, opt in ipairs(data.options) do
            net.WriteString(opt)
        end
        net.WriteUInt(duration, 8)
    net.Broadcast()
end

-- Player cast vote
net.Receive("Dubz_Vote_Cast", function(_, ply)
    local id = net.ReadString()
    local choice = net.ReadUInt(8)

    local v = Dubz.Vote.Active[id]
    if not v then return end
    if choice < 1 or choice > #v.options then return end

    v.votes[ply] = choice
end)

-- Tally + finish
local function FinishVote(id, v)
    Dubz.Vote.Active[id] = nil
    if not v then return end

    -- tally
    local counts = {}
    for i = 1, #v.options do counts[i] = 0 end
    for ply, choice in pairs(v.votes or {}) do
        counts[choice] = (counts[choice] or 0) + 1
    end

    -- find winner
    local winningIndex, winningCount = 0, -1
    for i, c in ipairs(counts) do
        if c > winningCount then
            winningCount = c
            winningIndex = i
        end
    end

    Dubz.Vote.Log(string.format("Vote '%s' finished, winner = %d (%s)", id, winningIndex, v.options[winningIndex] or "none"))

    -- call type handler
    local handler = Dubz.Vote.Types[v.vtype or "generic"]
    if handler and isfunction(handler.OnFinish) then
        handler.OnFinish(v, counts, winningIndex)
    end

    -- notify clients
    net.Start("Dubz_Vote_End")
        net.WriteString(id)
        net.WriteUInt(#counts, 8)
        for _, c in ipairs(counts) do
            net.WriteUInt(c, 12)
        end
        net.WriteUInt(winningIndex, 8)
    net.Broadcast()
end

-- Main Think hook
hook.Add("Think", "Dubz_Vote_Think", function()
    for id, v in pairs(Dubz.Vote.Active) do
        if CurTime() >= v.endTime then
            FinishVote(id, v)
        end
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
--]]