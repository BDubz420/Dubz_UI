if not Dubz then Dubz = {} end
Dubz.Graffiti = Dubz.Graffiti or {}

-------------------------------------------------
-- SHARED HELPERS
-------------------------------------------------
function Dubz.Graffiti.GetGangGraffiti(gang)
    if not gang then return "Gang", "DermaLarge",
        1, { r = 255, g = 255, b = 255 } end

    local g = gang.graffiti or {}

    local text  = g.text
    if not text or text == "" then
        text = gang.name or "Gang"
    end

    local cfgFonts = Dubz.Config.GraffitiFonts or {}
    local defaultFont = (cfgFonts[1] and cfgFonts[1].id) or "DermaLarge"

    local font = g.font or defaultFont
    local valid = false
    for _, f in ipairs(cfgFonts) do
        if f.id == font then valid = true break end
    end
    if not valid then
        font = defaultFont
    end

    local scale = tonumber(g.scale) or 1

    local col = g.color or gang.color or { r = 255, g = 255, b = 255 }

    return text, font, scale, col
end

local function jitter(n, amount)
    return n + math.sin(CurTime() * 5 + n) * amount
end

-- What text to use for a gang's graffiti
function Dubz.Graffiti.GetTextForGang(gang)
    if not gang then return "???", Color(255,255,255) end

    local txt = (gang.graffiti and gang.graffiti.text and string.Trim(gang.graffiti.text) ~= "")
        and gang.graffiti.text
        or gang.name
        or "Gang"

    local colTbl = gang.color or {r=255,g=255,b=255}
    local col = Color(colTbl.r or 255, colTbl.g or 255, colTbl.b or 255)

    return txt, col
end

