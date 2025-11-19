TOOL.Category = "Dubz UI"
TOOL.Name     = "#Dubz Territory Tool"
TOOL.Command  = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.dubz_territory.name", "Dubz Territory Tool")
    language.Add("tool.dubz_territory.desc", "Place and manage graffiti territory spots.")
    language.Add("tool.dubz_territory.0", "LMB: Place | RMB: Remove | Reload: Save positions")

    TOOL.GhostEntity = nil
end

local function TConfig()
    return Dubz.Config and Dubz.Config.Territories or {}
end

-- get exact model center
local function GetCenterOffset(ent)
    local min, max = ent:GetModelBounds()
    return (min + max) * 0.5
end

----------------------------------------------------------------------
-- ROTATION THAT MAKES THE PLATE ALWAYS FACE THE PLAYER (moon effect)
----------------------------------------------------------------------
local function ComputeBillboardAngle(hitNorm, ply)
    local eye = ply:EyeAngles()

    -- base from wall
    local ang = hitNorm:Angle()

    -- upright
    ang:RotateAroundAxis(ang:Right(), -90)

    -- face player horizontally
    local yawDiff = math.AngleDifference(eye.y, ang.y)
    ang:RotateAroundAxis(ang:Up(), yawDiff)

    -- face player vertically (tilt)
    local pitchDiff = math.AngleDifference(eye.p, ang.p)
    ang:RotateAroundAxis(ang:Right(), pitchDiff)

    return ang
end

----------------------------------------------------------------------
-- GHOST UPDATE
----------------------------------------------------------------------
function TOOL:UpdateGhost(ent, ply)
    if not IsValid(ent) then return end

    local tr = ply:GetEyeTrace()
    if not tr.Hit or tr.HitSky then ent:SetNoDraw(true) return end

    local hitPos  = tr.HitPos
    local hitNorm = tr.HitNormal

    -- TEXTSCREEN-STYLE ANGLES (ALWAYS UPRIGHT, WALL-FLUSH)
    local base = hitNorm:Angle()
    local ang = Angle(base.p, base.y, base.r)
    ang:RotateAroundAxis(base:Right(), -90)
    ang:RotateAroundAxis(base:Forward(), 90)

    -- CENTER FIX
    local center = GetCenterOffset(ent)
    local worldOffset =
        ang:Forward() * center.x -
        ang:Right()   * center.y +
        ang:Up()      * center.z

    ent:SetPos(hitPos + hitNorm * 0.5 - worldOffset)
    ent:SetAngles(ang)
    ent:SetNoDraw(false)

    ent:SetColor(self:IsPlacementValid(hitPos, hitNorm)
        and Color(50,255,50,150)
        or  Color(255,50,50,150))
end

----------------------------------------------------------------------
-- VALID CHECK
----------------------------------------------------------------------
function TOOL:IsPlacementValid(pos, normal)
    local cfg   = TConfig()
    local class = cfg.EntityClass or "ent_dubz_graffiti_spot"

    if math.abs(normal.z) > 0.3 then return false end

    for _, e in ipairs(ents.FindByClass(class)) do
        if e:GetPos():DistToSqr(pos) < (40*40) then
            return false
        end
    end

    return true
end

----------------------------------------------------------------------
-- THINK: spawn ghost
----------------------------------------------------------------------
function TOOL:Think()
    if CLIENT then
        if not IsValid(self.GhostEntity) then
            self.GhostEntity = ClientsideModel("models/squad/sf_plates/sf_plate8x8.mdl")
            self.GhostEntity:SetRenderMode(RENDERMODE_TRANSCOLOR)
            self.GhostEntity:SetColor(Color(255,255,255,150))
            self.GhostEntity:SetNoDraw(true)
        end
        self:UpdateGhost(self.GhostEntity, LocalPlayer())
    end
end

