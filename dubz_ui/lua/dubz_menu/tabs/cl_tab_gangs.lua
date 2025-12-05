if not Dubz then Dubz = {} end
include("dubz_menu/gangs/sh_gangs.lua")

--------------------------------------------------------
-- Fonts (extra ones used ONLY here)
--------------------------------------------------------
if not Dubz._GangFonts then
    Dubz._GangFonts = true

    surface.CreateFont("DubzHUD_Title", {
        font   = "Roboto Bold",
        size   = 24,
        weight = 800
    })

    surface.CreateFont("DubzHUD_Label", {
        font   = "Roboto",
        size   = 16,
        weight = 500
    })

    surface.CreateFont("DubzHUD_Tag", {
        font   = "Roboto",
        size   = 14,
        weight = 400
    })

    surface.CreateFont("DubzHUD_BodyBold", {
        font   = "Roboto Bold",
        size   = 18,
        weight = 600
    })
end

--------------------------------------------------------
-- Client cache (backed by Dubz globals so entities can use Dubz.Gangs)
--------------------------------------------------------
Dubz.Gangs    = Dubz.Gangs    or {}
Dubz.MyGangId = Dubz.MyGangId or ""
Dubz.MyRank   = Dubz.MyRank   or 0

--------------------------------------------------------
-- Helpers
--------------------------------------------------------

local function SendAction(tbl)
    net.Start("Dubz_Gang_Action")
    net.WriteTable(tbl)
    net.SendToServer()
end

local function GetMyGang()
    if Dubz.GetMyGang then
        return Dubz.GetMyGang()
    end
    return (Dubz.MyGangId ~= "" and Dubz.Gangs[Dubz.MyGangId]) or nil
end

local function IsLeaderC()
    if Dubz.IsLeaderC then
        return Dubz.IsLeaderC()
    end
    local g = GetMyGang()
    if not g then return false end
    return (Dubz.MyRank or 0) >= (Dubz.GangRanks.Leader or 3)
end

-- Simple UI refresh helper so the active panel can re-layout when data changes
local function RefreshGangUI()
    if not Dubz then return end
    if not IsValid(Dubz.ActiveGangPanel) then return end
    local pnl = Dubz.ActiveGangPanel

    pnl:InvalidateLayout(true)
    pnl:InvalidateParent(true)

    timer.Simple(0, function()
        if IsValid(pnl) then
            pnl:InvalidateLayout(true)
            pnl:InvalidateParent(true)
        end
    end)
end

