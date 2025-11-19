if not SERVER then return end

util.AddNetworkString("Dubz_Territory_RequestName")
util.AddNetworkString("Dubz_Territory_SetName")

net.Receive("Dubz_Territory_SetName", function(_, ply)
    if not ply:IsAdmin() then return end
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    local name = net.ReadString() or ""
    name = string.Trim(name)
    if name == "" then 
        ent:ApplyDefaultName()
        return
    end

    ent:SetTerritoryName(name)
    ent.StoredName = name
end)

local function TConfig()
    return Dubz.Config and Dubz.Config.Territories or {}
end

local function SpawnSavedTerritories()
    local cfg = TConfig()
    if not cfg.Enabled then return end

    local class = cfg.EntityClass or "ent_dubz_territory"
    local map = game.GetMap() or "unknown"
    local dir = "dubz_ui"
    local path = string.format("%s/territories_%s.json", dir, map)

    if not file.Exists(path, "DATA") then
        return
    end

    local raw = file.Read(path, "DATA") or "[]"
    local ok, data = pcall(util.JSONToTable, raw)
    if not ok or type(data) ~= "table" then
        print("[Dubz Territories] Failed to parse territories file for "..map)
        return
    end

    local count = 0
    for _, info in ipairs(data) do
        local pos = info.pos or {}
        local ang = info.ang or {}
        local ent = ents.Create(class)
        if IsValid(ent) then
            ent:SetPos(Vector(pos.x or 0, pos.y or 0, pos.z or 0))
            ent:SetAngles(Angle(ang.p or 0, ang.y or 0, ang.r or 0))
            ent:Spawn()
            ent:Activate()
            count = count + 1
        end
    end

    print(string.format("[Dubz Territories] Loaded %d territory poles for map %s", count, map))
end

hook.Add("InitPostEntity", "Dubz_Territories_Load", SpawnSavedTerritories)

