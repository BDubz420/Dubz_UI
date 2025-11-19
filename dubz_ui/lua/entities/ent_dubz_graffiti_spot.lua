AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Graffiti Territory Plate"
ENT.Author    = "Dubz UI"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

-----------------------------------------------------
-- NETWORK VARS
-----------------------------------------------------
function ENT:SetupDataTables()
    self:NetworkVar("Bool",   0, "IsClaimed")
    self:NetworkVar("String", 0, "OwnerGangId")
    self:NetworkVar("String", 1, "OwnerGangName")

    -- NEW: Territory name
    self:NetworkVar("String", 2, "TerritoryName")
end

-----------------------------------------------------
-- SERVER
-----------------------------------------------------
if SERVER then

util.AddNetworkString("Dubz_Graffiti_ClaimProgress")
util.AddNetworkString("Dubz_Graffiti_ClaimFinished")

util.AddNetworkString("Dubz_Territory_NamePrompt")
util.AddNetworkString("Dubz_Territory_SetName")
local CLAIM_TIME = 4

if SERVER then
    hook.Add("PlayerDisconnected", "Dubz_Territory_AutoUnclaim", function(ply)
        timer.Simple(1, function()
            if not IsValid(ply) then return end
            if not Dubz or not Dubz.GangByMember then return end

            local sid = ply:SteamID64()
            local gid = Dubz.GangByMember[sid]
            if not gid or gid == "" then return end

            -- Count online members of that gang
            local online = 0
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and Dubz.GangByMember[p:SteamID64()] == gid then
                    online = online + 1
                end
            end

            -- If no members of that gang online -> unclaim all their territories
            if online == 0 then
                for _, ent in ipairs(ents.FindByClass("ent_dubz_graffiti_spot")) do
                    if IsValid(ent) and ent.GetOwnerGangId and ent:GetOwnerGangId() == gid then
                        ent:SetIsClaimed(false)
                        ent:SetOwnerGangId("")
                        ent:SetOwnerGangName("")
                        if ent.SetTerritoryName then
                            ent:SetTerritoryName("Unclaimed Territory")
                        end
                        ent.ClaimProg = nil
                        ent.ProgTime  = nil
                    end
                end
            end
        end)
    end)
end

