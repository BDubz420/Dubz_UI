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

    local cfgFonts = Dubz.Config.Graffiti.Fonts or {}
    local defaultFont = cfgFonts[1] or "DermaLarge"
    local font  = g.font or defaultFont

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

-- TERRITORY INCOME TICK
if SERVER then
    timer.Create("Dubz_Territory_IncomeTick", (Dubz.Config.Territories.Income.Interval or 60), 0, function()
        -- Make sure config + Dubz tables exist
        if not Dubz or not Dubz.Config or not Dubz.Config.Territories then return end

        local TCFG   = Dubz.Config.Territories
        local income = TCFG.Income or {}
        if income.Enabled == false then return end

        -- Make sure gang tables exist before touching them
        local gangs        = Dubz.Gangs
        local gangByMember = Dubz.GangByMember

        if not gangs or not gangByMember then
            -- Gangs system not ready yet, skip this tick
            return
        end

        local poles = ents.FindByClass(TCFG.EntityClass or "ent_dubz_graffiti_spot")

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
                if not anyOnline then continue end -- no payout this tick
            end

            ----------------------------------------------------
            -- COLLECT ONLINE MEMBERS (FOR MEMBER SHARE)
            ----------------------------------------------------
            local onlineMembers = {}
            if income.GiveOnlineMembers ~= false then
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and gangByMember[p:SteamID64()] == gid then
                        table.insert(onlineMembers, p)
                    end
                end
            end

            ----------------------------------------------------
            -- FIRE MAIN PAYOUT HOOK
            ----------------------------------------------------
            hook.Run(
                "Dubz_Gang_TerritoryPayout",
                gid,
                ent,
                income.TotalPerTick or 0,
                onlineMembers
            )
        end
    end)
end

-------------------------------------------------
-- CLIENT DRAW: used by the territory entity
-------------------------------------------------
if CLIENT then

-- Fonts
surface.CreateFont("Dubz_Graffiti_Main", {
    font = "Capture it",   -- change to your graffiti font (make sure it's installed)
    size = 64,
    weight = 800,
    antialias = true,
    extended = true,
})

surface.CreateFont("Dubz_Graffiti_Outline", {
    font = "Capture it",
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
function Dubz.Graffiti.Draw2D(x, y, w, h, gang)
    if not gang then return end
    gang.graffiti = gang.graffiti or {}

    local data  = gang.graffiti
    local text  = data.text  or gang.name or "Gang"
    local font  = data.font  or "Trebuchet24"
    local scale = tonumber(data.scale or 1)
    local effect = data.effect or "Clean"

    ---------------------------------------------------------
    -- CREATE THE SCALED FONT (unique per gang)
    ---------------------------------------------------------
    local scaledFontName = font .. "_scaled_" .. tostring(scale)

    if not dubz_font_cache then dubz_font_cache = {} end

    if not dubz_font_cache[scaledFontName] then
        surface.CreateFont(scaledFontName, {
            font = font,
            size = math.floor(48 * scale),
            weight = 800,
            antialias = true,
            extended = true
        })
        dubz_font_cache[scaledFontName] = true
    end

    ---------------------------------------------------------
    -- GANG COLOR
    ---------------------------------------------------------
    local col = gang.color or { r = 255, g = 255, b = 255 }
    local mainColor = Color(col.r, col.g, col.b)

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
