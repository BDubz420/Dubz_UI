--------------------------------------------------------
-- Dubz UI Player Tab – Fixed Dropdown Behavior
--------------------------------------------------------

-- Optional backfill if you joined late and missed NW2 set
net.Receive("Dubz_Playtime_Backfill", function()
    local ent = net.ReadEntity()
    local base = net.ReadFloat()
    local join = net.ReadFloat()
    if IsValid(ent) then
        ent:SetNW2Float("Dubz_TotalBase", base)
        ent:SetNW2Float("Dubz_JoinTime", join)
    end
end)

-- Format HH:MM:SS
local function FormatHMS(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function pingColorAndBars(ping)
    if ping <= 50 then return Color(60,200,120), 3
    elseif ping <= 100 then return Color(255,190,60), 2
    else return Color(220,60,60), 1 end
end

local function drawPingBars(x,y,baseW,baseH,ping)
    local col, bars = pingColorAndBars(ping or 0)
    local w, h, gap = baseW or 18, baseH or 16, 3
    for i=1,3 do
        local bw = math.floor(w/3)
        local bh = math.floor(h * (i/3))
        local by = y + (h - bh)
        local bx = x + (i-1) * (bw + gap)
        surface.SetDrawColor(0,0,0,120); surface.DrawRect(bx, by, bw, bh)
        if i <= bars then surface.SetDrawColor(col); surface.DrawRect(bx, by, bw, bh) end
    end
end

local function PanelBG(w, h)
    if Dubz and Dubz.DrawBubble then
        Dubz.DrawBubble(0,0,w,h, Color(24,24,24,220))
    end
end

local function AccentLine(y, w)
    local c = (Dubz and Dubz.GetAccentColor and Dubz.GetAccentColor()) or Color(120,170,255)
    surface.SetDrawColor(c)
    surface.DrawRect(0, y, w, 4)
end

Dubz.RegisterTab("players","Players","players", function(parent)
    local root = vgui.Create("DPanel", parent)
    root:Dock(FILL)
    root:DockMargin(12,12,12,12)
    function root:Paint(w,h) end

    ------------------ Header ------------------
    local header = vgui.Create("DPanel", root)
    header:Dock(TOP)
    header:SetTall(36)
    --header:DockMargin(0,0,08,0)
    function header:Paint(w,h)
        PanelBG(w,h)
        local cols = {
            {name="Player", offset=0.11},
            {name="Job",    offset=0.30},
            {name="Money",  offset=0.42},
            {name="Kills",  offset=0.54},
            {name="Deaths", offset=0.64},
            {name="Session",offset=0.78},
            {name="Total",  offset=0.88},
            {name="Ping",   offset=0.96},
        }
        for _,c in ipairs(cols) do
            draw.SimpleText(c.name, "DubzHUD_Small", w*c.offset, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        AccentLine(h-4, w)
    end

    ------------------ Scroll + ListLayout ------------------
    local scroll = vgui.Create("DScrollPanel", root)
    scroll:Dock(FILL)
    --scroll:DockMargin(8,6,8,8)
    --function scroll:Paint(w,h) PanelBG(w,h) end

    local layout = vgui.Create("DListLayout", scroll)
    layout:Dock(TOP) -- allow it to grow dynamically
    layout:SetTall(0)

    local canvas = scroll:GetCanvas()
    canvas:SetZPos(1)

    scroll._openRow = nil

    --------------------------------------------------------------
    -- 🎯 Sliding Dropdown + Canvas Auto-Resize + Accordion Behavior
    --------------------------------------------------------------
    local function CollapseRow(row)
        if not IsValid(row) or not row._expanded then return end
        row._expanded = false

        local drop = row._dropdown
        if not IsValid(drop) then return end

        -- Slide dropdown up
        drop:SizeTo(drop:GetWide(), 0, 0.25, 0, -1, function()
            if not IsValid(row) then return end
            row:SizeTo(row:GetWide(), row._baseTall, 0.25, 0, -1, function()
                if IsValid(layout) then
                    layout:InvalidateLayout(true)
                    layout:SetTall(math.max(layout:GetTall() - row._dropTall, 0))
                end
                if IsValid(canvas) then
                    canvas:InvalidateLayout(true)
                end
            end)
        end)
    end

    local function ExpandRow(row)
        -- Accordion: close previous open row
        if scroll._openRow and IsValid(scroll._openRow) and scroll._openRow ~= row then
            CollapseRow(scroll._openRow)
            scroll._openRow = nil
        end

        row._expanded = true
        scroll._openRow = row
        local drop = row._dropdown
        if not IsValid(drop) then return end

        drop:Dock(BOTTOM)

        -- Expand row and dropdown together
        row:SizeTo(row:GetWide(), row._baseTall + row._dropTall, 0.25, 0, -1, function()
            if not IsValid(drop) then return end
            drop:SizeTo(drop:GetWide(), row._dropTall, 0.25, 0, -1, function()
                if IsValid(layout) then
                    layout:InvalidateLayout(true)
                    layout:SetTall(layout:GetTall() + row._dropTall)
                end
                if IsValid(canvas) then
                    canvas:InvalidateLayout(true)
                end
            end)
        end)

        -- Scroll to keep expanded dropdown visible
        timer.Simple(0.3, function()
            if not IsValid(scroll) or not IsValid(row) then return end
            local bar = scroll:GetVBar()
            if not IsValid(bar) then return end

            local _, ry = row:GetPos()
            local rowBottom = ry + row._baseTall + row._dropTall + 20
            local viewBottom = bar:GetScroll() + scroll:GetTall()

            if rowBottom > viewBottom then
                local diff = rowBottom - viewBottom
                bar:AnimateTo(bar:GetScroll() + diff, 0.3, 0, 0.3)
            end
        end)
    end

    local function ToggleRow(row)
        if row._expanded then
            CollapseRow(row)
            if scroll._openRow == row then scroll._openRow = nil end
        else
            ExpandRow(row)
        end
    end

    ------------------ Add Row ------------------
    local function AddRow(ply)
        local row = vgui.Create("DPanel", layout)
        row:Dock(TOP)
        row:DockMargin(0,3,0,3)
        row._baseTall = 44
        row._dropTall = 58
        row._expanded = false
        row:SetTall(row._baseTall)

        function row:Paint(w,h)
            PanelBG(w,h)
            if not IsValid(ply) then return end

            local join   = ply:GetNW2Float("Dubz_JoinTime", CurTime())
            local base   = ply:GetNW2Float("Dubz_TotalBase", 0)
            local session = CurTime() - join
            local total   = base + session

            local job   = (ply.getDarkRPVar and ply:getDarkRPVar("job")) or "Citizen"
            local money = (ply.getDarkRPVar and ply:getDarkRPVar("money")) or 0
            local moneyText = (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(math.floor(tonumber(money) or 0)))
                or ("$"..tostring(math.floor(tonumber(money) or 0)))

            draw.SimpleText(ply:Nick(), "DubzHUD_Body", w * 0.13 + 22, 22, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(job, "DubzHUD_Small", w * 0.30, 22, team.GetColor(ply:Team()), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(moneyText, "DubzHUD_Small", w * 0.42, 22, Color(60,255,90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(ply:Frags(), "DubzHUD_Small", w * 0.54, 22, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(ply:Deaths(), "DubzHUD_Small", w * 0.64, 22, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(FormatHMS(session), "DubzHUD_Small", w * 0.78, 22, Color(200,200,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(FormatHMS(total),   "DubzHUD_Small", w * 0.88, 22, Color(180,255,180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            drawPingBars(w * 0.96 - 9, 14, 18, 16, ply:Ping())
        end

        local av = vgui.Create("AvatarImage", row)
        av:SetSize(36,36)
        av:SetPlayer(ply,36)
        function row:PerformLayout(w,h)
            av:SetPos(w * 0.13 - 50, 4)
        end

        ------------------------------------------------------------------
        -- 🧩 Dubz UI Style – Minimal Flat Dropdown (No Background)
        ------------------------------------------------------------------
        row._dropdown = vgui.Create("DPanel", row)
        row._dropdown:Dock(BOTTOM)
        row._dropdown:SetTall(0)
        row._dropdown:DockMargin(40, 2, 40, 2)
        row._dropdown:SetPaintBackground(false) -- no background, fully transparent

        -- Compact button container
        local btnWrap = vgui.Create("DPanel", row._dropdown)
        btnWrap:Dock(FILL)
        btnWrap:DockMargin(65, 2, 4, 2)
        btnWrap:SetPaintBackground(false)

        local function AddBtn(label, baseColor, func)
            local accent = Dubz and Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(37,150,190)
            local c = baseColor or accent

            local b = vgui.Create("DButton", btnWrap)
            b:SetText("")
            b:SetWide(80)      -- smaller, cleaner
            b:SetTall(20)
            b:Dock(LEFT)
            b:DockMargin(3, 6, 3, 0)

            b.Paint = function(s, w, h)
                local bg = Color(c.r, c.g, c.b, 180)
                if s:IsHovered() then
                    bg = Color(math.min(c.r+25,255), math.min(c.g+25,255), math.min(c.b+25,255), 220)
                end
                draw.RoundedBox(6, 0, 0, w, h, bg)
                draw.SimpleText(label, "DubzHUD_Small", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            b.DoClick = function()
                surface.PlaySound("buttons/button15.wav")
                if func then func() end
            end
        end

        -- 🧩 Buttons
        AddBtn("Copy ID", Color(70,70,70), function()
            if IsValid(ply) and ply.SteamID then SetClipboardText(ply:SteamID()) end
        end)

        AddBtn("Profile", Color(70,70,70), function()
            if IsValid(ply) and ply.SteamID64 then gui.OpenURL("https://steamcommunity.com/profiles/"..ply:SteamID64()) end
        end)

        if LocalPlayer():IsAdmin() then
            AddBtn("Goto",      Color(90,120,220),  function() RunConsoleCommand("ulx","goto",     ply:Nick()) end)
            AddBtn("Bring",     Color(120,180,240), function() RunConsoleCommand("ulx","bring",    ply:Nick()) end)
            AddBtn("Kick",      Color(180,60,60),   function() RunConsoleCommand("ulx","kick",     ply:Nick()) end)
            AddBtn("Freeze",    Color(200,130,60),  function() RunConsoleCommand("ulx","freeze",   ply:Nick()) end)
            AddBtn("Unfreeze",  Color(80,160,100),  function() RunConsoleCommand("ulx","unfreeze", ply:Nick()) end)
        end

        local click = vgui.Create("DButton", row)
        click:SetText("")
        click:Dock(FILL)
        click:SetAlpha(0)
        function click:DoClick()
            ToggleRow(row)
        end

        layout:Add(row)
    end

    ------------------ Populate Rows ------------------
    local players = player.GetAll()
    table.sort(players, function(a,b) return string.lower(a:Nick() or "") < string.lower(b:Nick() or "") end)
    for _, ply in ipairs(players) do
        if IsValid(ply) then AddRow(ply) end
    end
end)
