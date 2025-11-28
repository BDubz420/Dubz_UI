if not Dubz then Dubz = {} end
include("dubz_menu/gangs/sh_gangs.lua")

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
    return (Dubz.MyRank or 0) >= Dubz.GangRanks.Leader
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

    -- Use the graffiti territory entity as the source of truth
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

hook.Add("Dubz_Gangs_FullSync", "Dubz_Gangs_Tab_FullRefresh", function()
    QueueMenuRefresh(true)
end)
hook.Add("Dubz_Gangs_MyStatus", "Dubz_Gangs_Tab_StatusRefresh", QueueMenuRefresh)
hook.Add("Dubz_Gangs_GangUpdated", "Dubz_Gangs_Tab_UpdateRefresh", QueueMenuRefresh)

--------------------------------------------------------
-- UI drawing helpers
--------------------------------------------------------
local function Bubble(x,y,w,h)
    if Dubz.DrawBubble then
        Dubz.DrawBubble(x,y,w,h, Color(24,24,24,220))
    else
        draw.RoundedBox(12, x,y,w,h, Color(24,24,24,220))
    end
end

local function ColorToTable(c)
    return { r = c.r, g = c.g, b = c.b }
end

--------------------------------------------------------
-- CREATE GANG UI
--------------------------------------------------------
local function DrawCreateGang(pnl, w, y, accent)
    local bw, bh = w, 160

    Bubble(12, y, bw - 24, bh)
    draw.SimpleText("Create Organization", "DubzHUD_Header", 24, y + 10, accent)

    if not pnl._create then
        pnl._create = {}

        -- Name
        local name = vgui.Create("DTextEntry", pnl)
        if Dubz.HookTextEntry then Dubz.HookTextEntry(name) end
        name:SetPos(24, y + 52)
        name:SetSize(260, 24)
        name:SetPlaceholderText("Gang Name (max 24)")

        -- Desc
        local desc = vgui.Create("DTextEntry", pnl)
        if Dubz.HookTextEntry then Dubz.HookTextEntry(desc) end
        desc:SetPos(24, y + 82)
        desc:SetSize(bw - 24 - 24 - 220, 24)
        desc:SetPlaceholderText("Description (optional)")

        -- Color
        local col = vgui.Create("DColorMixer", pnl)
        col:SetPos(bw - 24 - 200, y + 40)
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
        btn:SetPos(24, y + 114)
        btn:SetSize(200, 24)
        function btn:Paint(w,h)
            draw.RoundedBox(6, 0, 0, w, h, accent)
            draw.SimpleText(
                "Create ($"..(Dubz.Config.Gangs.StartCost or 0)..")",
                "DubzHUD_Small", w / 2, h / 2,
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
    else
        if IsValid(pnl._create.name) then pnl._create.name:SetPos(24, y + 52) end
        if IsValid(pnl._create.desc) then pnl._create.desc:SetPos(24, y + 82) end
        if IsValid(pnl._create.col)  then pnl._create.col:SetPos(bw - 24 - 200, y + 40) end
        if IsValid(pnl._create.btn)  then pnl._create.btn:SetPos(24, y + 114) end
    end

    return y + bh + 12
end

--------------------------------------------------------
-- GANG TERRITORIES (GRAFFITI SYSTEM)
--------------------------------------------------------
local function DrawTerritories(pnl, w, y, accent, g)
    local territories = GetGangTerritories(g.id)
    local count = #territories

    local rowH    = 28
    local headerH = 50
    local totalH  = headerH + (count > 0 and (rowH * count) or rowH) + 12

    Bubble(12, y, w - 24, totalH)
    draw.SimpleText("Territories Controlled", "DubzHUD_Header", 24, y + 10, accent)

    local yy = y + headerH

    if count == 0 then
        draw.SimpleText(
            "Your gang hasn’t sprayed (claimed) any territories yet.",
            "DubzHUD_Body",
            24, yy,
            Color(220, 220, 220)
        )
        yy = yy + rowH
    else
        for _, name in ipairs(territories) do
            draw.SimpleText(
                "• " .. name,
                "DubzHUD_Body",
                24, yy,
                Color(230, 230, 230)
            )
            yy = yy + rowH
        end
    end

    return y + totalH + 12
end

--------------------------------------------------------
-- GANG GRAFFITI PREVIEW (Option 2 data model)
--------------------------------------------------------
local function DrawGraffitiPreview(pnl, w, y, accent, g)
    local bh = 160
    Bubble(12, y, w - 24, bh)

    draw.SimpleText("Gang Graffiti", "DubzHUD_Header", 24, y + 10, accent)

    --------------------------------------------------------
    -- PREVIEW PANEL
    --------------------------------------------------------
    if not pnl._graffitiPreview then
        local preview = vgui.Create("DPanel", pnl)
        preview:SetSize(260, 100)
        preview.Paint = function(self, pw, ph)
            local gang = GetMyGang()
            if not gang then return end

            if Dubz.DrawBubble then
                Dubz.DrawBubble(0, 0, pw, ph, Color(0,0,0,180))
            else
                draw.RoundedBox(8, 0, 0, pw, ph, Color(0,0,0,180))
            end

            if Dubz.Graffiti and Dubz.Graffiti.Draw2D then
                Dubz.Graffiti.Draw2D(0, 0, pw, ph, gang)
            else
                draw.SimpleText(
                    gang.name or "Gang",
                    "DubzHUD_Header", pw / 2, ph / 2,
                    Color(255,255,255),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            end
        end

        pnl._graffitiPreview = preview
        if pnl.RegisterGangElem then pnl:RegisterGangElem(preview) end
    end

    pnl._graffitiPreview:SetPos(24, y + 40)

    --------------------------------------------------------
    -- EDIT BUTTON (leaders only)
    --------------------------------------------------------
    if IsLeaderC() then
        if not pnl._graffitiEdit then
            local b = vgui.Create("DButton", pnl)
            b:SetText("")
            b:SetSize(160, 28)
            b.Paint = function(self, pw, ph)
                draw.RoundedBox(6, 0, 0, pw, ph, accent)
                draw.SimpleText(
                    "Edit Graffiti",
                    "DubzHUD_Small",
                    pw / 2, ph / 2,
                    Color(255,255,255),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            end

            function b:DoClick()
                local g = GetMyGang()
                if not g then return end

                g.graffiti = g.graffiti or {}
                g.graffiti.bgMat        = g.graffiti.bgMat        or "brick/brick_model"
                g.graffiti.scale        = g.graffiti.scale        or 1
                g.graffiti.outlineSize  = g.graffiti.outlineSize  or 1
                g.graffiti.shadowOffset = g.graffiti.shadowOffset or 2
                g.graffiti.effect       = g.graffiti.effect       or "Clean"
                g.graffiti.color        = g.graffiti.color        or g.color or { r = 255, g = 255, b = 255 }

                ---------------------------------------------------------
                -- FRAME
                ---------------------------------------------------------
                local frame = vgui.Create("DFrame")
                frame:SetTitle("")
                frame:SetSize(600, 420)
                frame:Center()
                frame:MakePopup()
                frame.Paint = function(self, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, Color(25,25,25,240))
                    draw.SimpleText("Edit Gang Graffiti", "DubzHUD_Header", 16, 10, accent)
                end

                ---------------------------------------------------------
                -- PREVIEW PANEL
                ---------------------------------------------------------
                local bgMatName = g.graffiti.bgMat or "brick/brick_model"

                local preview = vgui.Create("DPanel", frame)
                preview:SetPos(20, 40)
                preview:SetSize(260, 200)
                preview.Paint = function(self, pw, ph)
                    -- BG
                    surface.SetMaterial(Material(bgMatName, "smooth"))
                    surface.SetDrawColor(255,255,255)
                    surface.DrawTexturedRect(0, 0, pw, ph)

                    local text  = g.graffiti.text or g.name or ""
                    local font  = g.graffiti.fontScaled or g.graffiti.font or "Trebuchet24"
                    local eff   = g.graffiti.effect or "Clean"
                    local col   = g.graffiti.color or g.color or { r = 255, g = 255, b = 255 }

                    local x = pw / 2
                    local y = ph / 2

                    -- EFFECTS
                    if eff == "Shadow" then
                        local off = g.graffiti.shadowOffset or 2
                        draw.SimpleText(text, font, x + off, y + off,
                            Color(0,0,0,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

                    -- MAIN TEXT
                    draw.SimpleText(text, font, x, y,
                        Color(col.r, col.g, col.b),
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                ---------------------------------------------------------
                -- TEXT ENTRY
                ---------------------------------------------------------
                local txt = vgui.Create("DTextEntry", frame)
                txt:SetPos(300, 40)
                txt:SetSize(260, 24)
                txt:SetText(g.graffiti.text or g.name or "")
                txt.OnChange = function()
                    g.graffiti.text = string.sub(txt:GetText(), 1, 24)
                    preview:InvalidateLayout(true)
                end

                ---------------------------------------------------------
                -- FONT DROPDOWN
                ---------------------------------------------------------
                local fontBox = vgui.Create("DComboBox", frame)
                fontBox:SetPos(300, 70)
                fontBox:SetSize(260, 24)
                fontBox:SetValue(g.graffiti.font or "Trebuchet24")

                local fonts = {
                    "Trebuchet18","Trebuchet24","Trebuchet32",
                    "DermaDefaultBold","DermaLarge",
                    "ChatFont","BudgetLabel"
                }

                for _, f in ipairs(fonts) do
                    fontBox:AddChoice(f)
                end

                fontBox.OnSelect = function(_,_,val)
                    g.graffiti.font = val

                    -- re-create scaled font if we have a scale
                    local scaleVal = g.graffiti.scale or 1
                    g.graffiti.fontScaled = "DubzGraffiti_Font_" .. math.floor(scaleVal * 100)

                    surface.CreateFont(g.graffiti.fontScaled, {
                        font = g.graffiti.font or "Trebuchet24",
                        size = math.floor(24 * scaleVal),
                        weight = 800,
                        antialias = true
                    })

                    preview:InvalidateLayout(true)
                end

                ---------------------------------------------------------
                -- SIZE (FONT SCALE) SLIDER
                ---------------------------------------------------------
                local scale = vgui.Create("DNumSlider", frame)
                scale:SetPos(300, 100)
                scale:SetSize(260, 30)
                scale:SetMin(0.5)
                scale:SetMax(3)
                scale:SetText("Graffiti Size")
                scale:SetDecimals(2)
                scale:SetValue(g.graffiti.scale or 1)

                scale.OnValueChanged = function(_, val)
                    g.graffiti.scale = val

                    -- create dynamic font name
                    g.graffiti.fontScaled = "DubzGraffiti_Font_" .. math.floor(val * 100)

                    -- register dynamic font
                    surface.CreateFont(g.graffiti.fontScaled, {
                        font = g.graffiti.font or "Trebuchet24",
                        size = math.floor(24 * val),  -- scale actual pixel size
                        weight = 800,
                        antialias = true
                    })

                    preview:InvalidateLayout(true)
                end

                ---------------------------------------------------------
                -- EFFECT DROPDOWN
                ---------------------------------------------------------
                local effectBox = vgui.Create("DComboBox", frame)
                effectBox:SetPos(300, 135)
                effectBox:SetSize(260, 24)
                effectBox:SetValue(g.graffiti.effect or "Clean")

                effectBox:AddChoice("Clean")
                effectBox:AddChoice("Shadow")
                effectBox:AddChoice("Outline")

                ---------------------------------------------------------
                -- OUTLINE SIZE (ONLY IF OUTLINE)
                ---------------------------------------------------------
                local outline = vgui.Create("DNumSlider", frame)
                outline:SetPos(300, 165)
                outline:SetSize(260, 30)
                outline:SetMin(1)
                outline:SetMax(10)
                outline:SetDecimals(0)
                outline:SetText("Outline Thickness")
                outline:SetValue(g.graffiti.outlineSize or 1)

                ---------------------------------------------------------
                -- SHADOW OFFSET SLIDER (ONLY IF SHADOW)
                ---------------------------------------------------------
                local shadow = vgui.Create("DNumSlider", frame)
                shadow:SetPos(300, 195)
                shadow:SetSize(260, 30)
                shadow:SetMin(1)
                shadow:SetMax(10)
                shadow:SetDecimals(0)
                shadow:SetText("Shadow Offset")
                shadow:SetValue(g.graffiti.shadowOffset or 2)

                ---------------------------------------------------------
                -- SHOW/HIDE SLIDERS BASED ON EFFECT
                ---------------------------------------------------------
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

                outline.OnValueChanged = function(_, val)
                    g.graffiti.outlineSize = val
                    preview:InvalidateLayout(true)
                end

                shadow.OnValueChanged = function(_, val)
                    g.graffiti.shadowOffset = val
                    preview:InvalidateLayout(true)
                end

                RefreshEffectVisibility()

                ---------------------------------------------------------
                -- SAVE BUTTON
                ---------------------------------------------------------
                local bgBox = vgui.Create("DComboBox", frame)
                bgBox:SetPos(300, 225)
                bgBox:SetSize(260, 24)
                bgBox:SetValue(g.graffiti.bgMat or "brick/brick_model")

                local bgChoices = {
                    "brick/brick_model",
                    "models/debug/debugwhite",
                    "models/props_c17/fisheyelens",
                    "models/props/cs_assault/moneywrap03",
                    "models/props_combine/stasisshield_sheet"
                }
                for _, choice in ipairs(bgChoices) do
                    bgBox:AddChoice(choice)
                end

                bgBox.OnSelect = function(_, _, val)
                    g.graffiti.bgMat = val
                    bgMatName = val
                    preview:InvalidateLayout(true)
                end

                ---------------------------------------------------------
                -- COLOR MIXER
                ---------------------------------------------------------
                local colMixer = vgui.Create("DColorMixer", frame)
                colMixer:SetPos(300, 255)
                colMixer:SetSize(260, 100)
                colMixer:SetPalette(true)
                colMixer:SetAlphaBar(false)
                colMixer:SetWangs(true)
                colMixer:SetColor(Color(g.graffiti.color.r or 255, g.graffiti.color.g or 255, g.graffiti.color.b or 255))
                colMixer.ValueChanged = function(_, col)
                    g.graffiti.color = { r = col.r, g = col.g, b = col.b }
                    preview:InvalidateLayout(true)
                end

                ---------------------------------------------------------
                -- SAVE BUTTON
                ---------------------------------------------------------
                local saveBtn = vgui.Create("DButton", frame)
                saveBtn:SetPos(20, 365)
                saveBtn:SetSize(540, 30)
                saveBtn:SetText("")
                saveBtn.Paint = function(_,w,h)
                    draw.RoundedBox(6, 0, 0, w, h, accent)
                    draw.SimpleText(
                        "Save Graffiti",
                        "DubzHUD_Small",
                        w / 2, h / 2,
                        Color(255,255,255),
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                    )
                end
                saveBtn.DoClick = function()
                    net.Start("Dubz_Gang_Action")
                    net.WriteTable({
                        cmd          = "setgraffiti",
                        text         = g.graffiti.text or "",
                        font         = g.graffiti.font or "Trebuchet24",
                        scale        = g.graffiti.scale or 1,
                        effect       = g.graffiti.effect or "Clean",
                        outlineSize  = g.graffiti.outlineSize,
                        shadowOffset = g.graffiti.shadowOffset,
                        bgMat        = g.graffiti.bgMat or "brick/brick_model",
                        color        = g.graffiti.color or g.color or { r = 255, g = 255, b = 255 }
                    })
                    net.SendToServer()
                    frame:Close()
                end
            end

            pnl._graffitiEdit = b
            if pnl.RegisterGangElem then pnl:RegisterGangElem(b) end
        end

        pnl._graffitiEdit:SetPos(300, y + 60)
    end

    return y + bh + 12
end

--------------------------------------------------------
-- GANG OVERVIEW + COLOR PICKER + PREVIEW + SAVE BUTTON
--------------------------------------------------------
local function DrawGangOverview(pnl, w, y, accent, g)
    local bh = 110
    Bubble(12, y, w - 24, bh)

    -- Gang name
    draw.SimpleText(g.name or "Gang", "DubzHUD_Header", 24, y + 10, accent)

    --------------------------------------------------------
    -- WAR READY INDICATOR
    --------------------------------------------------------
    local warReadyText  = ""
    local warReadyColor = Color(255, 80, 80)

    if g.allowWars == false then
        warReadyText  = "– NOT READY"
        warReadyColor = Color(180,180,180)
    else
        warReadyText  = "– WAR READY"
        warReadyColor = Color(255, 60, 60)
    end

    surface.SetFont("DubzHUD_Header")
    local nameW = surface.GetTextSize(g.name or "Gang")

    draw.SimpleText(
        warReadyText,
        "DubzHUD_Header",
        24 + nameW + 12,
        y + 10,
        warReadyColor
    )

    --------------------------------------------------------
    -- COLOR SQUARE
    --------------------------------------------------------
    local gc = g.color or { r = accent.r, g = accent.g, b = accent.b }

    draw.RoundedBox(
        6,
        24,
        y + 44,
        14, 14,
        Color(gc.r, gc.g, gc.b)
    )

    --------------------------------------------------------
    -- LEADER / MEMBERS / BANK / DESC
    --------------------------------------------------------
    draw.SimpleText(
        "Leader: " .. (g.members[g.leaderSid64] and g.members[g.leaderSid64].name or "Unknown"),
        "DubzHUD_Small",
        48, y + 42,
        Color(220,220,220)
    )

    local count = table.Count(g.members or {})

    draw.SimpleText(
        "Members: " .. count .. "/" .. (Dubz.Config.Gangs.MaxMembers or 12),
        "DubzHUD_Small",
        24, y + 66,
        Color(220,220,220)
    )

    draw.SimpleText(
        "Bank: $" .. tostring(g.bank or 0),
        "DubzHUD_Small",
        220, y + 66,
        Color(220,220,220)
    )

    draw.SimpleText(
        "Desc: " .. (g.desc or ""),
        "DubzHUD_Small",
        24, y + 86,
        Color(200,200,200)
    )

    --------------------------------------------------------
    -- COLOR PICKER (leader only)
    --------------------------------------------------------
    if IsLeaderC() then
        local bubbleRight  = w - 24      -- right side padding
        local pickerWidth  = 180
        local pickerHeight = 90
        local previewSize  = 36
        local rightX       = bubbleRight - pickerWidth

        -- PREVIEW BOX
        if not pnl._colorPrev then
            local box = vgui.Create("DPanel", pnl)
            box:SetSize(previewSize, previewSize)
            function box:Paint(w,h)
                local gang = GetMyGang()
                if not gang then return end
                local c = gang.color or { r = 255, g = 255, b = 255 }
                draw.RoundedBox(6, 0, 0, w, h, Color(c.r, c.g, c.b))
            end
            pnl._colorPrev = box
            if pnl.RegisterGangElem then pnl:RegisterGangElem(box) end
        end

        pnl._colorPrev:SetPos(rightX - previewSize - 12, y + 10)

        -- COLOR MIXER
        if not pnl._colorMixer then
            local cm = vgui.Create("DColorMixer", pnl)
            cm:SetSize(pickerWidth, pickerHeight)
            cm:SetPalette(false)
            cm:SetAlphaBar(false)
            cm:SetWangs(true)
            pnl._colorMixer = cm
            if pnl.RegisterGangElem then pnl:RegisterGangElem(cm) end
        end

        pnl._colorMixer:SetSize(pickerWidth, pickerHeight)
        pnl._colorMixer:SetPos(rightX, y + 10)

        -- APPLY BUTTON
        if not pnl._applyColor then
            local b = vgui.Create("DButton", pnl)
            b:SetText("")
            b:SetSize(90, 22)
            function b:Paint(w,h)
                draw.RoundedBox(6, 0, 0, w, h, accent)
                draw.SimpleText(
                    "Set Color",
                    "DubzHUD_Small",
                    w / 2, h / 2,
                    Color(255,255,255),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            end
            function b:DoClick()
                local col = pnl._colorMixer:GetColor()
                net.Start("Dubz_Gang_Action")
                net.WriteTable({
                    cmd   = "setcolor",
                    color = { r = col.r, g = col.g, b = col.b }
                })
                net.SendToServer()
            end
            pnl._applyColor = b
            if pnl.RegisterGangElem then pnl:RegisterGangElem(b) end
        end

        pnl._applyColor:SetPos(
            rightX - previewSize - 66,
            y + 10 + previewSize + 6
        )
    end

    return y + bh + 12
end

--------------------------------------------------------
-- RANKS
--------------------------------------------------------
local function DrawRanks(pnl, w, y, accent, g)
    local bh = 110
    Bubble(12, y, w - 24, bh)
    draw.SimpleText("Ranks", "DubzHUD_Header", 24, y + 10, accent)

    local rt = g.rankTitles or Dubz.DefaultRankTitles
    local x  = 24

    for r = 3, 1, -1 do
        draw.SimpleText(
            string.format("%s (%d)", rt[r] or Dubz.DefaultRankTitles[r], r),
            "DubzHUD_Body",
            x, y + 48,
            Color(230,230,230)
        )

        if IsLeaderC() then
            local key = "_rank_"..r
            if not pnl[key] then
                local te = vgui.Create("DTextEntry", pnl)
                if Dubz.HookTextEntry then Dubz.HookTextEntry(te) end
                te:SetSize(160, 22)
                te:SetPos(x, y + 70)
                te:SetText(rt[r] or "")
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
            else
                if IsValid(pnl[key]) then pnl[key]:SetPos(x, y + 70) end
            end
        end

        x = x + 200
    end

    return y + bh + 12
end

--------------------------------------------------------
-- MEMBERS
--------------------------------------------------------
local function DrawMembers(pnl, w, y, accent, g)
    local rowH = 34
    local count = 0
    for _ in pairs(g.members or {}) do count = count + 1 end
    local bh = 56 + rowH * math.max(1, count)

    Bubble(12, y, w - 24, bh)
    draw.SimpleText("Members", "DubzHUD_Header", 24, y + 10, accent)

    local listY = y + 40
    local sx    = 24

    for sid, m in pairs(g.members or {}) do
        draw.SimpleText(m.name or sid, "DubzHUD_Body", sx, listY, Color(230,230,230))
        draw.SimpleText(
            Dubz.GangGetTitle(g, m.rank or 1),
            "DubzHUD_Small",
            sx + 260, listY + 2,
            Color(180,180,255)
        )

        if IsLeaderC() and sid ~= g.leaderSid64 then
            -- Promote
            local pk = "_pro_"..sid
            if not pnl[pk] then
                local b = vgui.Create("DButton", pnl)
                b:SetText("")
                b:SetSize(70, 22)
                function b:Paint(w,h)
                    draw.RoundedBox(6, 0, 0, w, h, accent)
                    draw.SimpleText("Promote","DubzHUD_Small",w / 2,h / 2,Color(255,255,255),1,1)
                end
                function b:DoClick()
                    SendAction({ cmd = "promote", target = sid })
                end
                pnl[pk] = b
                if pnl.RegisterGangElem then pnl:RegisterGangElem(b) end
            end
            if IsValid(pnl[pk]) then pnl[pk]:SetPos(sx + 380, listY - 4) end

            -- Demote
            local dk = "_dem_"..sid
            if not pnl[dk] then
                local b = vgui.Create("DButton", pnl)
                b:SetText("")
                b:SetSize(70, 22)
                function b:Paint(w,h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(120,120,120))
                    draw.SimpleText("Demote","DubzHUD_Small",w / 2,h / 2,Color(255,255,255),1,1)
                end
                function b:DoClick()
                    SendAction({ cmd = "demote", target = sid })
                end
                pnl[dk] = b
                if pnl.RegisterGangElem then pnl:RegisterGangElem(b) end
            end
            if IsValid(pnl[dk]) then pnl[dk]:SetPos(sx + 456, listY - 4) end

            -- Kick
            local kk = "_kick_"..sid
            if not pnl[kk] then
                local b = vgui.Create("DButton", pnl)
                b:SetText("")
                b:SetSize(70, 22)
                function b:Paint(w,h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(190,80,80))
                    draw.SimpleText("Kick","DubzHUD_Small",w / 2,h / 2,Color(255,255,255),1,1)
                end
                function b:DoClick()
                    SendAction({ cmd = "kick", target = sid })
                end
                pnl[kk] = b
                if pnl.RegisterGangElem then pnl:RegisterGangElem(b) end
            end
            if IsValid(pnl[kk]) then pnl[kk]:SetPos(sx + 532, listY - 4) end
        end

        listY = listY + rowH
    end

    -- Invite controls (leader only)
    if IsLeaderC() then
        -- combo = list of online players not already in gang
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
            bt:SetSize(90, 22)
            function bt:Paint(w,h)
                draw.RoundedBox(6, 0, 0, w, h, accent)
                draw.SimpleText("Invite","DubzHUD_Small",w / 2,h / 2,Color(255,255,255),1,1)
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

        -- position
        if IsValid(pnl._inviteCombo) then
            pnl._inviteCombo:SetPos(24, y + bh - 30)
        end
        if IsValid(pnl._inviteBtn) then
            pnl._inviteBtn:SetPos(250, y + bh - 30)
        end

        -- Only repopulate when online player count or member count changes
        if IsValid(pnl._inviteCombo) then
            local combo       = pnl._inviteCombo
            local onlineCount = #player.GetAll()
            local memberCount = table.Count(g.members or {})

            if combo._lastOnlineCount ~= onlineCount
            or combo._lastMemberCount ~= memberCount then

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

                combo._lastOnlineCount = onlineCount
                combo._lastMemberCount = memberCount
            end
        end
    end

    return y + bh + 12
end

--------------------------------------------------------
-- BANK
--------------------------------------------------------
local function DrawMoney(pnl, w, y, accent, g)
    local bh = 80
    Bubble(12, y, w - 24, bh)

    draw.SimpleText("Gang Bank", "DubzHUD_Header", 24, y + 10, accent)
    draw.SimpleText(
        "Balance: $" .. tostring(g.bank or 0),
        "DubzHUD_Body",
        24, y + 42,
        Color(230,230,230)
    )

    -- Deposit
    if not pnl._dep then
        local d = vgui.Create("DTextEntry", pnl)
        if Dubz.HookTextEntry then Dubz.HookTextEntry(d) end
        d:SetNumeric(true)
        d:SetSize(120, 22)

        local db = vgui.Create("DButton", pnl)
        db:SetText("")
        db:SetSize(90, 22)
        function db:Paint(w,h)
            draw.RoundedBox(6, 0, 0, w, h, accent)
            draw.SimpleText("Deposit","DubzHUD_Small",w / 2,h / 2,Color(255,255,255),1,1)
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

    if IsValid(pnl._dep)    then pnl._dep:SetPos(220, y + 42) end
    if IsValid(pnl._depBtn) then pnl._depBtn:SetPos(346, y + 42) end

    -- Withdraw (leader only)
    if IsLeaderC() then
        if not pnl._wd then
            local d = vgui.Create("DTextEntry", pnl)
            if Dubz.HookTextEntry then Dubz.HookTextEntry(d) end
            d:SetNumeric(true)
            d:SetSize(120, 22)

            local db = vgui.Create("DButton", pnl)
            db:SetText("")
            db:SetSize(90, 22)
            function db:Paint(w,h)
                draw.RoundedBox(6, 0, 0, w, h, Color(160,160,160))
                draw.SimpleText("Withdraw","DubzHUD_Small",w / 2,h / 2,Color(255,255,255),1,1)
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

        if IsValid(pnl._wd)    then pnl._wd:SetPos(450, y + 42) end
        if IsValid(pnl._wdBtn) then pnl._wdBtn:SetPos(576, y + 42) end
    end

    return y + bh + 12
end

--------------------------------------------------------
-- WARS
--------------------------------------------------------
local function DrawWars(pnl, w, y, accent, g)
    local bh = 160
    Bubble(12, y, w - 24, bh)

    draw.SimpleText("Wars", "DubzHUD_Header", 24, y + 10, accent)

    --------------------------------------------------------
    -- WAR STATUS
    --------------------------------------------------------
    local status = "Not at war"
    if g.wars and g.wars.active then
        local rem       = math.max(0, math.floor((g.wars.ends or CurTime()) - CurTime()))
        local enemyName = g.wars.enemy

        if Dubz.Gangs[enemyName] then
            enemyName = Dubz.Gangs[enemyName].name or enemyName
        end

        status = ("At war with: %s (%ds left)"):format(enemyName, rem)
    end

    draw.SimpleText(status, "DubzHUD_Body", 24, y + 42, Color(230,230,230))

    --------------------------------------------------------
    -- WAR OPT-IN TOGGLE
    --------------------------------------------------------
    if IsLeaderC() then
        if not pnl._warToggle then
            local cb = vgui.Create("DCheckBoxLabel", pnl)
            cb:SetText(" Allow other gangs to declare war on us")
            cb:SetTextColor(Color(200,200,200))
            cb:SetFont("DubzHUD_Body")
            function cb:OnChange(b)
                SendAction({
                    cmd     = "set_war_toggle",
                    enabled = b and true or false
                })
            end
            pnl._warToggle = cb
            if pnl.RegisterGangElem then pnl:RegisterGangElem(cb) end
        end

        pnl._warToggle:SetPos(24, y + 66)
        pnl._warToggle:SetChecked(g.allowWars ~= false)
    end

    --------------------------------------------------------
    -- DECLARE / FORFEIT WAR UI
    --------------------------------------------------------
    if IsLeaderC() then
        -- CREATE ELEMENTS
        if not pnl._target then
            pnl._target = vgui.Create("DComboBox", pnl)
            pnl._target:SetSize(240, 22)
            if pnl.RegisterGangElem then pnl:RegisterGangElem(pnl._target) end
        end

        if not pnl._warBtn then
            local btn = vgui.Create("DButton", pnl)
            btn:SetText("")
            btn:SetSize(120, 22)
            function btn:Paint(w,h)
                local gang = GetMyGang() or g
                local col  = (gang.wars and gang.wars.active) and Color(190,80,80) or accent
                draw.RoundedBox(6, 0, 0, w, h, col)
                draw.SimpleText(
                    (gang.wars and gang.wars.active) and "Forfeit" or "Declare",
                    "DubzHUD_Small",
                    w / 2, h / 2,
                    Color(255,255,255),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            end
            function btn:DoClick()
                local gang = GetMyGang() or g

                -- Already at war → forfeit
                if gang.wars and gang.wars.active then
                    SendAction({ cmd = "forfeit_war" })
                    return
                end

                -- Declare war
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

        -- POPULATE DROPDOWN SAFELY
        local needsRefresh = false
        local hash         = 0

        for gid, gg in pairs(Dubz.Gangs or {}) do
            hash = hash + (gg.allowWars == false and 1 or 2)
        end

        if hash ~= (pnl._target._lastHash or -1) then
            needsRefresh = true
        end

        if needsRefresh then
            pnl._target:Clear()

            for gid, gg in pairs(Dubz.Gangs or {}) do
                if gid ~= g.id and (gg.allowWars ~= false) and (g.allowWars ~= false) then
                    pnl._target:AddChoice(gg.name, gid)
                end
            end

            pnl._target._lastHash = hash
        end

        pnl._target:SetPos(24,  y + 96)
        pnl._warBtn:SetPos(274, y + 96)
    end

    return y + bh + 12
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

    -- Single canvas panel inside the scroll
    local pnl = vgui.Create("DPanel", scroll)
    pnl:SetWide(scroll:GetWide())
    pnl:Dock(TOP)
    pnl:SetTall(2000) -- big; shrinks dynamically in Paint
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

    -- MAIN PAINT LAYOUT
    function pnl:Paint(w, h)
        local g = GetMyGang()
        local y = 12

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
                    function b:Paint(w,h)
                        draw.RoundedBox(6, 0, 0, w, h, Color(180,60,60))
                        draw.SimpleText("Disband","DubzHUD_Small",w / 2,h / 2,Color(255,255,255),1,1)
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
                    function b:Paint(w,h)
                        draw.RoundedBox(6, 0, 0, w, h, Color(120,120,120))
                        draw.SimpleText("Leave","DubzHUD_Small",w / 2,h / 2,Color(255,255,255),1,1)
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

        -- Make panel just big enough for content instead of fixed 2000
        self:SetTall(math.max(y + 32, parent:GetTall() + 32))
    end

    if not Dubz._GangTabSynced then
        net.Start("Dubz_Gang_RequestSync")
        net.SendToServer()
        Dubz._GangTabSynced = true
    end
end)
