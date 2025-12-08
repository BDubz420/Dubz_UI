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
    self:NetworkVar("Bool",   1, "IsAbandoned")
    self:NetworkVar("String", 0, "OwnerGangId")
    self:NetworkVar("String", 1, "OwnerGangName")

    -- NEW: Territory name
    self:NetworkVar("String", 2, "TerritoryName")
    self:NetworkVar("Float",  0, "GraffitiAlpha")
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
                        ent:ResetOwnership("Unclaimed Territory")
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
    self.TerritoryRecordId = nil
    self._territoryGang = ""
    self._lastPresence = CurTime()
    self._abandonStart = nil
    self:SetIsAbandoned(false)
    self:SetGraffitiAlpha(255)

    -- default placeholder name
    if self:GetTerritoryName() == "" then
        self:SetTerritoryName("Unnamed Territory")
    end
end

function ENT:ResetOwnership(forceName)
    local gid = self:GetOwnerGangId()
    if gid ~= "" and RemoveGangTerritory then
        RemoveGangTerritory(gid, self.TerritoryRecordId or self:GetTerritoryName())
    end
    self.TerritoryRecordId = nil
    self._territoryGang = ""
    self._abandonStart = nil
    self._lastPresence = CurTime()
    self:SetIsAbandoned(false)
    self:SetGraffitiAlpha(255)
    self:SetIsClaimed(false)
    self:SetOwnerGangId("")
    self:SetOwnerGangName("")
    if forceName then
        self:SetTerritoryName(forceName)
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

local function AlertOwners(self, terrName)
    if self:GetIsClaimed() and (not self._lastAlert or self._lastAlert < CurTime()) then
        local owners = {}
        for _, p in ipairs(player.GetAll()) do
            if not IsValid(p) then continue end
            if Dubz.GangByMember and Dubz.GangByMember[p:SteamID64()] == self:GetOwnerGangId() then
                table.insert(owners, p)
            end
        end

        for _, p in ipairs(owners) do
            p:ChatPrint(string.format("[Gang] Someone is attempting to claim %s!", terrName))
        end

        self._lastAlert = CurTime() + 10
    end
end

function ENT:StartClaim(ply, opts)
    if not IsValid(ply) then return end

    local sid = ply:SteamID64()
    local gid = (opts and opts.gang) or (Dubz.GangByMember and Dubz.GangByMember[sid])
    local isCleaning = (not gid) or (opts and opts.mode == "clean")

    if self:GetIsClaimed() and not isCleaning and self:GetOwnerGangId() == gid then
        ply:ChatPrint("Your gang already owns this territory.")
        return
    end

    if isCleaning and not self:GetIsClaimed() then
        ply:ChatPrint("There is nothing to clean here.")
        return
    end

    if not isCleaning and not gid then
        ply:ChatPrint("Make a gang first to claim this territory, then spray it to claim.")
        return
    end

    -- Only allow claims to start from the spray can (attack key). Cleaning can be E or spray.
    if not isCleaning and (not opts or opts.key ~= IN_ATTACK) then
        ply:ChatPrint("Equip your spray paint and hold attack while looking at the plate to claim.")
        return
    end

    if self:GetIsClaimed() and self:GetOwnerGangId() ~= gid and not isCleaning then
        local terrName = self:GetTerritoryName() ~= "" and self:GetTerritoryName() or "a territory"
        AlertOwners(self, terrName)
    end

    self.IsClaiming[ply] = {
        start   = CurTime(),
        gang    = gid or "",
        key     = (opts and opts.key) or IN_USE,
        mode    = isCleaning and "clean" or "claim",
    }
end

function ENT:Use(ply)
    if not IsValid(ply) then return end
    local hasGang = Dubz.GangByMember and Dubz.GangByMember[ply:SteamID64()]

    if not hasGang and self:GetIsClaimed() then
        -- Allow unganged players to clean with E
        self:StartClaim(ply, { key = IN_USE, mode = "clean" })
        ply:ChatPrint("Hold E to scrub the graffiti clean for a small payout.")
        return
    end

    if not hasGang then
        ply:ChatPrint("Clean the graffiti with E, or create a gang and spray your own tag.")
        return
    end

    ply:ChatPrint("Use the spray paint can and hold attack while looking at the plate to claim.")