----------------------------------------------------------------------
-- LEFT CLICK — place
----------------------------------------------------------------------
function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()

    if not trace.Hit or trace.HitSky then return false end
    if math.abs(trace.HitNormal.z) > 0.3 then return false end

    local hitPos  = trace.HitPos
    local hitNorm = trace.HitNormal

    if not self:IsPlacementValid(hitPos, hitNorm) then return false end

    local ent = ents.Create("ent_dubz_graffiti_spot")
    ent:Spawn()
    ent:Activate()

    -- TEXTSCREEN ANGLES (perfectly upright & aligned)
    local base = hitNorm:Angle()
    local ang = Angle(base.p, base.y, base.r)
    ang:RotateAroundAxis(base:Right(), -90)
    ang:RotateAroundAxis(base:Forward(), 90)

    ent:SetAngles(ang)

    -- CENTER FIX
    local center = GetCenterOffset(ent)
    local worldOffset =
        ang:Forward() * center.x -
        ang:Right()   * center.y +
        ang:Up()      * center.z

    ent:SetPos(hitPos + hitNorm * 0.5 - worldOffset)

    -- NAME POPUP
    timer.Simple(0.2, function()
        if IsValid(ply) and IsValid(ent) then
            net.Start("Dubz_Territory_RequestName")
                net.WriteEntity(ent)
            net.Send(ply)
        end
    end)

    return true
end

----------------------------------------------------------------------
-- RIGHT CLICK — remove
----------------------------------------------------------------------
function TOOL:RightClick(trace)
    if CLIENT then return true end

    local cfg = TConfig()
    local class = cfg.EntityClass or "ent_dubz_graffiti_spot"
    local ply = self:GetOwner()

    if cfg.Tool.AdminOnly ~= false and not ply:IsAdmin() then return false end

    local ent = trace.Entity
    if IsValid(ent) and ent:GetClass() == class then
        ent:Remove()
        return true
    end

    for _, e in ipairs(ents.FindByClass(class)) do
        if e:GetPos():DistToSqr(trace.HitPos) < (64*64) then
            e:Remove()
            return true
        end
    end

    return false
end

----------------------------------------------------------------------
-- SAVE TERRITORIES
----------------------------------------------------------------------
if SERVER then
    function TOOL:Reload()
        local cfg = TConfig()
        if not cfg.Enabled then return false end

        local class = cfg.EntityClass or "ent_dubz_graffiti_spot"
        local ply = self:GetOwner()

        if cfg.Tool.AdminOnly ~= false and not ply:IsAdmin() then
            return false
        end

        local map = game.GetMap()
        local dir = "dubz_ui"
        if not file.IsDir(dir, "DATA") then file.CreateDir(dir) end

        local saved = {}

        for _, ent in ipairs(ents.FindByClass(class)) do
            local pos = ent:GetPos()
            local ang = ent:GetAngles()

            table.insert(saved, {
                pos  = {pos.x, pos.y, pos.z},
                ang  = {ang.p,  ang.y,  ang.r},
                name = ent.GetTerritoryName and ent:GetTerritoryName() or ""
            })
        end

        file.Write(dir.."/territories_"..map..".json", util.TableToJSON(saved, true))

        print("[Dubz Territories] Saved", #saved, "territories.")
        return true
    end
end

----------------------------------------------------------------------
-- NAME POPUP
----------------------------------------------------------------------
if CLIENT then
net.Receive("Dubz_Territory_RequestName", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Territory Name")
    frame:SetSize(300, 110)
    frame:Center()
    frame:MakePopup()

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(20, 40)
    entry:SetSize(260, 24)
    entry:SetText(ent:GetTerritoryName() or "")

    local btn = vgui.Create("DButton", frame)
    btn:SetPos(20, 70)
    btn:SetSize(260, 26)
    btn:SetText("Save")
    btn.DoClick = function()
        net.Start("Dubz_Territory_SetName")
            net.WriteEntity(ent)
            net.WriteString(entry:GetText())
        net.SendToServer()
        frame:Close()
    end
end)
end

----------------------------------------------------------------------
-- SERVER RECEIVE NAME
----------------------------------------------------------------------
if SERVER then
net.Receive("Dubz_Territory_SetName", function(_, ply)
    local ent  = net.ReadEntity()
    local name = net.ReadString()

    if not IsValid(ent) then return end
    if ent:GetClass() ~= (TConfig().EntityClass or "ent_dubz_graffiti_spot") then return end

    name = string.Trim(name)
    name = string.sub(name, 1, 32)

    if ent.SetTerritoryName then
        ent:SetTerritoryName(name)
    end

    ply:ChatPrint("Territory name set to: " .. name)
end)
end
