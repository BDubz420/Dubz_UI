local function GetGangName(p)
    return p:GetNWString("DubzGang", "")
end

local function GetGangColor(p)
    local v = p:GetNWVector("DubzGangColor", Vector(1,1,1))
    return Color(v.x * 255, v.y * 255, v.z * 255)
end

hook.Add("PostDrawTranslucentRenderables", "Dubz_Overhead3D2D", function()
    if not Dubz.Config or not Dubz.Config.Overhead or not Dubz.Config.Overhead.Enabled then return end

    local cfg = Dubz.Config.Overhead
    local lp = LocalPlayer(); if not IsValid(lp) then return end

    for _, ply in ipairs(player.GetAll()) do
        if ply == lp or not ply:Alive() then continue end
        
        local d2 = lp:GetPos():DistToSqr(ply:GetPos())
        if d2 > cfg.MaxDistance * cfg.MaxDistance then continue end

        local gang = GetGangName(ply)
        local gangColor = (gang ~= "" and GetGangColor(ply)) or nil

        local pos = ply:EyePos() + Vector(0, 0, (cfg.HeightOffset or 18) + 8)
        local ang = Angle(0, lp:EyeAngles().y - 90, 90)
        local scale = (cfg.Scale or 0.1) * 1.25

        cam.Start3D2D(pos, ang, scale)

            -- distance fade
            local dist = math.sqrt(d2)
            local alpha = 255
            if dist > (cfg.MaxDistance * 0.75) then
                local t = math.Clamp((dist - cfg.MaxDistance * 0.75) / (cfg.MaxDistance * 0.25), 0, 1)
                alpha = math.floor(Lerp(t, 255, 30))
            end

            local name = ply:Nick()
            local job = (ply.getDarkRPVar and ply:getDarkRPVar("job")) or "Citizen"
            local jobCol = team.GetColor(ply:Team()) or Color(200,200,200)

            surface.SetFont("DubzHUD_Body")
            local prefix = gang ~= "" and "[" .. gang .. "] " or ""
            local tw = surface.GetTextSize(prefix .. name)

            -- Draw gang tag + player name
            if gang ~= "" then
                surface.SetFont("DubzHUD_Body")

                local gtw = surface.GetTextSize("[" .. gang .. "] ")
                draw.SimpleText("[" .. gang .. "] ", "DubzHUD_Body",
                    -tw / 2, -24,
                    Color(gangColor.r, gangColor.g, gangColor.b, alpha),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
                )

                draw.SimpleText(name, "DubzHUD_Body",
                    -tw / 2 + gtw, -24,
                    Color(255, 255, 255, alpha),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
                )
            else
                draw.SimpleText(name, "DubzHUD_Body",
                    0, -24,
                    Color(255, 255, 255, alpha),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            end

            -- Job title
            draw.SimpleText(job, "DubzHUD_Body",
                0, -2,
                Color(jobCol.r, jobCol.g, jobCol.b, alpha),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )

        cam.End3D2D()
    end
end)