end

function ENT:Think()
    local function ResetClientProgress(target)
        if not IsValid(target) then return end
        net.Start("Dubz_Graffiti_ClaimProgress")
            net.WriteEntity(self)
            net.WriteFloat(-1)
        net.Send(target)
    end

    for ply, data in pairs(self.IsClaiming) do

        if not IsValid(ply) then
            ResetClientProgress(ply)
            self.IsClaiming[ply] = nil
            continue
        end

        -- must keep aiming at entity while holding E/attack
        local tr = ply:GetEyeTrace()
        if tr.Entity ~= self then
            ResetClientProgress(ply)
            self.IsClaiming[ply] = nil
            continue
        end

        local key = data.key or IN_USE
        if not ply:KeyDown(key) then
            ResetClientProgress(ply)
            self.IsClaiming[ply] = nil
            continue
        end

        local prog = (CurTime() - data.start) / CLAIM_TIME
        self.ClaimProg = prog
        self.ProgTime  = CurTime()

        net.Start("Dubz_Graffiti_ClaimProgress")
            net.WriteEntity(self)
            net.WriteFloat(prog)
        net.Send(ply)

        if prog >= 1 then
            self:FinishClaim(ply, data.gang, data.mode)
            self.IsClaiming[ply] = nil
        end
    end

    -- Weathering / abandonment
    if self:GetIsClaimed() then
        local cfg = (Dubz.Config and Dubz.Config.Territories) or {}
        local abandon = cfg.Abandon or {}

        if not self._nextPresenceCheck or CurTime() >= self._nextPresenceCheck then
            local hasNearby = false
            local gid = self:GetOwnerGangId()
            local radius = (cfg.CaptureRadius or 250)
            local radiusSqr = radius * radius
            for _, p in ipairs(player.GetAll()) do
                if not IsValid(p) then continue end
                if Dubz.GangByMember and Dubz.GangByMember[p:SteamID64()] == gid then
                    if p:GetPos():DistToSqr(self:GetPos()) <= radiusSqr then
                        hasNearby = true
                        break
                    end
                end
            end

            self:RecordPresence(hasNearby, abandon)
            self._nextPresenceCheck = CurTime() + 1.0
        end
    end

    local gid = self:GetOwnerGangId()
    if gid ~= "" and (not Dubz.Gangs or not Dubz.Gangs[gid]) then
        self:ResetOwnership("Unclaimed Territory")
    end

    self:NextThink(CurTime())
    return true
end

function ENT:RecordPresence(hasNearby, abandonCfg)
    abandonCfg = abandonCfg or {}

    if not self:GetIsClaimed() then
        self._abandonStart = nil
        self:SetGraffitiAlpha(255)
        self:SetIsAbandoned(false)
        return
    end

    if hasNearby then
        self._lastPresence = CurTime()
        self._abandonStart = nil
        self:SetIsAbandoned(false)
        self:SetGraffitiAlpha(math.min(255, (self:GetGraffitiAlpha() or 255) + 30))
        return
    end

    local grace = abandonCfg.Grace or 60
    local fade  = math.max(30, abandonCfg.FadeTime or 120)

    if (CurTime() - self._lastPresence) < grace then return end

    if not self._abandonStart then
        self._abandonStart = CurTime()
    end

    local elapsed = CurTime() - self._abandonStart
    local t = math.Clamp(elapsed / fade, 0, 1)
    local alpha = math.floor(255 * (1 - t))
    self:SetGraffitiAlpha(alpha)
    self:SetIsAbandoned(true)

    if t >= 1 then
        self:ResetOwnership("Unclaimed Territory")
    end
end

