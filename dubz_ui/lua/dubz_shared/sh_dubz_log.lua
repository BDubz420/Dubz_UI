Dubz = Dubz or {}
Dubz.Logs = Dubz.Logs or {}

local function keepCount()
    if Dubz.Config and Dubz.Config.MaxLogs then return Dubz.Config.MaxLogs end
    return 500
end

local function normalizeEntry(entry)
    entry = entry or {}
    entry.ts = entry.ts or os.time()
    entry.level = string.upper(entry.level or "INFO")
    entry.cat = string.upper(entry.cat or "GENERAL")
    entry.msg = tostring(entry.msg or "")
    return entry
end

local function pushEntry(entry)
    Dubz.Logs = Dubz.Logs or {}
    table.insert(Dubz.Logs, 1, entry)
    local keep = math.max(keepCount(), 50)
    while #Dubz.Logs > keep do
        table.remove(Dubz.Logs)
    end
end

local function writeEntry(entry)
    net.WriteUInt(math.floor(entry.ts or 0), 32)
    net.WriteString(entry.level or "INFO")
    net.WriteString(entry.cat or "GENERAL")
    net.WriteString(entry.msg or "")
end

local function readEntry()
    local e = {
        ts = net.ReadUInt(32),
        level = net.ReadString(),
        cat = net.ReadString(),
        msg = net.ReadString()
    }
    return normalizeEntry(e)
end

if SERVER then
    util.AddNetworkString("Dubz_LogStream")

    local function broadcastEntry(entry, ply)
        net.Start("Dubz_LogStream")
            net.WriteBool(false)
            writeEntry(entry)
        if IsValid(ply) then
            net.Send(ply)
        else
            net.Broadcast()
        end
    end

    local function sendFull(ply)
        net.Start("Dubz_LogStream")
            net.WriteBool(true)
            net.WriteUInt(math.min(#Dubz.Logs, 2047), 12)
            for i = 1, math.min(#Dubz.Logs, 2047) do
                writeEntry(Dubz.Logs[i])
            end
        if IsValid(ply) then
            net.Send(ply)
        end
    end

    function Dubz.Log(msg, level, category)
        local entry = normalizeEntry({
            ts = os.time(),
            level = level,
            cat = category,
            msg = msg
        })
        pushEntry(entry)
        broadcastEntry(entry)
    end

    hook.Add("PlayerInitialSpawn", "Dubz_LogSync", function(ply)
        timer.Simple(3, function()
            if IsValid(ply) then
                sendFull(ply)
            end
        end)
    end)
else
    net.Receive("Dubz_LogStream", function()
        Dubz.Logs = Dubz.Logs or {}
        local full = net.ReadBool()
        if full then
            local count = net.ReadUInt(12)
            Dubz.Logs = {}
            for i = 1, count do
                local entry = readEntry()
                pushEntry(entry)
            end
        else
            local entry = readEntry()
            pushEntry(entry)
        end
    end)

    function Dubz.Log(msg, level, category)
        local entry = normalizeEntry({
            ts = os.time(),
            level = level or "CLIENT",
            cat = category or "LOCAL",
            msg = msg
        })
        pushEntry(entry)
    end
end
