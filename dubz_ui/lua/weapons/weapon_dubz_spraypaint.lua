if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Gang Spray Paint"
SWEP.Author    = "Dubz UI"
SWEP.Instructions = "Hold attack while aiming at a territory to claim or clean."
SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.UseHands = true
SWEP.ViewModel = "models/props_junk/propane_tank001a.mdl"
SWEP.WorldModel = "models/props_junk/propane_tank001a.mdl"
SWEP.ViewModelFOV = 62
SWEP.HoldType = "slam"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary = SWEP.Primary

SWEP.IsDubzSpraypaint = true

function SWEP:SetupDataTables()
    self:NetworkVar("Int", 0, "SprayUses")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    if self:GetSprayUses() == 0 then
        self:SetSprayUses(3)
    end
    self:SetModelScale(0.5, 0)
end

function SWEP:Deploy()
    if self:GetSprayUses() == 0 then
        self:SetSprayUses(3)
    end
    return true
end

function SWEP:PrimaryAttack()
    if self:GetSprayUses() <= 0 then
        if CLIENT then return end
        self.Owner:ChatPrint("This can is empty.")
        return
    end

    self:SetNextPrimaryFire(CurTime() + 0.15)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local tr = owner:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid(ent) or ent:GetClass() ~= "ent_dubz_graffiti_spot" then return end
    if tr.HitPos:DistToSqr(owner:GetPos()) > 40000 then return end -- ~200 units

    if ent.StartClaim then
        local gid = Dubz.GangByMember and Dubz.GangByMember[owner:SteamID64()]
        local mode = gid and "claim" or "clean"
        ent:StartClaim(owner, { key = IN_ATTACK, gang = gid, mode = mode })
    end

    if CLIENT then return end

    self:EmitSound("weapons/spraycan/spraycan.wav", 70, 100, 0.6)

    local col = Color(255, 255, 255)
    if Dubz and Dubz.GangByMember and owner.SteamID64 then
        local gid = Dubz.GangByMember[owner:SteamID64()]
        local g = Dubz.Gangs and Dubz.Gangs[gid]
        if g and g.color then
            col = Color(g.color.r or 255, g.color.g or 255, g.color.b or 255)
        end
    end

    local emitter = ParticleEmitter(tr.HitPos)
    if emitter then
        for i = 1, 8 do
            local p = emitter:Add("particle/particle_smokegrenade", tr.HitPos + tr.HitNormal * 2)
            if p then
                p:SetVelocity(VectorRand() * 20 + tr.HitNormal * 35)
                p:SetDieTime(0.6)
                p:SetStartAlpha(80)
                p:SetEndAlpha(0)
                p:SetStartSize(12)
                p:SetEndSize(2)
                p:SetColor(col.r, col.g, col.b)
            end
        end
        emitter:Finish()
    end
end

function SWEP:SecondaryAttack()
    return
end

function SWEP:ConsumeSprayUse()
    local uses = math.max(0, self:GetSprayUses() - 1)
    self:SetSprayUses(uses)
    if uses <= 0 and IsValid(self:GetOwner()) then
        self:GetOwner():ChatPrint("Your spray paint can is empty.")
        SafeRemoveEntity(self)
    end
end

function SWEP:DrawWorldModel()
    self:SetModelScale(0.5, 0)
    self:DrawModel()
end

function SWEP:PostDrawViewModel(vm, ply, weapon)
    vm:SetModelScale(0.5, 0)
end
