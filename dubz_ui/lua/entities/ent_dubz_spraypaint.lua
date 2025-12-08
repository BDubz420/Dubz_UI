AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Spray Paint Can"
ENT.Author    = "Dubz UI"
ENT.Spawnable = true

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_junk/propane_tank001a.mdl")
        self:SetModelScale(0.5, 0)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
    end

    function ENT:Use(ply)
        if not IsValid(ply) then return end

        local wep = ply:GetWeapon("weapon_dubz_spraypaint")
        if not IsValid(wep) then
            ply:Give("weapon_dubz_spraypaint")
            wep = ply:GetWeapon("weapon_dubz_spraypaint")
        end

        if IsValid(wep) and wep.SetSprayUses then
            wep:SetSprayUses(3)
        end

        ply:SelectWeapon("weapon_dubz_spraypaint")
        SafeRemoveEntity(self)
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
