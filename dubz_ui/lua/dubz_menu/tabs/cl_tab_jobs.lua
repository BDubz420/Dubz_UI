local function getJobCategories()
    if not DarkRP or not DarkRP.getCategories then return {} end
    local cats = DarkRP.getCategories()
    return cats.jobs or {}
end

Dubz.RegisterTab("jobs", "Jobs", "jobs", function(parent)
    local pnl = vgui.Create("DScrollPanel", parent)
    pnl:Dock(FILL)
    pnl:DockMargin(12, 12, 12, 12)

    --------------------------------------------------------------------------
    -- 🧹 Cleanup: close hover previews safely
    --------------------------------------------------------------------------
    local OPEN_JOB_HOVERS = {}
    local function CloseAllJobHovers()
        for p, _ in pairs(OPEN_JOB_HOVERS) do
            if IsValid(p) then p:Remove() end
        end
        table.Empty(OPEN_JOB_HOVERS)
    end

    function pnl:OnRemove()
        CloseAllJobHovers()
    end

    hook.Add("VGUIMousePressed", "Dubz_JobsHoverClickAway", function()
        if not IsValid(pnl) then
            hook.Remove("VGUIMousePressed", "Dubz_JobsHoverClickAway")
            return
        end
        CloseAllJobHovers()
    end)

    --------------------------------------------------------------------------
    -- 🎨 Scrollbar Styling
    --------------------------------------------------------------------------
    local sbar = pnl:GetVBar()
    function sbar:Paint(w, h)
        surface.SetDrawColor(Color(10, 10, 10, 150))
        surface.DrawRect(0, 0, w, h)
    end
    function sbar.btnGrip:Paint(w, h)
        local acc = Dubz.GetAccentColor()
        local col = self:IsHovered() and Color(acc.r + 25, acc.g + 25, acc.b + 25, 230) or Color(acc.r, acc.g, acc.b, 200)
        draw.RoundedBox(6, 2, 0, w - 4, h, col)
    end
    function sbar.btnUp:Paint() end
    function sbar.btnDown:Paint() end

    --------------------------------------------------------------------------
    -- 🧱 Build Job Categories
    --------------------------------------------------------------------------
    for _, cat in ipairs(getJobCategories()) do
        if #cat.members == 0 then continue end

        local header = vgui.Create("DPanel", pnl)
        header:Dock(TOP)
        header:SetTall(36)
        header:DockMargin(0, 0, 0, 6)
        local catColor = (cat.color and Color(cat.color.r, cat.color.g, cat.color.b, 220)) or Dubz.GetAccentColor()
        function header:Paint(w, h)
            Dubz.DrawBubble(0, 0, w, h, Color(24, 24, 24, 220))
            surface.SetDrawColor(catColor)
            surface.DrawRect(0, 0, 4, h)
            draw.SimpleText(cat.name or "Category", "DubzHUD_Body", 12, h / 2, catColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local grid = vgui.Create("DIconLayout", pnl)
        grid:Dock(TOP)
        grid:SetTall(1)
        grid:DockMargin(0, 0, 0, 10)
        grid:SetSpaceY(8)
        grid:SetSpaceX(8)
        function grid:PerformLayoutInternal()
            self:SetTall(math.ceil(#cat.members / 3) * 110 + 10)
        end

        ----------------------------------------------------------------------
        -- 🎫 Job Cards
        ----------------------------------------------------------------------
        for _, job in ipairs(cat.members or {}) do

            ------------------------------------------------------------------
            -- ✅ Respect DarkRP customCheck (hide job if not permitted)
            ------------------------------------------------------------------
            if job.customCheck and not job.customCheck(LocalPlayer()) then
                -- job is hidden from F4 for this player, so skip it
                continue
            end

            ------------------------------------------------------------------
            -- ✅ Respect admin jobs (admin=1=admin only, admin=2=superadmin only)
            ------------------------------------------------------------------
            if job.admin == 1 and not LocalPlayer():IsAdmin() then continue end
            if job.admin == 2 and not LocalPlayer():IsSuperAdmin() then continue end

            local jobColor = job.color or catColor
            local card = grid:Add("DPanel")
            card:SetSize(300, 100)

            function card:Paint(w, h)
                Dubz.DrawBubble(0, 0, w, h, Color(22, 22, 22, 220))
                draw.SimpleText(job.name or "Job", "DubzHUD_Body", 100, 10, Color(230, 230, 230))
                local salary = job.salary or 0
                local stxt = (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(math.floor(tonumber(salary) or 0))) or ("$" .. tostring(math.floor(tonumber(salary) or 0)))
                draw.SimpleText(stxt, "DubzHUD_Small", 100, 36, Color(60, 255, 90))
            end

            ------------------------------------------------------------------
            -- 👕 Model Carousel (closer, face-centered camera)
            ------------------------------------------------------------------
            local modelList = istable(job.model) and job.model or { job.model }
            local curModel = 1
            local mdl = vgui.Create("DModelPanel", card)
            mdl:SetSize(80, 80)
            mdl:SetPos(10, 10)
            mdl:SetFOV(32) -- zoomed in for detail
            mdl:SetModel(modelList[curModel] or "models/player/kleiner.mdl")

            function mdl:SetupCam()
                if not IsValid(self.Entity) then return end
                local mn, mx = self.Entity:GetRenderBounds()
                local size = math.max(math.abs(mn.x) + math.abs(mx.x), math.abs(mn.y) + math.abs(mx.y), math.abs(mn.z) + math.abs(mx.z))
                local headHeight = size * 0.75 -- lifted focus toward face
                self:SetCamPos(Vector(size * 0.55, size * 0.55, headHeight))
                self:SetLookAt(Vector(0, 0, headHeight))
            end
            mdl:SetupCam()

            function mdl:LayoutEntity(ent)
                ent:SetAngles(Angle(0, CurTime() * 25 % 360, 0))
            end

            function mdl:PreDrawModel(ent)
                render.SuppressEngineLighting(true)
                local lightCol = Vector(0.85, 0.85, 0.9)
                local acc = Dubz.GetAccentColor()
                local rimLight = Vector(acc.r / 255 * 0.4, acc.g / 255 * 0.4, acc.b / 255 * 0.4)
                render.SetModelLighting(BOX_TOP, lightCol.x, lightCol.y, lightCol.z)
                render.SetModelLighting(BOX_FRONT, 0.2, 0.2, 0.25)
                render.SetModelLighting(BOX_LEFT, rimLight.x, rimLight.y, rimLight.z)
            end
            function mdl:PostDrawModel() render.SuppressEngineLighting(false) end

            -- 🔹 Arrow Buttons (moved down)
            if #modelList > 1 then
                local left = vgui.Create("DButton", mdl)
                left:SetText("<")
                left:SetFont("DubzHUD_Small")
                left:SetSize(16, 16)
                left:SetPos(0, 64) -- moved down
                function left:Paint(w, h)
                    local col = self:IsHovered() and Color(255, 255, 255, 255) or Color(200, 200, 200, 160)
                    draw.SimpleText("<", "DubzHUD_Small", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                function left:DoClick()
                    curModel = curModel - 1
                    if curModel < 1 then curModel = #modelList end
                    mdl:SetModel(modelList[curModel])
                    mdl:SetupCam()
                end

                local right = vgui.Create("DButton", mdl)
                right:SetText(">")
                right:SetFont("DubzHUD_Small")
                right:SetSize(16, 16)
                right:SetPos(64, 64) -- moved down
                function right:Paint(w, h)
                    local col = self:IsHovered() and Color(255, 255, 255, 255) or Color(200, 200, 200, 160)
                    draw.SimpleText(">", "DubzHUD_Small", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                function right:DoClick()
                    curModel = curModel + 1
                    if curModel > #modelList then curModel = 1 end
                    mdl:SetModel(modelList[curModel])
                    mdl:SetupCam()
                end
            end

            ------------------------------------------------------------------
            -- 🟢 Become Button
            ------------------------------------------------------------------
            local btn = vgui.Create("DButton", card)
            btn:SetText("")
            btn:SetSize(90, 26)
            btn:SetPos(300 - 100, 100 - 36)
            function btn:Paint(w, h)
                local bg = jobColor
                if self:IsHovered() then bg = Color(bg.r, bg.g, bg.b, 255) end
                draw.RoundedBox(8, 0, 0, w, h, bg)
                draw.SimpleText("Become", "DubzHUD_Small", w / 2, h / 2, Color(255, 255, 255), 1, 1)
            end
            function btn:DoClick()
                if not job.command then return end

                -- If the job requires a vote, use the vote command
                if job.vote == true then
                    RunConsoleCommand("darkrp", "vote" .. job.command)
                else
                    -- Otherwise, become the job instantly
                    RunConsoleCommand("darkrp", job.command)
                end
            end

            ------------------------------------------------------------------
            -- 💬 Hover Info (Description + Weapons, with newline support)
            ------------------------------------------------------------------
            local hoverPanel
            function btn:OnCursorEntered()
                if IsValid(hoverPanel) then hoverPanel:Remove() end

                local mx, my = gui.MousePos()
                local desc = job.description or "No description provided."

                -- Split into paragraphs by \n or newlines
                local rawLines = string.Explode("\n", desc)
                local wrappedLines = {}
                surface.SetFont("DubzHUD_Small")
                local maxWidth = 300

                for _, raw in ipairs(rawLines) do
                    local words = string.Explode(" ", raw)
                    local line = ""
                    for _, word in ipairs(words) do
                        local test = line == "" and word or (line .. " " .. word)
                        local tw = surface.GetTextSize(test)
                        if tw > maxWidth then
                            table.insert(wrappedLines, line)
                            line = word
                        else
                            line = test
                        end
                    end
                    table.insert(wrappedLines, line)
                end

                -- Compute height dynamically from wrapped line count
                local descHeight = #wrappedLines * 16
                local totalH = 120 + descHeight + 50 -- base + text + weapons section

                hoverPanel = vgui.Create("DPanel")
                hoverPanel:SetSize(320, totalH)
                hoverPanel:SetPos(mx + 16, my - 10)
                hoverPanel:SetAlpha(0)
                hoverPanel:MakePopup()
                hoverPanel:SetMouseInputEnabled(true)
                hoverPanel:SetKeyboardInputEnabled(false)

                OPEN_JOB_HOVERS[hoverPanel] = true
                function hoverPanel:OnRemove() OPEN_JOB_HOVERS[self] = nil end

                hoverPanel:AlphaTo(255, 0.25, 0)

                function hoverPanel:Paint(w, h)
                    Dubz.DrawBubble(0, 0, w, h, Color(30, 30, 30, 240))
                    draw.SimpleText(job.name or "", "DubzHUD_Body", 12, 8, jobColor)
                    draw.SimpleText("Description:", "DubzHUD_Small", 12, 36, Color(180, 180, 180))

                    local y = 52
                    for _, ln in ipairs(wrappedLines) do
                        draw.SimpleText(ln, "DubzHUD_Small", 12, y, Color(230, 230, 230), TEXT_ALIGN_LEFT)
                        y = y + 16
                    end

                    draw.SimpleText("Weapons:", "DubzHUD_Small", 12, y + 10, Color(180, 180, 180))
                    local weps = istable(job.weapons) and table.concat(job.weapons, ", ") or (job.weapons or "")
                    draw.DrawText(weps ~= "" and weps or "None", "DubzHUD_Small", 12, y + 26, Color(220, 220, 220), TEXT_ALIGN_LEFT)
                end
            end

            function btn:OnCursorExited()
                if IsValid(hoverPanel) then
                    hoverPanel:AlphaTo(0, 0.2, 0, function()
                        if IsValid(hoverPanel) then hoverPanel:Remove() end
                    end)
                end
            end
        end
    end
end)
