local function getAllMarketCategories()
    if not DarkRP or not DarkRP.getCategories then return {} end

    local cats = DarkRP.getCategories()

    -- These are REAL category sets inside DarkRP
    return {
        { type = "Entities",  list = cats.entities   or {} },
        { type = "Ammo",      list = cats.ammo       or {} },
        { type = "Weapons",   list = cats.weapons    or {} },
        { type = "Shipments", list = cats.shipments  or {} },
    }
end

Dubz.RegisterTab("market", "Market", "market", function(parent)

    local pnl = vgui.Create("DScrollPanel", parent)
    pnl:Dock(FILL)
    pnl:DockMargin(12,12,12,12)

    ---------------------------------------
    -- Scrollbar Styling
    ---------------------------------------
    local sbar = pnl:GetVBar()

    function sbar:Paint(w,h)
        local bg = Dubz.Colors.Background or Color(0,0,0,150)
        surface.SetDrawColor(bg)
        surface.DrawRect(0,0,w,h)
    end
    function sbar.btnGrip:Paint(w,h)
        local acc = Dubz.Colors.Accent or Color(37,150,190)
        local col = self:IsHovered()
            and Color(acc.r+25, acc.g+25, acc.b+25, 230)
            or  Color(acc.r,   acc.g,   acc.b,   200)
        draw.RoundedBox(6, 2, 0, w-4, h, col)
    end
    function sbar.btnUp:Paint() end
    function sbar.btnDown:Paint() end


    -------------------------------------------------------
    -- BUILD TABS
    -------------------------------------------------------
    for _, group in ipairs(getAllMarketCategories()) do
        if #group.list == 0 then continue end

        for _, cat in ipairs(group.list) do

            -----------------------------------------
            -- APPLY CATEGORY ALLOWED JOBS TO ITEMS
            -----------------------------------------
            if cat.allowed and istable(cat.allowed) then
                for _, item in ipairs(cat.members or {}) do

                    -- Shipments
                    if (item.entity or item.shipmentClass) and not item.allowed then
                        item.allowed = table.Copy(cat.allowed)
                    end

                    -- Weapons
                    if item.weapon and not item.allowed then
                        item.allowed = table.Copy(cat.allowed)
                    end
                end
            end

            -----------------------------------------
            -- FILTER ITEMS VISIBLE TO LOCAL PLAYER
            -----------------------------------------
            local validItems = {}

            for _, item in ipairs(cat.members or {}) do
                local canSee = true

                -- allowed jobs
                if item.allowed and istable(item.allowed) then
                    canSee = false
                    for _, t in ipairs(item.allowed) do
                        if LocalPlayer():Team() == t then
                            canSee = true
                            break
                        end
                    end
                end

                -- customCheck
                if canSee and item.customCheck then
                    local ok, result = pcall(item.customCheck, LocalPlayer())
                    if not ok or not result then
                        canSee = false
                    end
                end

                if canSee then table.insert(validItems, item) end
            end

            if #validItems == 0 then continue end

            -----------------------------------------
            -- CATEGORY HEADER
            -----------------------------------------
            local header = vgui.Create("DPanel", pnl)
            header:Dock(TOP)
            header:SetTall(36)
            header:DockMargin(0,0,0,6)

            local catColor = (cat.color and Color(cat.color.r, cat.color.g, cat.color.b, 220))
                         or Dubz.GetAccentColor()

            function header:Paint(w,h)
                Dubz.DrawBubble(0,0,w,h, Color(24,24,24,220))
                surface.SetDrawColor(catColor)
                surface.DrawRect(0,0,4,h)
                draw.SimpleText(cat.name or group.type, "DubzHUD_Body", 12, h/2, catColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end


            -----------------------------------------
            -- ITEM GRID
            -----------------------------------------
            local grid = vgui.Create("DIconLayout", pnl)
            grid:Dock(TOP)
            grid:SetTall(1)
            grid:DockMargin(0,0,0,10)
            grid:SetSpaceY(6)
            grid:SetSpaceX(6)

            function grid:PerformLayoutInternal()
                local scrollBarWidth = pnl:GetVBar():IsVisible() and 20 or 0
                local available = pnl:GetWide() - scrollBarWidth
                local cardWidth = 300 + 8
                local perRow = math.Clamp(math.floor(available / cardWidth), 1, 4)
                local rowHeight = 110
                self:SetTall(math.ceil(#validItems / perRow) * rowHeight + 10)
            end


            -----------------------------------------
            -- BUILD ITEM CARDS
            -----------------------------------------
            for _, item in ipairs(validItems) do

                local card = grid:Add("DPanel")
                card:SetSize(300, 100)

                function card:Paint(w,h)
                    Dubz.DrawBubble(0,0,w,h, Color(22,22,22,220))
                    draw.SimpleText(item.name or "Item", "DubzHUD_Body", 100, 10, Color(230,230,230))

                    local cost = item.price or (item.getPrice and item:getPrice(LocalPlayer())) or 0
                    if group.type == "Weapons" and item.pricesep then
                        cost = item.pricesep
                    end
                    local ctext = DarkRP.formatMoney and DarkRP.formatMoney(cost)
                               or ("$"..math.floor(cost))
                    draw.SimpleText(ctext, "DubzHUD_Small", 100, 36, Color(60,255,90))

                    --------------------------
                    -- AMOUNT / OWNED TEXT
                    --------------------------
                    if group.type == "Entities" then
                        local owned, maxv = 0, (item.max or 0)
                        for _, ent in ipairs(ents.FindByClass(item.ent or "")) do
                            local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
                                or ent.Getowning_ent and ent:Getowning_ent()
                            if IsValid(owner) and owner == LocalPlayer() then
                                owned = owned + 1
                            end
                        end
                        local color = owned >= maxv and Color(255,80,80) or Color(180,255,180)
                        draw.SimpleText("Owned: "..owned.." / "..(maxv > 0 and maxv or "∞"),
                            "DubzHUD_Small", 100, 54, color)

                    elseif group.type == "Ammo" then
                        draw.SimpleText("Qty: "..(item.amountGiven or 0),
                            "DubzHUD_Small", 100, 54, Color(200,200,255))

                    elseif group.type == "Weapons" then
                        draw.SimpleText("Qty: 1",
                            "DubzHUD_Small", 100, 54, Color(200,200,255))

                        if item.separate or item.shipmentClass or item.category then
                            draw.SimpleText("Shipment: "..(item.category or "Shipment"),
                                "DubzHUD_Small", 100, 72, Color(190,190,215))
                        end

                    elseif group.type == "Shipments" then
                        local qty = item.amount or (item.getAmount and item:getAmount()) or 10
                        draw.SimpleText("Qty: "..qty,
                            "DubzHUD_Small", 100, 54, Color(200,200,255))
                    end
                end


                -----------------------------------------
                -- MODEL PREVIEW
                -----------------------------------------
                local mdl = vgui.Create("DModelPanel", card)
                mdl:SetSize(80, 80)
                mdl:SetPos(10, 10)
                mdl:SetModel(item.model or "models/props_c17/oildrum001.mdl")

                if group.type == "Entities" then
                    mdl:SetFOV(25)  mdl:SetCamPos(Vector(50,50,50))   mdl:SetLookAt(Vector(0,0,0))
                elseif group.type == "Ammo" then
                    mdl:SetFOV(40)  mdl:SetCamPos(Vector(18,18,10))   mdl:SetLookAt(Vector(0,0,4))
                elseif group.type == "Weapons" then
                    mdl:SetFOV(30)  mdl:SetCamPos(Vector(22,22,10))   mdl:SetLookAt(Vector(0,0,3))
                elseif group.type == "Shipments" then
                    mdl:SetFOV(15)  mdl:SetCamPos(Vector(45,45,35))   mdl:SetLookAt(Vector(0,0,10))
                end

                function mdl:LayoutEntity(ent)
                    ent:SetAngles(Angle(0, CurTime() * 20 % 360, 0))
                end


                -----------------------------------------
                -- BUY BUTTON (FULLY FIXED)
                -----------------------------------------
                local btn = vgui.Create("DButton", card)
                btn:SetText("")
                btn:SetSize(90,26)
                btn:SetPos(300-100,100-36)

                function btn:Paint(w,h)
                    local bg = catColor
                    if self:IsHovered() then bg = Color(bg.r, bg.g, bg.b, 255) end
                    draw.RoundedBox(8,0,0,w,h,bg)
                    draw.SimpleText("Buy","DubzHUD_Small",w/2,h/2,Color(255,255,255),1,1)
                end

                -------------------------------------------------------
                -- BUY LOGIC (COMPLETE AND 100% FIXED)
                -------------------------------------------------------
                function btn:DoClick()
                    if not item then return end

                    ----------------------------------------------------
                    -- ENTITY BUY
                    ----------------------------------------------------
                    if group.type == "Entities" and item.cmd then
                        RunConsoleCommand("darkrp", item.cmd)
                        return
                    end

                    ----------------------------------------------------
                    -- AMMO BUY
                    ----------------------------------------------------
                    if group.type == "Ammo" and item.ammoType then
                        RunConsoleCommand("darkrp", "buyammo", item.ammoType)
                        return
                    end

                    ----------------------------------------------------
                    -- WEAPON BUY (single weapon from shipment)
                    ----------------------------------------------------
                    if group.type == "Weapons" then
                        if item.separate then
                            RunConsoleCommand("darkrp", "buy", item.name)
                        else
                            RunConsoleCommand("darkrp", "buyshipment", item.name)
                        end
                        return
                    end

                    ----------------------------------------------------
                    -- SHIPMENT BUY (must use exact shipment name)
                    ----------------------------------------------------
                    if group.type == "Shipments" then
                        RunConsoleCommand("darkrp", "buyshipment", item.name)
                        return
                    end
                end
            end
        end
    end
end)