function ENT:FinishClaim(ply, gid, mode)
    local cleaning = (mode == "clean") or (not gid or gid == "")
    local previous = self:GetOwnerGangId()
    if cleaning then
        self:ResetOwnership("Unclaimed Territory")
        if IsValid(ply) then
            if AddMoney then AddMoney(ply, 250) end
            ply:ChatPrint("You cleaned the graffiti. Create a gang to claim this spot next time.")
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep.ConsumeSprayUse then
                wep:ConsumeSprayUse()
            end
        end
        return
    end

    local gang = Dubz.Gangs and Dubz.Gangs[gid]
    if not gang then return end

    if self:GetIsClaimed() then
        self:ResetOwnership()
    end

    self:SetIsClaimed(true)
    self:SetIsAbandoned(false)
    self:SetGraffitiAlpha(255)
    self:SetOwnerGangId(gid)
    self:SetOwnerGangName(gang.name)
    self._lastPresence = CurTime()
    self._abandonStart = nil

    if AddGangTerritory then
        local pos = self:GetPos()
        local ang = self:GetAngles()
        local tid = AddGangTerritory(gid, {
            name = self:GetTerritoryName(),
            sprayer = ply:Nick(),
            time = os.time(),
            pos = { x = pos.x, y = pos.y, z = pos.z },
            ang = { p = ang.p, y = ang.y, r = ang.r }
        })
        self.TerritoryRecordId = tid
        self._territoryGang = gid
    end

    net.Start("Dubz_Graffiti_ClaimFinished")
        net.WriteEntity(self)
    net.Broadcast()

    if Dubz.GangAddXP then
        Dubz.GangAddXP(gid, "territory_claim")
    end

    local wep = IsValid(ply) and ply:GetActiveWeapon()
    if IsValid(wep) and wep.ConsumeSprayUse then
        wep:ConsumeSprayUse()
    end

    if previous ~= "" and Dubz.Gangs[previous] then
        local gWars = gang.wars
        if gWars and gWars.active and gWars.enemy == previous then
            local bonus = 750
            if IsValid(ply) then
                AddMoney(ply, bonus)
                ply:ChatPrint(string.format("[Gang] Claim bonus: You earned $%d for taking enemy territory!", bonus))
            end
        end
    end
end

function ENT:OnRemove()
    if self:GetIsClaimed() then
        self:ResetOwnership()
    end
end

end -- SERVER

hook.Add("Dubz_Gang_Disbanded", "Dubz_Territory_ResetOnDisband", function(gid)
    if not gid or gid == "" then return end

    for _, ent in ipairs(ents.FindByClass("ent_dubz_graffiti_spot")) do
        if IsValid(ent) and ent.GetOwnerGangId and ent:GetOwnerGangId() == gid then
            ent:ResetOwnership("Unclaimed Territory")
            ent.ClaimProg = nil
            ent.ProgTime  = nil
        end
    end
end)

-----------------------------------------------------
-- CLIENT
-----------------------------------------------------
if CLIENT then

local TerritoryHUD_Active = false
local TerritoryHUD_Ent = nil
local TerritoryHUD_End = 0
local TerritoryHUD_Lerp = 0
local TerritoryHUD_BlockUntilRelease = false

surface.CreateFont("DumpsterFont", {
    font = "Roboto",
    size = 32,
    weight = 600
})

-----------------------------------------------------
-- NET
-----------------------------------------------------
net.Receive("Dubz_Graffiti_ClaimProgress", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    local prog = net.ReadFloat()

    -- Reset / stop claiming
    if prog < 0 then
        TerritoryHUD_Active = false
        TerritoryHUD_Ent = nil
        TerritoryHUD_Lerp = 0
        return
    end

    -- Setup HUD tracking
    if TerritoryHUD_BlockUntilRelease then return end

    -- Setup HUD tracking
    TerritoryHUD_Active = true
    TerritoryHUD_Ent = ent
    TerritoryHUD_End = CurTime() + (1 - prog) * 4
end)

net.Receive("Dubz_Graffiti_ClaimFinished", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    TerritoryHUD_Active = false
    ent.ClaimProg = nil
    ent.ProgTime  = nil
end)

