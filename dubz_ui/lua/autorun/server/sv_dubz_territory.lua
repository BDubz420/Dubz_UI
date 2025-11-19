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

    local function toVector(tbl)
        if istable(tbl) then
            if tbl.x then return Vector(tbl.x, tbl.y, tbl.z) end
            if tbl[1] then return Vector(tbl[1], tbl[2], tbl[3]) end
        end
        return Vector(0,0,0)
    end

    local function toAngle(tbl)
        if istable(tbl) then
            if tbl.p then return Angle(tbl.p, tbl.y, tbl.r) end
            if tbl[1] then return Angle(tbl[1], tbl[2], tbl[3]) end
        end
        return Angle(0,0,0)
    end

    local count = 0
    for _, info in ipairs(data) do
        local pos = toVector(info.pos)
        local ang = toAngle(info.ang)
        local ent = ents.Create(class)
        if IsValid(ent) then
            ent:SetPos(pos)
            ent:SetAngles(ang)
            ent:Spawn()
            ent:Activate()
            if info.name and ent.SetTerritoryName then
                ent:SetTerritoryName(info.name)
            end
            count = count + 1
        end
    end

    print(string.format("[Dubz Territories] Loaded %d territory poles for map %s", count, map))
end

hook.Add("InitPostEntity", "Dubz_Territories_Load", SpawnSavedTerritories)