function ENT:Initialize()
    self:SetModel("models/squad/sf_plates/sf_plate8x8.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)

    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self:SetColor(Color(255,255,255,1)) -- almost invisible
    self:DrawShadow(false)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    self.IsClaiming = {}
    self:SetUseType(SIMPLE_USE)

    -- default placeholder name
    if self:GetTerritoryName() == "" then
        self:SetTerritoryName("Unnamed Territory")
    end
end

-- toolgun alignment
function ENT:AlignToWall(hitPos, hitNormal)
    local ang = hitNormal:Angle()
    ang:RotateAroundAxis(ang:Right(), -90)
    ang:RotateAroundAxis(ang:Up(), 90)

    self:SetPos(hitPos + hitNormal * 0.1)
    self:SetAngles(ang)
end

function ENT:Use(ply)
    if not IsValid(ply) then return end

    local sid = ply:SteamID64()
    local gid = Dubz.GangByMember and Dubz.GangByMember[sid]

    if not gid then
        ply:ChatPrint("You must be in a gang to claim this.")
        return
    end

    if self:GetIsClaimed() and self:GetOwnerGangId() == gid then
        ply:ChatPrint("Your gang already owns this territory.")
        return
    end

    self.IsClaiming[ply] = {
        start = CurTime(),
        gang  = gid
    }
end

function ENT:Think()
    for ply, data in pairs(self.IsClaiming) do

        if not IsValid(ply) then
            self.IsClaiming[ply] = nil
            continue
        end

        -- must keep aiming at entity while holding E
        local tr = ply:GetEyeTrace()
        if tr.Entity ~= self then
            self.IsClaiming[ply] = nil
            continue
        end

        if not ply:KeyDown(IN_USE) then
            self.IsClaiming[ply] = nil
            continue
        end

        local prog = (CurTime() - data.start) / CLAIM_TIME

        net.Start("Dubz_Graffiti_ClaimProgress")
            net.WriteEntity(self)
            net.WriteFloat(prog)
        net.Send(ply)

        if prog >= 1 then
            self:FinishClaim(ply, data.gang)
            self.IsClaiming[ply] = nil
        end
    end

    self:NextThink(CurTime())
    return true
end

function ENT:FinishClaim(ply, gid)
    local gang = Dubz.Gangs and Dubz.Gangs[gid]
    if not gang then return end

    self:SetIsClaimed(true)
    self:SetOwnerGangId(gid)
    self:SetOwnerGangName(gang.name)

    if AddGangTerritory then
        AddGangTerritory(gid, {
            name = self:GetTerritoryName(),
            sprayer = ply:Nick(),
            time = os.time(),
            pos = self:GetPos(),
            ang = self:GetAngles()
        })
    end

    net.Start("Dubz_Graffiti_ClaimFinished")
        net.WriteEntity(self)
    net.Broadcast()
end

end -- SERVER


-----------------------------------------------------
-- CLIENT
-----------------------------------------------------
if CLIENT then

-----------------------------------------------------
-- NET
-----------------------------------------------------
net.Receive("Dubz_Graffiti_ClaimProgress", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    ent.ClaimProg = net.ReadFloat()
    ent.ProgTime  = CurTime()
end)

net.Receive("Dubz_Graffiti_ClaimFinished", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    ent.ClaimProg = nil
    ent.ProgTime  = nil
end)


-----------------------------------------------------
-- BORDER + CIRCLE HELPERS
-----------------------------------------------------
local function DrawDottedBorder(x, y, w, h)
    surface.SetDrawColor(255,255,255,255)
    local step = 14

    for i = 0, w, step do
        surface.DrawRect(x + i, y, step/2, 3)
        surface.DrawRect(x + i, y + h - 3, step/2, 3)
    end

    for i = 0, h, step do
        surface.DrawRect(x, y + i, 3, step/2)
        surface.DrawRect(x + w - 3, y + i, 3, step/2)
    end
end

local function DrawCircle(x, y, r, col, perc)
    surface.SetDrawColor(col)
    draw.NoTexture()

    local poly = {{x = x, y = y}}
    for i = 0, perc * 360 do
        local rad = math.rad(i)
        poly[#poly+1] = { x = x + math.cos(rad)*r, y = y + math.sin(rad)*r }
    end
    surface.DrawPoly(poly)
end


-----------------------------------------------------
-- MAIN 3D2D
-----------------------------------------------------
function ENT:Draw()
    local ang = self:GetAngles()
    local pos = self:GetPos()

    local drawPos = pos + ang:Forward() * 0.10
    local drawAng = Angle(ang.p, ang.y, ang.r)

    local claimed = self:GetIsClaimed()

    cam.Start3D2D(drawPos, drawAng, 0.25)

        -------------------------------------------------
        -- CLAIMED (ONLY GRAFFITI + TERRITORY NAME)
        -------------------------------------------------
        if claimed then
            local gid = self:GetOwnerGangId()
            local gang = Dubz.Gangs and Dubz.Gangs[gid]

            -- If gang hasn't synced yet
            if not gang then
                draw.SimpleText(
                    "Loading…",
                    "Trebuchet24",
                    191.5, -191.5,
                    Color(200,200,200),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
                cam.End3D2D()
                return
            end

            -- Draw graffiti (no background)
            if gang.graffiti and Dubz.Graffiti and Dubz.Graffiti.Draw2D then
                Dubz.Graffiti.Draw2D(10, -370, 360, 360, gang)
            end

            --[[
            -- Draw territory name above graffiti
            draw.SimpleText(
                self:GetTerritoryName(),
                "Trebuchet24",
                191.5, -370,
                Color(255,255,255),
                TEXT_ALIGN_CENTER
            )
            --]]

        -------------------------------------------------
        -- UNCLAIMED — ONLY TEXT, NO BACKGROUND
        -------------------------------------------------
        else
            if not self.ClaimProg then
                draw.SimpleText(
                    "Hold E to claim Territory",
                    "DermaLarge",
                    191.5, -191.5,
                    Color(0,255,0),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end

    cam.End3D2D()

    -----------------------------------------------------
    -- PROGRESS CIRCLE (kept as-is)
    -----------------------------------------------------
    if self.ClaimProg then
        cam.Start3D2D(drawPos, drawAng, 0.25)
            DrawCircle(191.5, -191.5, 80, Color(0,200,0,180), math.Clamp(self.ClaimProg, 0, 1))
        cam.End3D2D()
    end
end
end -- CLIENT