-----------------------------------------------------
-- MAIN 3D2D
-----------------------------------------------------
function ENT:Draw()
    local ang = self:GetAngles()
    local pos = self:GetPos()

    local drawPos = pos + ang:Forward() * 0.10
    local drawAng = Angle(ang.p, ang.y, ang.r)

    local claimed = self:GetIsClaimed()
    local alpha   = math.Clamp(self:GetGraffitiAlpha() or 255, 0, 255)

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
                Dubz.Graffiti.Draw2D(10, -370, 360, 360, gang, alpha)
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
                    "Spray to claim Territory",
                    "DermaLarge",
                    191.5, -191.5,
                    Color(0,255,0, alpha),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end

    cam.End3D2D()

    -----------------------------------------------------
    -- TERRITORY PROGRESS BAR
    -----------------------------------------------------
    if self.ClaimProg then
        -- Smooth lerp to make the bar animate cleanly
        TerritoryProgressLerp = Lerp(
            math.Clamp(FrameTime() * 10, 0, 1),
            TerritoryProgressLerp,
            math.Clamp(self.ClaimProg, 0, 1)
        )

        cam.Start3D2D(drawPos, drawAng, 0.25)

            local barW = 360
            local barH = 40
            local barX = 191.5 - barW/2
            local barY = -191.5 - 120

            -- background
            draw.RoundedBox(8, barX, barY, barW, barH, Color(0,0,0,180))

            -- fill based on progress
            local fillW = barW * TerritoryProgressLerp
            draw.RoundedBox(8, barX, barY, fillW, barH, Color(0,140,255,230))

            -- label text
            draw.SimpleText(
                "Claiming territory...",
                "DumpsterFont",
                191.5,
                barY + barH/2,
                Color(255,255,255),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

        cam.End3D2D()
    else
        -- reset lerp when not claiming
        TerritoryProgressLerp = 0
    end
end

hook.Add("Think", "Dubz_Territory_ClaimThink", function()
    if not TerritoryHUD_Active then return end
    if not IsValid(TerritoryHUD_Ent) then
        TerritoryHUD_Active = false
        return
    end

    if not (LocalPlayer():KeyDown(IN_USE) or LocalPlayer():KeyDown(IN_ATTACK)) then
        TerritoryHUD_Active = false
        return
    end

    -- Finished?
    if CurTime() >= TerritoryHUD_End then
        TerritoryHUD_Active = false
        
        -- Block HUD until E is released
        TerritoryHUD_BlockUntilRelease = true
    end
end)

hook.Add("HUDPaint", "Dubz_Territory_ClaimBar", function()
    if not TerritoryHUD_Active then return end

    local w = 400
    local h = 40
    local x = ScrW() / 2 - w / 2
    local y = ScrH() / 2 + 100

    -- Calculate progress based on remaining time
    local remaining = math.max(0, TerritoryHUD_End - CurTime())
    local total = 4   -- CLAIM_TIME
    local progress = 1 - (remaining / total)

    -- Smooth animation
    TerritoryHUD_Lerp = Lerp(FrameTime() * 8, TerritoryHUD_Lerp, progress)

    -- Background
    draw.RoundedBox(8, x, y, w, h, Color(0,0,0,180))

    -- Fill
    draw.RoundedBox(8, x, y, w * TerritoryHUD_Lerp, h, Color(0,140,255,230))

    -- Text
    draw.SimpleText(
        "Claiming territory...",
        "DumpsterFont",
        ScrW() / 2,
        y + h / 2,
        Color(255,255,255),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )
end)

hook.Add("Think", "Dubz_Territory_ClearBlock", function()
    if not TerritoryHUD_BlockUntilRelease then return end

    -- Player released E → remove block
    if not (LocalPlayer():KeyDown(IN_USE) or LocalPlayer():KeyDown(IN_ATTACK)) then
        TerritoryHUD_BlockUntilRelease = false
    end
end)

end -- CLIENT