if SERVER then
    util.AddNetworkString("Dubz_Territory_PayoutTimer")

    local function BroadcastPayoutTimer(interval)
        local nextTick = CurTime() + interval
        Dubz.NextTerritoryPayout = nextTick

        net.Start("Dubz_Territory_PayoutTimer")
            net.WriteFloat(interval)
            net.WriteFloat(nextTick)
        net.Broadcast()
    end

    local function SendPayoutTimer(ply)
        if not IsValid(ply) then return end
        local interval = (Dubz.Config.Territories.Income.Interval or 60)
        local nextTick = Dubz.NextTerritoryPayout or (CurTime() + interval)

        net.Start("Dubz_Territory_PayoutTimer")
            net.WriteFloat(interval)
            net.WriteFloat(nextTick)
        net.Send(ply)
    end

    hook.Add("PlayerInitialSpawn", "Dubz_TerritoryTimerSync", function(ply)
        timer.Simple(2, function()
            SendPayoutTimer(ply)
        end)
    end)

    timer.Create("Dubz_Territory_IncomeTick", (Dubz.Config.Territories.Income.Interval or 60), 0, function()
        -- Make sure config + Dubz tables exist
        if not Dubz or not Dubz.Config or not Dubz.Config.Territories then return end

        local TCFG    = Dubz.Config.Territories
        local income  = TCFG.Income or {}
        local abandon = TCFG.Abandon or {}
        if income.Enabled == false then return end

        -- Make sure gang tables exist before touching them
        local gangs        = Dubz.Gangs
        local gangByMember = Dubz.GangByMember

        if not gangs or not gangByMember then
            -- Gangs system not ready yet, skip this tick
            return
        end

        local poles = ents.FindByClass(TCFG.EntityClass or "ent_dubz_graffiti_spot")
        local radius = (TCFG.CaptureRadius or 250)
        local radiusSqr = radius * radius

        for _, ent in ipairs(poles) do
            if not IsValid(ent) or not ent.GetIsClaimed or not ent:GetIsClaimed() then continue end

            local gid = ent.GetOwnerGangId and ent:GetOwnerGangId() or ""
            if not gid or gid == "" then continue end

            local gang = gangs[gid]
            if not gang then continue end

            ----------------------------------------------------
            -- REQUIRE ANY OWNER ONLINE? (optional)
            ----------------------------------------------------
            if income.RequireOwnerOnline then
                local anyOnline = false
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and gangByMember[p:SteamID64()] == gid then
                        anyOnline = true
                        break
                    end
                end
                if not anyOnline then
                    ent:SetIsAbandoned(true)
                    goto CONTINUE_TERR
                end
            end

            ----------------------------------------------------
            -- COLLECT NEARBY MEMBERS ONLY (FOR MEMBER SHARE)
            ----------------------------------------------------
            local nearbyMembers = {}
            if income.GiveOnlineMembers ~= false then
                for _, p in ipairs(player.GetAll()) do
                    if not IsValid(p) then continue end
                    if gangByMember[p:SteamID64()] ~= gid then continue end
                    if p:GetPos():DistToSqr(ent:GetPos()) <= radiusSqr then
                        table.insert(nearbyMembers, p)
                    end
                end
            end

            if ent.RecordPresence then
                ent:RecordPresence(#nearbyMembers > 0, abandon)
            end

            if #nearbyMembers == 0 then
                goto CONTINUE_TERR
            end

            if ent.GetIsAbandoned and ent:GetIsAbandoned() then
                goto CONTINUE_TERR
            end

            ----------------------------------------------------
            -- FIRE MAIN PAYOUT HOOK
            ----------------------------------------------------
            hook.Run(
                "Dubz_Gang_TerritoryPayout",
                gid,
                ent,
                income.TotalPerTick or 0,
                nearbyMembers
            )

            if Dubz.GangAddXP then
                Dubz.GangAddXP(gid, "territory_payout")
            end

            ::CONTINUE_TERR::
        end

        BroadcastPayoutTimer(Dubz.Config.Territories.Income.Interval or 60)
    end)

    BroadcastPayoutTimer(Dubz.Config.Territories.Income.Interval or 60)
end

-------------------------------------------------
-- CLIENT DRAW: used by the territory entity
-------------------------------------------------
if CLIENT then

net.Receive("Dubz_Territory_PayoutTimer", function()
    Dubz.TerritoryPayoutInterval = net.ReadFloat()
    Dubz.NextTerritoryPayout     = net.ReadFloat()
end)

-- graffiti font helpers (use configured font files and cache scaled variants)
local graffitiFontCache = {
    base = {},
    scaled = {}
}

local function GetGraffitiFontEntry(id)
    for _, f in ipairs(Dubz.Config.GraffitiFonts or {}) do
        if f.id == id then return f end
    end
    return nil
end

local function EnsureBaseFont(id)
    local entry = GetGraffitiFontEntry(id)
    if not entry then return "Trebuchet24" end

    local baseName = "DubzGraff_" .. entry.id .. "_Base"
    if graffitiFontCache.base[baseName] then return baseName end

    surface.CreateFont(baseName, {
        font = entry.file,
        size = 48,
        weight = 900,
        antialias = true,
        extended = true
    })

    graffitiFontCache.base[baseName] = true
    return baseName
end

local function EnsureScaledFont(id, scale)
    scale = math.max(0.5, tonumber(scale) or 1)

    local base = EnsureBaseFont(id)
    local scaleKey = string.format("%0.2f", scale)
    local scaledName = base .. "_S" .. scaleKey

    if graffitiFontCache.scaled[scaledName] then
        return scaledName
    end

    surface.CreateFont(scaledName, {
        font      = base,
        size      = math.floor(48 * scale),
        weight    = 900,
        antialias = true,
        extended  = true
    })

    graffitiFontCache.scaled[scaledName] = true
    return scaledName
end

-- Fonts
local defaultGraffitiFont = (Dubz.Config.GraffitiFonts[1] and Dubz.Config.GraffitiFonts[1].file) or "Roboto"
surface.CreateFont("Dubz_Graffiti_Main", {
    font = defaultGraffitiFont,
    size = 64,
    weight = 800,
    antialias = true,
    extended = true,
})

surface.CreateFont("Dubz_Graffiti_Outline", {
    font = defaultGraffitiFont,
    size = 64,
    weight = 800,
    antialias = true,
    blursize = 4,
    extended = true,
})

Dubz = Dubz or {}
Dubz.Graffiti = Dubz.Graffiti or {}

local matCache = {}

local function GetMat(path)
    if not matCache[path] then
        matCache[path] = Material(path, "smooth")
    end
    return matCache[path]
end

-- =========================================================
--   FIXED / UPDATED DRAW2D FUNCTION
-- =========================================================
function Dubz.Graffiti.Draw2D(x, y, w, h, gang, alphaOverride)
    if not gang then return end
    gang.graffiti = gang.graffiti or {}

    local data  = gang.graffiti
    local text  = data.text  or gang.name or "Gang"
    local fontId = data.font  or ((Dubz.Config.GraffitiFonts[1] and Dubz.Config.GraffitiFonts[1].id) or "Trebuchet24")
    local scale = tonumber(data.scale or 1)
    local effect = data.effect or "Clean"

    ---------------------------------------------------------
    -- CREATE THE SCALED FONT (unique per gang)
    ---------------------------------------------------------
    local scaledFontName = EnsureScaledFont(fontId, scale)
    data.fontScaled = scaledFontName

    ---------------------------------------------------------
    -- GANG COLOR
    ---------------------------------------------------------
    local col = gang.color or { r = 255, g = 255, b = 255 }
    local mainColor = Color(col.r, col.g, col.b, math.Clamp(alphaOverride or 255, 0, 255))

    ---------------------------------------------------------
    -- TEXT POSITIONING
    ---------------------------------------------------------
    local centerX = x + w * 0.5
    local centerY = y + h * 0.5

    ---------------------------------------------------------
    -- EFFECTS: Shadow, Outline, Jitter
    ---------------------------------------------------------
    if effect == "Shadow" then
        draw.SimpleText(text, scaledFontName,
            centerX + 3 * scale, centerY + 3 * scale,
            Color(0,0,0,200),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )

    elseif effect == "Outline" then
        local o = 3 * scale
        for _, offset in ipairs({
            {-o, 0}, {o, 0}, {0, -o}, {0, o},
            {-o, -o}, {-o, o}, {o, -o}, {o, o}
        }) do
            draw.SimpleText(text, scaledFontName,
                centerX + offset[1],
                centerY + offset[2],
                Color(0,0,0,255),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )
        end

    elseif effect == "Jitter" then
        local dx = math.sin(CurTime() * 6) * 2 * scale
        local dy = math.cos(CurTime() * 5) * 2 * scale
        centerX = centerX + dx
        centerY = centerY + dy
    end

    ---------------------------------------------------------
    -- MAIN GRAFFITI TEXT
    ---------------------------------------------------------
    draw.SimpleText(
        text,
        scaledFontName,
        centerX,
        centerY,
        mainColor,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )
end

-------------------------------------------------
-- SIMPLE EDITOR WINDOW (leaders only)
-- Call from your gangs tab button:
--   Dubz.Graffiti.OpenEditor(myGangId)
-------------------------------------------------
function Dubz.Graffiti.OpenEditor(gid)
    if not Dubz.Gangs or not gid or not Dubz.Gangs[gid] then return end
    local gang = Dubz.Gangs[gid]

    local frame = vgui.Create("DFrame")
    frame:SetSize(420, 360)
    frame:Center()
    frame:SetTitle("Edit Gang Graffiti")
    frame:MakePopup()

    -- PREVIEW
    local preview = vgui.Create("DPanel", frame)
    preview:SetSize(256, 256)
    preview:SetPos(20, 40)
    function preview:Paint(w, h)
        if Dubz.Graffiti.Draw2D then
            Dubz.Graffiti.Draw2D(0, 0, w, h, gang)
        end
    end

    -- TEXT INPUT
    local textEntry = vgui.Create("DTextEntry", frame)
    textEntry:SetPos(290, 60)
    textEntry:SetSize(110, 24)
    textEntry:SetUpdateOnType(true)

    local existing = (gang.graffiti and gang.graffiti.text) or gang.name or ""
    textEntry:SetText(existing)

    -- FONT CHOOSER
    local fontBox = vgui.Create("DComboBox", frame)
    fontBox:SetPos(290, 100)
    fontBox:SetSize(110, 24)
    fontBox:SetSortItems(false)

    local cfgFonts = Dubz.Config.Graffiti.Fonts or { "DermaLarge" }
    local currentFont = (gang.graffiti and gang.graffiti.font) or cfgFonts[1]

    for _, f in ipairs(cfgFonts) do
        fontBox:AddChoice(f, nil, f == currentFont)
    end

    -- SAVE BUTTON
    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos(290, 140)
    saveBtn:SetSize(110, 30)
    saveBtn:SetText("Save")

    local function updateTemp()
        gang.graffiti = gang.graffiti or {}
        gang.graffiti.text = string.sub(textEntry:GetValue() or "", 1, Dubz.Config.Graffiti.MaxTextLength or 24)
        gang.graffiti.font = fontBox:GetSelected() or currentFont
    end

    textEntry.OnValueChange = function()
        updateTemp()
        preview:InvalidateLayout(true)
    end

    fontBox.OnSelect = function(_, _, value)
        currentFont = value
        updateTemp()
        preview:InvalidateLayout(true)
    end

    saveBtn.DoClick = function()
        updateTemp()

        net.Start("Dubz_Gang_Action")
            net.WriteTable({
                cmd  = "setgraffiti",
                text = gang.graffiti.text or "",
                font = gang.graffiti.font or currentFont
            })
        net.SendToServer()

        frame:Close()
    end
end

end -- CLIENT