-- Territories / graffiti spots owned by this gang (CLIENT-SIDE VIEW)
local function GetGangTerritories(gid)
    if not gid or gid == "" then return {} end

    local list = {}

    local g = Dubz.Gangs and Dubz.Gangs[gid]
    if g and istable(g.territories) then
        for _, info in pairs(g.territories) do
            local name = tostring(info and info.name or "")
            if name ~= "" then
                table.insert(list, name)
            end
        end
    end

    if #list > 0 then
        table.sort(list, function(a, b)
            return string.lower(a) < string.lower(b)
        end)
        return list
    end

    -- Fallback: query territory entities
    for _, ent in ipairs(ents.FindByClass("ent_dubz_graffiti_spot")) do
        if IsValid(ent) and ent.GetOwnerGangId and ent:GetOwnerGangId() == gid then
            local name = ""
            if ent.GetTerritoryName then
                name = ent:GetTerritoryName() or ""
            end
            if name == "" then
                name = "Unnamed Territory"
            end
            table.insert(list, name)
        end
    end

    table.sort(list, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return list
end

local lastRevision = -1

local function QueueMenuRefresh(force)
    local rev = (Dubz and Dubz.GangRevision) or 0
    if not force and rev == lastRevision then return end
    lastRevision = rev

    RefreshGangUI()
    if Dubz and Dubz.RequestMenuRefresh then
        Dubz.RequestMenuRefresh("gangs")
    end
end

hook.Add("Dubz_Gangs_FullSync",   "Dubz_Gangs_Tab_FullRefresh",   function() QueueMenuRefresh(true) end)
hook.Add("Dubz_Gangs_MyStatus",   "Dubz_Gangs_Tab_StatusRefresh", QueueMenuRefresh)
hook.Add("Dubz_Gangs_GangUpdated","Dubz_Gangs_Tab_UpdateRefresh", QueueMenuRefresh)

--------------------------------------------------------
-- UI drawing helpers
--------------------------------------------------------

local function PanelFrame(x, y, w, h, accent, side)
    side = side or "left"

    draw.RoundedBox(8, x, y, w, h, Color(18,18,18,235))

    surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
    if side == "top" then
        surface.DrawRect(x, y, w, 3)
    else -- left
        surface.DrawRect(x, y, 3, h)
    end
end

local function ColorToTable(c)
    return { r = c.r, g = c.g, b = c.b }
end

--------------------------------------------------------
-- CREATE GANG UI
--------------------------------------------------------
local function DrawCreateGang(pnl, w, y, accent)
    local bw, bh = w - 24, 170

    PanelFrame(12, y, bw, bh, accent, "top")
    draw.SimpleText("Create Organization", "DubzHUD_Title", 24, y + 10, accent)

    if not pnl._create then
        pnl._create = {}

        -- Name
        local name = vgui.Create("DTextEntry", pnl)
        if Dubz.HookTextEntry then Dubz.HookTextEntry(name) end
        name:SetSize(260, 24)
        name:SetPlaceholderText("Gang Name (max 24)")

        -- Desc
        local desc = vgui.Create("DTextEntry", pnl)
        if Dubz.HookTextEntry then Dubz.HookTextEntry(desc) end
        desc:SetSize(bw - 24 - 24 - 220, 24)
        desc:SetPlaceholderText("Description (optional)")

        -- Color
        local col = vgui.Create("DColorMixer", pnl)
        col:SetSize(190, 100)
        col:SetPalette(false)
        col:SetAlphaBar(false)
        col:SetWangs(true)
        if Dubz.GetAccentColor then
            col:SetColor(Dubz.GetAccentColor())
        end

        -- Button
        local btn = vgui.Create("DButton", pnl)
        btn:SetText("")
        btn:SetSize(200, 24)
        function btn:Paint(w2,h2)
            draw.RoundedBox(6, 0, 0, w2, h2, accent)
            draw.SimpleText(
                "Create ($"..(Dubz.Config.Gangs.StartCost or 0)..")",
                "DubzHUD_Small", w2 / 2, h2 / 2,
                Color(255,255,255),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )
        end
        function btn:DoClick()
            local gName  = name:GetText() or ""
            local gDesc  = desc:GetText() or ""
            local gColor = col:GetColor()

            gName = string.Trim(gName)
            gDesc = string.Trim(gDesc)

            if gName == "" then
                if Dubz.Notify then Dubz.Notify("Gang name cannot be empty!", "error") end
                surface.PlaySound("buttons/button10.wav")
                return
            end

            if #gName > 24 then
                if Dubz.Notify then Dubz.Notify("Gang name must be 24 characters or fewer.", "error") end
                return
            end

            if #gDesc > 128 then
                if Dubz.Notify then Dubz.Notify("Description too long (max 128 chars).", "error") end
                return
            end

            if not gColor or not gColor.r then
                if Dubz.Notify then Dubz.Notify("Please choose a valid gang color.", "error") end
                return
            end

            local cost  = Dubz.Config.Gangs.StartCost or 0
            local money = (LocalPlayer().getDarkRPVar and LocalPlayer():getDarkRPVar("money")) or 0
            if money < cost then
                if Dubz.Notify then Dubz.Notify("You do not have enough money to create a gang!", "error") end
                surface.PlaySound("buttons/button10.wav")
                return
            end

            SendAction({
                cmd   = "create",
                name  = gName,
                desc  = gDesc,
                color = ColorToTable(gColor)
            })
        end

        pnl._create.name = name
        pnl._create.desc = desc
        pnl._create.col  = col
        pnl._create.btn  = btn
    end

    -- positions (so they follow y)
    if IsValid(pnl._create.name) then
        pnl._create.name:SetPos(24, y + 52)
    end
    if IsValid(pnl._create.desc) then
        pnl._create.desc:SetPos(24, y + 82)
    end
    if IsValid(pnl._create.col) then
        pnl._create.col:SetPos(w - 24 - 200, y + 44)
    end
    if IsValid(pnl._create.btn) then
        pnl._create.btn:SetPos(24, y + 116)
    end

    return y + bh + 12
end

--------------------------------------------------------
-- TERRITORIES
--------------------------------------------------------
local function DrawTerritories(pnl, w, y, accent, g)
    local territories = GetGangTerritories(g.id)
    local count       = #territories

    local rowH  = 22
    local baseH = 52
    local totalH = baseH + math.max(1, count) * rowH

    PanelFrame(12, y, w - 24, totalH, accent, "left")
    draw.SimpleText("Territories Controlled", "DubzHUD_Title", 28, y + 10, accent)

    local yy = y + 40

    if count == 0 then
        draw.SimpleText(
            "Your gang hasn’t claimed any territories yet.",
            "DubzHUD_Body",
            28, yy,
            Color(220,220,220)
        )
    else
        for _, name in ipairs(territories) do
            draw.SimpleText("• " .. name, "DubzHUD_Body", 28, yy, Color(230,230,230))
            yy = yy + rowH
        end
    end

    return y + totalH + 12
end

--------------------------------------------------------
-- GRAFFITI FONTS
--------------------------------------------------------
function EnsureGraffitiFont(gang)
    if not gang or not gang.graffiti then return "DubzHUD_Header" end

    local fontID = gang.graffiti.font or "DubzHUD_Header"
    local base = "DubzGraff_" .. fontID .. "_Base"

    local scale = math.max(0.5, gang.graffiti.scale or 1)
    local fontName = base .. "_S" .. tostring(scale)

    _G.DubzGraffitiFonts = _G.DubzGraffitiFonts or {}

    if not _G.DubzGraffitiFonts[fontName] then
        surface.CreateFont(fontName, {
            font      = base,
            size      = math.floor(40 * scale),
            weight    = 900,
            antialias = true,
            extended  = true
        })
        _G.DubzGraffitiFonts[fontName] = true
    end

    gang.graffiti.fontScaled = fontName

    return fontName
end


--------------------------------------------------------
-- FULL GRAFFITI / IDENTITY EDITOR
--------------------------------------------------------
local function OpenGraffitiEditor(accent)
    local g = GetMyGang()
    if not g then return end
    if not IsLeaderC() then return end

    g.graffiti = g.graffiti or {}
    g.graffiti.scale        = g.graffiti.scale        or 1
    g.graffiti.outlineSize  = g.graffiti.outlineSize  or 1
    g.graffiti.shadowOffset = g.graffiti.shadowOffset or 2
    g.graffiti.effect       = g.graffiti.effect       or "Clean"
    g.graffiti.color        = g.graffiti.color        or g.color or { r=255,g=255,b=255 }
    g.graffiti.text         = g.graffiti.text         or g.name or "Gang"

    EnsureGraffitiFont(g)

    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(760, 470)
    frame:Center()
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(15,15,15,245))
        surface.SetDrawColor(accent)
        surface.DrawRect(0, 0, w, 4)

        draw.SimpleText("Gang Identity Studio", "DubzHUD_Title", 16, 10, accent)
        draw.SimpleText("Customize graffiti, fonts and gang color with live preview.",
            "DubzHUD_Tag", 16, 34, Color(200,200,200))
    end

    -----------------------------------------------------
    -- PREVIEW
    -----------------------------------------------------
    local preview = vgui.Create("DPanel", frame)
    preview:SetPos(20, 60)
    preview:SetSize(320, 220)
    preview.Paint = function(self, pw, ph)
        draw.RoundedBox(6, 0, 0, pw, ph, Color(25, 25, 25, 220))

        local text = g.graffiti.text or g.name or ""
        local font = EnsureGraffitiFont(g)
        local eff  = g.graffiti.effect or "Clean"
        local col  = g.graffiti.color or g.color or { r=255,g=255,b=255 }

        local x = pw / 2
        local y = ph / 2

        if eff == "Shadow" then
            local off = g.graffiti.shadowOffset or 2
            draw.SimpleText(text, font, x + off, y + off,
                Color(0,0,0,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif eff == "Outline" then
            local thick = g.graffiti.outlineSize or 1
            for ox = -thick, thick do
                for oy = -thick, thick do
                    if ox ~= 0 or oy ~= 0 then
                        draw.SimpleText(text, font, x + ox, y + oy,
                            Color(0,0,0,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
        end

        draw.SimpleText(
            text, font,
            x, y,
            Color(col.r or 255, col.g or 255, col.b or 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    local ctrlX = 360
    local ctrlW = 370

    -----------------------------------------------------
    -- TEXT
    -----------------------------------------------------
    local txt = vgui.Create("DTextEntry", frame)
    txt:SetPos(ctrlX, 60)
    txt:SetSize(ctrlW, 24)
    txt:SetText(g.graffiti.text or g.name or "")
    txt:SetUpdateOnType(true)
    txt.OnValueChange = function(_, val)
        val = string.sub(val or "", 1, 24)
        g.graffiti.text = val
        preview:InvalidateLayout(true)
    end

    -----------------------------------------------------
    -- FONT
    -----------------------------------------------------
    local fontBox = vgui.Create("DComboBox", frame)
    fontBox:SetPos(ctrlX, 90)
    fontBox:SetSize(ctrlW, 24)
    fontBox:SetSortItems(false)

    local fonts = {}
    for _, f in ipairs(Dubz.Config.GraffitiFonts) do
        table.insert(fonts, f.id)
    end

    local defaultFont = g.graffiti.font or fonts[1] or "DubzHUD_Header"
    g.graffiti.font = defaultFont
    EnsureGraffitiFont(g)
    fontBox:SetValue(defaultFont)

    for _, f in ipairs(fonts) do
        fontBox:AddChoice(f, nil, f == defaultFont)
    end

    fontBox.OnSelect = function(_, _, val)
        g.graffiti.font = val
        g.graffiti.fontScaled = nil
        EnsureGraffitiFont(g)
        preview:InvalidateLayout(true)
    end

    -----------------------------------------------------
    -- SIZE
    -----------------------------------------------------
    local scale = vgui.Create("DNumSlider", frame)
    scale:SetPos(ctrlX, 118)
    scale:SetSize(ctrlW, 26)
    scale:SetMin(0.5)
    scale:SetMax(3)
    scale:SetDecimals(2)
    scale:SetText("Graffiti Size")
    scale:SetValue(g.graffiti.scale or 1)
    scale.OnValueChanged = function(_, val)
        g.graffiti.scale = val
        g.graffiti.fontScaled = nil
        EnsureGraffitiFont(g)
        preview:InvalidateLayout(true)
    end

    -----------------------------------------------------
    -- EFFECT
    -----------------------------------------------------
    local effectBox = vgui.Create("DComboBox", frame)
    effectBox:SetPos(ctrlX, 146)
    effectBox:SetSize(ctrlW, 24)
    effectBox:SetValue(g.graffiti.effect or "Clean")
    effectBox:AddChoice("Clean")
    effectBox:AddChoice("Shadow")
    effectBox:AddChoice("Outline")

    local outline = vgui.Create("DNumSlider", frame)
    outline:SetPos(ctrlX, 174)
    outline:SetSize(ctrlW, 26)
    outline:SetMin(1)
    outline:SetMax(10)
    outline:SetDecimals(0)
    outline:SetText("Outline Thickness")
    outline:SetValue(g.graffiti.outlineSize or 1)
    outline.OnValueChanged = function(_, val)
        g.graffiti.outlineSize = val
        preview:InvalidateLayout(true)
    end

    local shadow = vgui.Create("DNumSlider", frame)
    shadow:SetPos(ctrlX, 202)
    shadow:SetSize(ctrlW, 26)
    shadow:SetMin(1)
    shadow:SetMax(10)
    shadow:SetDecimals(0)
    shadow:SetText("Shadow Offset")
    shadow:SetValue(g.graffiti.shadowOffset or 2)
    shadow.OnValueChanged = function(_, val)
        g.graffiti.shadowOffset = val
        preview:InvalidateLayout(true)
    end

    local function RefreshEffectVisibility()
        local eff = g.graffiti.effect or "Clean"
        outline:SetVisible(eff == "Outline")
        shadow:SetVisible(eff == "Shadow")
    end

    effectBox.OnSelect = function(_,_,val)
        g.graffiti.effect = val
        RefreshEffectVisibility()
        preview:InvalidateLayout(true)
    end

    RefreshEffectVisibility()

    -----------------------------------------------------
    -- COLORS: GANG + GRAFFITI
    -----------------------------------------------------
    local gangColorLabel = vgui.Create("DLabel", frame)
    gangColorLabel:SetPos(ctrlX, 260)
    gangColorLabel:SetSize(120, 16)
    gangColorLabel:SetText("Gang Color")
    gangColorLabel:SetFont("DubzHUD_Label")

    local gangMixer = vgui.Create("DColorMixer", frame)
    gangMixer:SetPos(ctrlX, 278)
    gangMixer:SetSize(180, 90)
    gangMixer:SetPalette(false)
    gangMixer:SetAlphaBar(false)
    gangMixer:SetWangs(true)
    local gc = g.color or { r=accent.r, g=accent.g, b=accent.b }
    gangMixer:SetColor(Color(gc.r or 255, gc.g or 255, gc.b or 255))

    local graffitiLabel = vgui.Create("DLabel", frame)
    graffitiLabel:SetPos(ctrlX + 190, 260)
    graffitiLabel:SetSize(160, 16)
    graffitiLabel:SetText("Graffiti Text Color")
    graffitiLabel:SetFont("DubzHUD_Label")

    local colMixer = vgui.Create("DColorMixer", frame)
    colMixer:SetPos(ctrlX + 190, 278)
    colMixer:SetSize(180, 90)
    colMixer:SetPalette(false)
    colMixer:SetAlphaBar(false)
    colMixer:SetWangs(true)
    colMixer:SetColor(Color(
        g.graffiti.color.r or 255,
        g.graffiti.color.g or 255,
        g.graffiti.color.b or 255
    ))
    colMixer.ValueChanged = function(_, col)
        g.graffiti.color = { r=col.r, g=col.g, b=col.b }
        preview:InvalidateLayout(true)
    end

    -----------------------------------------------------
    -- SAVE
    -----------------------------------------------------
    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos(20, 400)
    saveBtn:SetSize(720, 34)
    saveBtn:SetText("")
    saveBtn.Paint = function(_, w2, h2)
        draw.RoundedBox(6, 0, 0, w2, h2, accent)
        draw.SimpleText("Save Identity", "DubzHUD_Small", w2/2, h2/2,
            Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    saveBtn.DoClick = function()
        local gangCol = gangMixer:GetColor()
        local textCol = colMixer:GetColor()

        g.graffiti.color = { r=textCol.r, g=textCol.g, b=textCol.b }

        -- update gang base color
        SendAction({
            cmd   = "setcolor",
            color = { r=gangCol.r, g=gangCol.g, b=gangCol.b }
        })

        -- update graffiti
        SendAction({
            cmd          = "setgraffiti",
            text         = g.graffiti.text or "",
            font         = g.graffiti.font or "DubzHUD_Header",
            fontScaled   = EnsureGraffitiFont(g),
            scale        = g.graffiti.scale or 1,
            effect       = g.graffiti.effect or "Clean",
            outlineSize  = g.graffiti.outlineSize,
            shadowOffset = g.graffiti.shadowOffset,
            color        = g.graffiti.color or g.color or { r=255,g=255,b=255 }
        })

        frame:Close()
    end
end

--------------------------------------------------------
-- GRAFFITI PREVIEW (compact, opens editor)
--------------------------------------------------------
local function DrawGraffitiPreview(pnl, w, y, accent, g)
    local bh = 110
    PanelFrame(12, y, w - 24, bh, accent, "top")

    draw.SimpleText("Gang Graffiti", "DubzHUD_Title", 24, y + 10, accent)
    draw.SimpleText("Visual identity shown on territories & HUD.",
        "DubzHUD_Tag", 24, y + 34, Color(190,190,190))

    if not pnl._graffitiPreview then
        local preview = vgui.Create("DPanel", pnl)
        preview:SetSize(260, 50)
        preview.Paint = function(self, pw, ph)
            local gang = GetMyGang()
            if not gang then return end

            local font = EnsureGraffitiFont(gang)
            local text = (gang.graffiti and gang.graffiti.text) or gang.name or "Gang"
            local col  = (gang.graffiti and gang.graffiti.color) or gang.color or { r=255,g=255,b=255 }

            draw.SimpleText(
                text,
                font,
                pw / 2, ph / 2,
                Color(col.r or 255, col.g or 255, col.b or 255),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )
        end
        pnl._graffitiPreview = preview
        if pnl.RegisterGangElem then pnl:RegisterGangElem(preview) end
    end

    pnl._graffitiPreview:SetPos(24, y + 52)

    -- Open editor button (leaders only)
    if IsLeaderC() then
        if not pnl._graffitiEdit then
            local b = vgui.Create("DButton", pnl)
            b:SetText("")
            b:SetSize(170, 26)
            function b:Paint(w2,h2)
                draw.RoundedBox(6, 0, 0, w2, h2, accent)
                draw.SimpleText(
                    "Open Identity Studio",
                    "DubzHUD_Small",
                    w2/2, h2/2,
                    Color(255,255,255),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            end
            function b:DoClick()
                OpenGraffitiEditor(accent)
            end
            pnl._graffitiEdit = b
            if pnl.RegisterGangElem then pnl:RegisterGangElem(b) end
        end

        pnl._graffitiEdit:SetPos(24 + 260 + 16, y + 60)
    end

    return y + bh + 12
end

--------------------------------------------------------
-- TOP OVERVIEW ROW: IDENTITY + WEALTH + STYLE
--------------------------------------------------------
local function DrawGangOverview(pnl, w, y, accent, g)
    if not g then return y end

    local total = w - 24
    local gap   = 12
    local rowH  = 120
    local colW  = (total - gap * 2) / 3

    ----------------------------------------------------
    -- Card 1: Identity
    ----------------------------------------------------
    local idX, idY = 12, y
    PanelFrame(idX, idY, colW, rowH, accent, "left")

    draw.SimpleText(g.name or "Gang", "DubzHUD_Title", idX + 16, idY + 10, accent)

    -- War-ready tag (big & visible)
    local warReadyText  = ""
    local warReadyColor = Color(255,80,80)
    if g.allowWars == false then
        warReadyText  = "NOT READY FOR WAR"
        warReadyColor = Color(170,170,170)
    else
        warReadyText  = "WAR READY"
        warReadyColor = Color(255,60,60)
    end
    draw.SimpleText(warReadyText, "DubzHUD_BodyBold", idX + 16, idY + 34, warReadyColor)

    local leaderName = "Unknown"
    if g.leaderSid64 and g.members and g.members[g.leaderSid64] then
        leaderName = g.members[g.leaderSid64].name or leaderName
    end
    local memberCount = table.Count(g.members or {})

    draw.SimpleText("Leader: " .. leaderName,
        "DubzHUD_Label", idX + 16, idY + 60, Color(230,230,230))
    draw.SimpleText("Members: " .. memberCount .. "/" .. (Dubz.Config.Gangs.MaxMembers or 12),
        "DubzHUD_Label", idX + 16, idY + 80, Color(200,200,200))

    ----------------------------------------------------
    -- Card 2: Wealth Analytics + Bank
    ----------------------------------------------------
    local wx, wy = idX + colW + gap, y
    PanelFrame(wx, wy, colW, rowH, accent, "left")

    draw.SimpleText("Wealth Analytics", "DubzHUD_Title", wx + 16, wy + 10, accent)

    local cleanAmt, dirtyAmt, bank = 0, 0, 0
    bank = math.max(0, tonumber(g.bank or 0) or 0)

    for sid64, _ in pairs(g.members or {}) do
        local ply = player.GetBySteamID64(sid64)
        if IsValid(ply) then
            local money = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
            local dirty = (ply.GetDirtyMoney and ply:GetDirtyMoney()) or 0
            cleanAmt = cleanAmt + math.max(0, tonumber(money) or 0)
            dirtyAmt = dirtyAmt + math.max(0, tonumber(dirty) or 0)
        elseif g._CachedWealth and g._CachedWealth[sid64] then
            local cached = g._CachedWealth[sid64]
            cleanAmt = cleanAmt + math.max(0, tonumber(cached.clean) or 0)
            dirtyAmt = dirtyAmt + math.max(0, tonumber(cached.dirty) or 0)
        end
    end

    local totalNet = bank + cleanAmt + dirtyAmt
    local cleanPct = (totalNet > 0) and math.floor(cleanAmt / totalNet * 100) or 0
    local dirtyPct = (totalNet > 0) and math.floor(dirtyAmt / totalNet * 100) or 0

    local fmt = DarkRP and DarkRP.formatMoney or function(v)
        return "$" .. tostring(math.floor(v or 0))
    end

    draw.SimpleText("Total Net Worth", "DubzHUD_Tag", wx + 16, wy + 34, Color(200,200,200))
    draw.SimpleText(fmt(totalNet), "DubzHUD_Money", wx + 16, wy + 50, Color(255,255,255))

    draw.SimpleText("Bank:  " .. fmt(bank), "DubzHUD_Label", wx + 16, wy + 80, accent)
    draw.SimpleText("Clean: " .. fmt(cleanAmt) .. " (" .. cleanPct .. "%)",
        "DubzHUD_Tag", wx + colW/2, wy + 52, Color(150,255,150))
    draw.SimpleText("Dirty: " .. fmt(dirtyAmt) .. " (" .. dirtyPct .. "%)",
        "DubzHUD_Tag", wx + colW/2, wy + 70, Color(255,150,150))

    ----------------------------------------------------
    -- Card 3: Style Snapshot (color swatch + editor)
    ----------------------------------------------------
    local sx, sy = wx + colW + gap, y
    PanelFrame(sx, sy, colW, rowH, accent, "left")

    draw.SimpleText("Style Snapshot", "DubzHUD_Title", sx + 16, sy + 10, accent)

    local gc = g.color or { r=accent.r, g=accent.g, b=accent.b }
    draw.RoundedBox(6, sx + 16, sy + 40, 40, 40,
        Color(gc.r or 255, gc.g or 255, gc.b or 255))
    surface.SetDrawColor(0,0,0,180)
    surface.DrawOutlinedRect(sx + 16, sy + 40, 40, 40)

    draw.SimpleText("Base Color", "DubzHUD_Tag", sx + 64, sy + 44, Color(220,220,220))
    draw.SimpleText("Open editor to tweak graffiti & color.",
        "DubzHUD_Tag", sx + 64, sy + 64, Color(190,190,190))

    if IsLeaderC() then
        if not pnl._styleEdit then
            local b = vgui.Create("DButton", pnl)
            b:SetText("")
            b:SetSize(130, 24)
            function b:Paint(w2,h2)
                draw.RoundedBox(6, 0, 0, w2, h2, accent)
                draw.SimpleText("Open Identity Studio", "DubzHUD_Small",
                    w2/2, h2/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            function b:DoClick()
                OpenGraffitiEditor(accent)
            end
            pnl._styleEdit = b
            if pnl.RegisterGangElem then pnl:RegisterGangElem(b) end
        end
        pnl._styleEdit:SetPos(sx + colW - 16 - 130, sy + rowH - 12 - 24)
    end

    return y + rowH + 16
end

--------------------------------------------------------
-- MEMBERS (list + invite row)
--------------------------------------------------------
local function DrawMembers(pnl, w, y, accent, g)
    local cardW = w - 24
    local baseH = 72
    local rowH  = 22
    local count = table.Count(g.members or {})
    local cardH = baseH + math.max(1, count) * rowH

    PanelFrame(12, y, cardW, cardH, accent, "left")
    draw.SimpleText("Members", "DubzHUD_Title", 28, y + 10, accent)

    local listY = y + 40
    local sx    = 28

    -- Members list
    for sid, m in SortedPairs(g.members or {}) do
        local name = m.name or sid
        local title = Dubz.GangGetTitle and Dubz.GangGetTitle(g, m.rank or 1) or ("Rank "..tostring(m.rank or 1))

        draw.SimpleText(name, "DubzHUD_Body", sx, listY, Color(230,230,230))
        draw.SimpleText(title, "DubzHUD_Tag", sx + 260, listY + 2, Color(180,180,255))

        listY = listY + rowH
    end

    -- Invite + promote/demote/kick row (leaders only)
    if IsLeaderC() then
        if not pnl._inviteCombo then
            local combo = vgui.Create("DComboBox", pnl)
            combo:SetSize(220, 22)
            combo:SetSortItems(false)
            pnl._inviteCombo = combo
            if pnl.RegisterGangElem then pnl:RegisterGangElem(combo) end
        end

        if not pnl._inviteBtn then
            local bt = vgui.Create("DButton", pnl)
            bt:SetText("")
            bt:SetSize(80, 22)
            function bt:Paint(w2,h2)
                draw.RoundedBox(6, 0, 0, w2, h2, accent)
                draw.SimpleText("Invite","DubzHUD_Small",w2/2,h2/2,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end
            function bt:DoClick()
                local combo = pnl._inviteCombo
                if not IsValid(combo) then return end

                local _, sid = combo:GetSelected()
                if not sid or sid == "" then
                    if Dubz.Notify then Dubz.Notify("Select a player to invite.", "error") end
                    surface.PlaySound("buttons/button10.wav")
                    return
                end

                SendAction({ cmd = "invite", target = sid })
            end
            pnl._inviteBtn = bt
            if pnl.RegisterGangElem then pnl:RegisterGangElem(bt) end
        end

        -- promote / demote / kick target (member dropdown)
        if not pnl._memberCombo then
            local combo = vgui.Create("DComboBox", pnl)
            combo:SetSize(220, 22)
            combo:SetSortItems(false)
            pnl._memberCombo = combo
            if pnl.RegisterGangElem then pnl:RegisterGangElem(combo) end
        end

        -- buttons
        local function MakeRoleButton(key, label, col, cmd)
            if pnl[key] then return end
            local b = vgui.Create("DButton", pnl)
            b:SetText("")
            b:SetSize(80, 22)
            function b:Paint(w2,h2)
                draw.RoundedBox(6, 0, 0, w2, h2, col)
                draw.SimpleText(label, "DubzHUD_Small", w2/2, h2/2,
                    Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            function b:DoClick()
                local combo = pnl._memberCombo
                if not IsValid(combo) then return end
                local _, sid = combo:GetSelected()
                if not sid or sid == "" then
                    if Dubz.Notify then Dubz.Notify("Select a member first.", "error") end
                    surface.PlaySound("buttons/button10.wav")
                    return
                end
                SendAction({ cmd = cmd, target = sid })
            end
            pnl[key] = b
            if pnl.RegisterGangElem then pnl:RegisterGangElem(b) end
        end

        MakeRoleButton("_promoteBtn", "Promote", accent, "promote")
        MakeRoleButton("_demoteBtn",  "Demote", Color(120,120,120), "demote")
        MakeRoleButton("_kickBtn",    "Kick",   Color(190,80,80),   "kick")

        -- positions (bottom row, not blocking list)
        local rowY = y + cardH - 30

        if IsValid(pnl._inviteCombo) then
            pnl._inviteCombo:SetPos(28, rowY)
        end
        if IsValid(pnl._inviteBtn) then
            pnl._inviteBtn:SetPos(28 + 228, rowY)
        end

        if IsValid(pnl._memberCombo) then
            pnl._memberCombo:SetPos(28 + 228 + 96, rowY)
        end
        if IsValid(pnl._promoteBtn) then
            pnl._promoteBtn:SetPos(28 + 228 + 96 + 228, rowY)
        end
        if IsValid(pnl._demoteBtn) then
            pnl._demoteBtn:SetPos(28 + 228 + 96 + 228 + 86, rowY)
        end
        if IsValid(pnl._kickBtn) then
            pnl._kickBtn:SetPos(28 + 228 + 96 + 228 + 86 + 86, rowY)
        end

        -- Refresh invite + member dropdowns ONLY when counts change
        if IsValid(pnl._inviteCombo) and IsValid(pnl._memberCombo) then
            local onlineCount = #player.GetAll()
            local memberCount = table.Count(g.members or {})

            local hash = onlineCount * 1000 + memberCount
            if pnl._lastInviteHash ~= hash then
                local combo = pnl._inviteCombo
                combo:Clear()

                local myGang = GetMyGang() or g or {}
                for _, ply in ipairs(player.GetAll()) do
                    if IsValid(ply) then
                        local sid = ply:SteamID64()
                        if not myGang.members or not myGang.members[sid] then
                            combo:AddChoice(ply:Nick(), sid)
                        end
                    end
                end

                pnl._lastInviteHash = hash
            end

            -- Member dropdown (for promote/demote/kick)
            local hash2 = memberCount
            if pnl._lastMemberHash ~= hash2 then
                local mcombo = pnl._memberCombo
                mcombo:Clear()
                for sid, m in pairs(g.members or {}) do
                    if sid ~= g.leaderSid64 then
                        mcombo:AddChoice(m.name or sid, sid)
                    end
                end
                pnl._lastMemberHash = hash2
            end
        end
    end

    return y + cardH + 12
end

--------------------------------------------------------
-- RANKS
--------------------------------------------------------
local function DrawRanks(pnl, w, y, accent, g)
    local cardW = w - 24
    local cardH = 120
    PanelFrame(12, y, cardW, cardH, accent, "left")

    draw.SimpleText("Ranks", "DubzHUD_Title", 28, y + 10, accent)

    local rt = g.rankTitles or Dubz.DefaultRankTitles
    local x  = 40
    local y2 = y + 46

    for r = 3,1,-1 do
        local title = rt[r] or Dubz.DefaultRankTitles[r] or ("Rank "..r)

        draw.SimpleText(
            string.format("%s (%d)", title, r),
            "DubzHUD_Body",
            x, y2,
            Color(230,230,230)
        )

        if IsLeaderC() then
            local key = "_rank_"..r
            if not pnl[key] then
                local te = vgui.Create("DTextEntry", pnl)
                if Dubz.HookTextEntry then Dubz.HookTextEntry(te) end
                te:SetSize(160, 22)
                te:SetText(title)
                function te:OnEnter()
                    local txt = string.Trim(self:GetText() or "")
                    if txt == "" then
                        if Dubz.Notify then Dubz.Notify("Rank title cannot be empty.", "error") end
                        return
                    end
                    if #txt > 32 then
                        if Dubz.Notify then Dubz.Notify("Rank title must be 32 characters or fewer.", "error") end
                        return
                    end
                    SendAction({ cmd = "setranktitle", rank = r, title = txt })
                end
                pnl[key] = te
                if pnl.RegisterGangElem then pnl:RegisterGangElem(te) end
            end
            if IsValid(pnl[key]) then
                pnl[key]:SetPos(x, y2 + 24)
            end
        end

        x = x + 230
    end

    return y + cardH + 12
end

--------------------------------------------------------
-- BANK (simple card, already summarized in top row)
--------------------------------------------------------
local function DrawMoney(pnl, w, y, accent, g)
    local cardW = w - 24
    local cardH = 90
    PanelFrame(12, y, cardW, cardH, accent, "left")

    draw.SimpleText("Gang Bank", "DubzHUD_Title", 28, y + 10, accent)

    draw.SimpleText(
        "Balance: $" .. tostring(g.bank or 0),
        "DubzHUD_Body",
        28, y + 38,
        Color(230,230,230)
    )

    -- Deposit (everyone) & Withdraw (leaders)
    if not pnl._dep then
        local d = vgui.Create("DTextEntry", pnl)
        if Dubz.HookTextEntry then Dubz.HookTextEntry(d) end
        d:SetNumeric(true)
        d:SetSize(120, 22)

        local db = vgui.Create("DButton", pnl)
        db:SetText("")
        db:SetSize(90, 22)
        function db:Paint(w2,h2)
            draw.RoundedBox(6, 0, 0, w2, h2, accent)
            draw.SimpleText("Deposit","DubzHUD_Small",w2/2,h2/2,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
        function db:DoClick()
            local raw = pnl._dep:GetText() or ""
            raw = string.Trim(raw)
            local amt = tonumber(raw)

            if not amt or amt <= 0 then
                if Dubz.Notify then Dubz.Notify("Enter a valid amount to deposit.", "error") end
                surface.PlaySound("buttons/button10.wav")
                return
            end

            local money = LocalPlayer().getDarkRPVar and LocalPlayer():getDarkRPVar("money") or 0
            if amt > money then
                if Dubz.Notify then Dubz.Notify("You don't have that much money to deposit.", "error") end
                surface.PlaySound("buttons/button10.wav")
                return
            end

            SendAction({
                cmd    = "deposit",
                amount = math.floor(amt)
            })
        end

        pnl._dep    = d
        pnl._depBtn = db
        if pnl.RegisterGangElem then
            pnl:RegisterGangElem(d)
            pnl:RegisterGangElem(db)
        end
    end

    if IsValid(pnl._dep)    then pnl._dep:SetPos(220, y + 38) end
    if IsValid(pnl._depBtn) then pnl._depBtn:SetPos(346, y + 38) end

    if IsLeaderC() then
        if not pnl._wd then
            local d = vgui.Create("DTextEntry", pnl)
            if Dubz.HookTextEntry then Dubz.HookTextEntry(d) end
            d:SetNumeric(true)
            d:SetSize(120, 22)

            local db = vgui.Create("DButton", pnl)
            db:SetText("")
            db:SetSize(90, 22)
            function db:Paint(w2,h2)
                draw.RoundedBox(6, 0, 0, w2, h2, Color(160,160,160))
                draw.SimpleText("Withdraw","DubzHUD_Small",w2/2,h2/2,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end
            function db:DoClick()
                local gang        = GetMyGang() or g or {}
                local currentBank = gang.bank or 0

                local raw = pnl._wd:GetText() or ""
                raw = string.Trim(raw)
                local amt = tonumber(raw)

                if not amt or amt <= 0 then
                    if Dubz.Notify then Dubz.Notify("Enter a valid amount to withdraw.", "error") end
                    surface.PlaySound("buttons/button10.wav")
                    return
                end

                if amt > currentBank then
                    if Dubz.Notify then Dubz.Notify("Your gang bank doesn't have that much money.", "error") end
                    surface.PlaySound("buttons/button10.wav")
                    return
                end

                SendAction({
                    cmd    = "withdraw",
                    amount = math.floor(amt)
                })
            end

            pnl._wd    = d
            pnl._wdBtn = db
            if pnl.RegisterGangElem then
                pnl:RegisterGangElem(d)
                pnl:RegisterGangElem(db)
            end
        end

        if IsValid(pnl._wd)    then pnl._wd:SetPos(450, y + 38) end
        if IsValid(pnl._wdBtn) then pnl._wdBtn:SetPos(576, y + 38) end
    end

    return y + cardH + 12
end

--------------------------------------------------------
-- WARS
--------------------------------------------------------
local function DrawWars(pnl, w, y, accent, g)
    local cardW = w - 24
    local cardH = 150
    PanelFrame(12, y, cardW, cardH, accent, "left")

    draw.SimpleText("Gang Wars", "DubzHUD_Title", 28, y + 10, accent)

    local leftX  = 28
    local rightX = 28 + cardW * 0.5
    local yy     = y + 40

    -- STATUS TEXT
    local statusText = "Peace"
    if g.wars and g.wars.active then
        local rem = math.max(0, math.floor((g.wars.ends or CurTime()) - CurTime()))
        local enemyName = g.wars.enemy
        if Dubz.Gangs[enemyName] then
            enemyName = Dubz.Gangs[enemyName].name or enemyName
        end
        statusText = ("At war with: %s (%ds left)"):format(enemyName, rem)
    end
    draw.SimpleText("Status: "..statusText, "DubzHUD_Body", leftX, yy, Color(230,230,230))
    yy = yy + 26

    if IsLeaderC() then
        ------------------------------------------------
        -- Target dropdown (enemy gang)
        ------------------------------------------------
        if not pnl._target then
            pnl._target = vgui.Create("DComboBox", pnl)
            pnl._target:SetSize(200, 22)
            pnl._target:SetSortItems(false)
            if pnl.RegisterGangElem then pnl:RegisterGangElem(pnl._target) end
        end

        if not pnl._warBtn then
            local btn = vgui.Create("DButton", pnl)
            btn:SetText("")
            btn:SetSize(100, 22)
            function btn:Paint(w2,h2)
                local gang = GetMyGang() or g
                local col  = (gang.wars and gang.wars.active)
                    and Color(190,80,80)
                    or accent
                local txt  = (gang.wars and gang.wars.active) and "Forfeit War" or "Declare War"
                draw.RoundedBox(6, 0, 0, w2, h2, col)
                draw.SimpleText(txt, "DubzHUD_Small", w2/2, h2/2,
                    Color(255,255,255), TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end
            function btn:DoClick()
                local gang = GetMyGang() or g

                if gang.wars and gang.wars.active then
                    SendAction({ cmd = "forfeit_war" })
                    return
                end

                local warsCfg      = Dubz.Config.Wars or {}
                local minMembers   = warsCfg.MinMembers or 1
                local declareCost  = warsCfg.DeclareCost or 0
                local myMembers    = table.Count(gang.members or {})
                local myMoney      = (LocalPlayer().getDarkRPVar and LocalPlayer():getDarkRPVar("money") or 0)

                if myMembers < minMembers then
                    if Dubz.Notify then Dubz.Notify("Your gang does not meet the member requirement!", "error") end
                    return
                end

                if myMoney < declareCost then
                    if Dubz.Notify then Dubz.Notify("You do not have enough money!", "error") end
                    return
                end

                if gang.allowWars == false then
                    if Dubz.Notify then Dubz.Notify("Your gang has wars disabled!", "error") end
                    return
                end

                local _, enemyGid = pnl._target:GetSelected()
                if not enemyGid then
                    if Dubz.Notify then Dubz.Notify("Select a gang first!", "error") end
                    return
                end

                SendAction({ cmd = "declare_war", enemy = enemyGid })
            end

            pnl._warBtn = btn
            if pnl.RegisterGangElem then pnl:RegisterGangElem(btn) end
        end

        pnl._target:SetPos(leftX, yy)
        pnl._warBtn:SetPos(leftX + 208, yy)

        yy = yy + 32

        ------------------------------------------------
        -- Opt-in checkbox (allow wars)
        ------------------------------------------------
        if not pnl._warToggle then
            local cb = vgui.Create("DCheckBoxLabel", pnl)
            cb:SetText(" Allow other gangs to declare war on us")
            cb:SetFont("DubzHUD_Body")
            cb:SetTextColor(Color(200,200,200))
            function cb:OnChange(b)
                SendAction({
                    cmd     = "set_war_toggle",
                    enabled = b and true or false
                })
            end
            pnl._warToggle = cb
            if pnl.RegisterGangElem then pnl:RegisterGangElem(cb) end
        end

        pnl._warToggle:SetPos(leftX, yy)
        pnl._warToggle:SetChecked(g.allowWars ~= false)

        ------------------------------------------------
        -- Requirements (right column)
        ------------------------------------------------
        local warsCfg      = Dubz.Config.Wars or {}
        local minMembers   = warsCfg.MinMembers or 1
        local declareCost  = warsCfg.DeclareCost or 0
        local myMembers    = table.Count(g.members or {})
        local myMoney      = (LocalPlayer().getDarkRPVar and LocalPlayer():getDarkRPVar("money") or 0)

        local reqY = y + 40
        draw.SimpleText("Requirements", "DubzHUD_BodyBold", rightX, reqY, accent)
        reqY = reqY + 26

        local function Req(label, ok)
            draw.SimpleText(ok and "✔" or "✘", "DubzHUD_Body", rightX, reqY,
                ok and Color(120,255,120) or Color(255,120,120))
            draw.SimpleText(label, "DubzHUD_Body", rightX + 22, reqY,
                Color(230,230,230))
            reqY = reqY + 20
        end

        Req("Members: "..myMembers.."/"..minMembers, myMembers >= minMembers)
        Req("Cost: $"..declareCost, myMoney >= declareCost)
        Req("Wars Enabled", g.allowWars ~= false)

        -- Refresh enemy dropdown only when gang list changes
        local hash = 0
        for gid2, gg in pairs(Dubz.Gangs or {}) do
            hash = hash + (gg.allowWars == false and 1 or 2)
        end
        if pnl._target._lastHash ~= hash then
            pnl._target:Clear()
            for gid2, gg in pairs(Dubz.Gangs or {}) do
                if gid2 ~= g.id and (gg.allowWars ~= false) then
                    pnl._target:AddChoice(gg.name or gid2, gid2)
                end
            end
            pnl._target._lastHash = hash
        end
    end

    return y + cardH + 12
end

--------------------------------------------------------
-- Tab Registration
--------------------------------------------------------
Dubz._GangTabSynced = Dubz._GangTabSynced or false

Dubz.RegisterTab("gangs", Dubz.Config.Gangs.TabTitle or "Gangs", "users", function(parent)
    if not (Dubz.Config.Gangs and Dubz.Config.Gangs.Enabled) then return end

    local accent = Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(37,150,190)

    -- Scroll panel wrapper
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)
    scroll:DockMargin(12,12,12,12)

    ---------------------------------------
    -- Scrollbar Styling (match market)
    ---------------------------------------
    do
        local sbar = scroll:GetVBar()

        function sbar:Paint(w,h)
            local bg = (Dubz.Colors and Dubz.Colors.Background) or Color(0,0,0,150)
            surface.SetDrawColor(bg)
            surface.DrawRect(0,0,w,h)
        end

        function sbar.btnGrip:Paint(w,h)
            local acc = (Dubz.Colors and Dubz.Colors.Accent) or accent
            local col = self:IsHovered()
                and Color(acc.r + 25, acc.g + 25, acc.b + 25, 230)
                or  Color(acc.r,      acc.g,      acc.b,      200)
            draw.RoundedBox(6, 2, 0, w - 4, h, col)
        end

        function sbar.btnUp:Paint() end
        function sbar.btnDown:Paint() end
    end

    -- Single canvas panel inside the scroll
    local pnl = vgui.Create("DPanel", scroll)
    pnl:SetWide(scroll:GetWide())
    pnl:Dock(TOP)
    pnl:SetTall(2000) -- will be shrunk dynamically
    pnl.Paint = nil
    scroll:AddItem(pnl)

    Dubz.ActiveGangPanel = pnl
    pnl._gangElems       = {}

    function pnl:RegisterGangElem(elem)
        if not IsValid(elem) then return end
        table.insert(self._gangElems, elem)
    end

    function pnl:SetGangVisible(b)
        for _, e in ipairs(self._gangElems) do
            if IsValid(e) then e:SetVisible(b) end
        end
    end

    function pnl:SetCreateVisible(b)
        if not self._create then return end
        for _, e in pairs(self._create) do
            if IsValid(e) then e:SetVisible(b) end
        end
    end

    -- MAIN PAINT / LAYOUT
    function pnl:Paint(w, h)
        local g = GetMyGang()
        local y = 12

        surface.SetDrawColor(12,12,12,230)
        surface.DrawRect(0,0,w,h)

        if not g then
            self:SetGangVisible(false)
            self:SetCreateVisible(true)
            y = DrawCreateGang(self, w, y, accent)
        else
            self:SetCreateVisible(false)
            self:SetGangVisible(true)

            y = DrawGangOverview(self, w, y, accent, g)
            y = DrawGraffitiPreview(self, w, y, accent, g)
            y = DrawMembers(self, w, y, accent, g)
            y = DrawRanks(self, w, y, accent, g)
            y = DrawMoney(self, w, y, accent, g)
            y = DrawWars(self, w, y, accent, g)
            y = DrawTerritories(self, w, y, accent, g)

            -- Footer actions
            if IsLeaderC() then
                if not self._disband then
                    local b = vgui.Create("DButton", self)
                    b:SetText("")
                    b:SetSize(120, 22)
                    function b:Paint(w2,h2)
                        draw.RoundedBox(6, 0, 0, w2, h2, Color(180,60,60))
                        draw.SimpleText("Disband","DubzHUD_Small",w2/2,h2/2,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                    end
                    function b:DoClick()
                        Derma_Query("Disband this gang?","Confirm",
                            "Yes", function() SendAction({ cmd = "disband" }) end,
                            "No")
                    end
                    self._disband = b
                    self:RegisterGangElem(b)
                end
                if IsValid(self._disband) then
                    self._disband:SetPos(24, y)
                end
            else
                if not self._leave then
                    local b = vgui.Create("DButton", self)
                    b:SetText("")
                    b:SetSize(120, 22)
                    function b:Paint(w2,h2)
                        draw.RoundedBox(6, 0, 0, w2, h2, Color(120,120,120))
                        draw.SimpleText("Leave","DubzHUD_Small",w2/2,h2/2,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                    end
                    function b:DoClick()
                        Derma_Query("Leave this gang?","Confirm",
                            "Yes", function() SendAction({ cmd = "leave" }) end,
                            "No")
                    end
                    self._leave = b
                    self:RegisterGangElem(b)
                end
                if IsValid(self._leave) then
                    self._leave:SetPos(24, y)
                end
            end
        end

        self:SetTall(math.max(y + 40, parent:GetTall()))
    end

    if not Dubz._GangTabSynced then
        net.Start("Dubz_Gang_RequestSync")
        net.SendToServer()
        Dubz._GangTabSynced = true
    end
end)
