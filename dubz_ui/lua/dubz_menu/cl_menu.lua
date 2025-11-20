Dubz = Dubz or {}; Dubz.MenuTabs = Dubz.MenuTabs or {}

Dubz.MenuLocked = false

function Dubz.RegisterTab(id, label, icon, buildFunc)
    Dubz.MenuTabs[id] = { label = label, icon = icon, build = buildFunc }
end

local frame, overlay, isOpen, switchTo, content = nil, nil, false, nil, nil
local openedByF4 = false
local refreshQueued = false

local function ensureOverlay()
    if IsValid(overlay) then return overlay end
    overlay = vgui.Create("DPanel")
    overlay:SetSize(ScrW(), ScrH()); overlay:SetPos(0,0); overlay:SetZPos(0); overlay:SetVisible(false)
    function overlay:Paint(w,h) draw.RoundedBox(0,0,0,w,h, Color(0,0,0,180)) end
    return overlay
end

local function openMenu(defaultTab, byF4)
    if IsValid(frame) then
        if defaultTab and switchTo then switchTo(defaultTab, true) end
        return
    end
    openedByF4 = byF4 or false
    local cfg = Dubz.Config.Menu
    if cfg.DimBackground then ensureOverlay():SetVisible(true) end

    frame = vgui.Create("DFrame")
    local fw, fh = ScrW()*0.82, ScrH()*0.78
    frame:SetSize(fw, fh)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    gui.EnableScreenClicker(true)
    isOpen = true

    function frame:Paint(w,h)
        draw.RoundedBox(cfg.CornerRadius or 12,0,0,w,h, cfg.Background or Color(0,0,0,160))
        draw.SimpleText("Dubz UI "..(Dubz.Config.Version or ""),"DubzHUD_Small", 12, h-20, Dubz.GetAccentColor())
    end

    -- Close button (visible when opened by F4)
    if openedByF4 then
        local close = vgui.Create("DButton", frame)
        close:SetSize(28,28); close:SetPos(fw-36, 8); close:SetText("")
        function close:Paint(w,h)
            local bg = Color(20,20,20,220)
            if self:IsHovered() then bg = Color(40,40,40,220) end
            draw.RoundedBox(6,0,0,w,h,bg)
            draw.SimpleText("X","DubzHUD_Small", w/2,h/2, Color(240,240,240),1,1)
        end
        function close:DoClick()
            if IsValid(frame) then
                gui.EnableScreenClicker(false)
                frame:Close()
            end
            Dubz.MenuLocked = false
            isOpen = false
            if IsValid(overlay) then overlay:SetVisible(false) end
        end
    end

    local side = vgui.Create("DPanel", frame)
    side:Dock(LEFT); side:SetWide(cfg.SidebarWidth or 280)
    function side:Paint(w,h)
        draw.RoundedBoxEx(12,0,0,w,h, Color(12,12,12,220), true,false,true,false)
        surface.SetDrawColor(Dubz.GetAccentColor()); surface.DrawRect(0,0,4,h)
    end

    local header = vgui.Create("DPanel", side)
    header:Dock(TOP); header:SetTall(92); header:DockMargin(8,8,8,8)
    function header:Paint(w,h)
        Dubz.DrawBubble(0,0,w,h, Color(20,20,20,220))
        local lp = LocalPlayer()
        if IsValid(lp) then
            local gang = Dubz.GetGangName and Dubz.GetGangName(lp) or nil
            local gtxt = gang and ("["..gang.."] ") or ""
            local gcol = gang and (Dubz.GetGangColor and Dubz.GetGangColor(lp) or Color(180,90,255))
            draw.SimpleText(gtxt, "DubzHUD_Small", 84, 10, gcol or Color(180,90,255))
            surface.SetFont("DubzHUD_Small")
            local gw,_ = surface.GetTextSize(gtxt)
            draw.SimpleText(lp:Nick() or "Player","DubzHUD_Header", 84+gw, 8, Color(240,240,240))
            local job = (lp.getDarkRPVar and lp:getDarkRPVar("job")) or "Citizen"
            draw.SimpleText(job,"DubzHUD_Body", 84, 36, team.GetColor(lp:Team()))
            local money = (lp.getDarkRPVar and lp:getDarkRPVar("money")) or 0
            local mtxt = (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(math.floor(tonumber(money) or 0))) or ("$"..tostring(math.floor(tonumber(money) or 0)))
            draw.SimpleText(mtxt,"DubzHUD_Money", 84, 58, Color(60,255,90))
        end
    end
    local av = vgui.Create("AvatarImage", header); av:SetSize(64,64); av:SetPos(10,14); av:SetPlayer(LocalPlayer(), 64)

    local sideTabs = vgui.Create("DScrollPanel", side)
    sideTabs:Dock(FILL); sideTabs:DockMargin(8,0,8,52)

    local sideBtns = vgui.Create("DPanel", side)
    sideBtns:Dock(BOTTOM); sideBtns:SetTall(96); sideBtns:DockMargin(8,8,8,8)
    function sideBtns:Paint(w,h) end

    local function stackBtn(parent, label, onclick)
        local b = vgui.Create("DButton", parent)
        b:Dock(TOP); b:SetTall(44); b:DockMargin(0,0,0,8); b:SetText("")
        function b:Paint(w,h)
            local bg = Color(22,22,22,220); if self:IsHovered() then bg = Color(32,32,32,220) end
            Dubz.DrawBubble(0,0,w,h, bg)
            draw.SimpleText(label,"DubzHUD_Body", 44, h/2, Color(240,240,240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        function b:DoClick() if onclick then onclick() end end
        return b
    end

    local allowedAdmin = LocalPlayer():IsAdmin() or LocalPlayer():IsSuperAdmin()
    stackBtn(sideBtns, "Discord", function() gui.OpenURL(Dubz.Config.DiscordInvite or "https://discord.gg/wMNqh7RBAd") end)
    if allowedAdmin then stackBtn(sideBtns, "Admin", function() if Dubz.OpenAdminWindow then Dubz.OpenAdminWindow() end end) end

    content = vgui.Create("DPanel", frame)
    content:Dock(FILL); content:DockMargin(12,12,12,12)
    function content:Paint(w,h) Dubz.DrawBubble(0,0,w,h, Color(24,24,24,220)) end

    local active = nil
    function switchTo(id, preload)
        content:Clear(); active = id
        Dubz.MenuActiveTab = id
        local t = Dubz.MenuTabs[id]; if t and t.build then t.build(content, preload) end
    end

    Dubz.MenuActiveTab = ""

    for _, t in ipairs(Dubz.Config.Menu.Tabs or {}) do
        local btn = sideTabs:Add("DButton")
        btn:Dock(TOP); btn:SetTall(44); btn:DockMargin(0,0,0,8); btn:SetText("")
        function btn:Paint(w,h)
            local bg = Color(22,22,22,220); if self:IsHovered() or active == t.id then bg = Color(32,32,32,220) end
            Dubz.DrawBubble(0,0,w,h, bg)
            draw.SimpleText(t.label or t.id, "DubzHUD_Body", 44, h/2, Color(240,240,240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if active == t.id then surface.SetDrawColor(Dubz.GetAccentColor()); surface.DrawRect(0,0,4,h) end
        end
        function btn:DoClick() switchTo(t.id, true) end
    end

    switchTo("dashboard", true)
end

local function closeMenu()
    if IsValid(frame) then frame:Close() end
    if IsValid(overlay) then overlay:SetVisible(false) end
    gui.EnableScreenClicker(false)
    isOpen = false
    Dubz.MenuLocked = false
    stickyInputLock = false
end

function Dubz.RequestMenuRefresh(tabId)
    if not isOpen then return end
    if tabId and Dubz.MenuActiveTab ~= tabId then return end
    if refreshQueued then return end
    refreshQueued = true
    timer.Simple(0, function()
        refreshQueued = false
        if not isOpen or not switchTo then return end
        if tabId and Dubz.MenuActiveTab ~= tabId then return end
        if not Dubz.MenuActiveTab then return end
        switchTo(Dubz.MenuActiveTab, true)
    end)
end

function Dubz.RequestMenuRefresh(tabId)
    if not isOpen then return end
    if tabId and Dubz.MenuActiveTab ~= tabId then return end
    if refreshQueued then return end
    refreshQueued = true
    timer.Simple(0, function()
        refreshQueued = false
        if not isOpen or not switchTo then return end
        if tabId and Dubz.MenuActiveTab ~= tabId then return end
        if not Dubz.MenuActiveTab then return end
        switchTo(Dubz.MenuActiveTab, true)
    end)
end

Dubz.RefreshActiveTab = Dubz.RequestMenuRefresh
Dubz.OpenMenuPanel = openMenu
Dubz.CloseMenuPanel = closeMenu
Dubz.IsMenuOpen = function() return isOpen end

-- Input: TAB (hold-to-open) & F4 (toggle open to Market with close button)
do
    local wasDown = false
hook.Add("Think","Dubz_MenuHoldTab", function()
        if not Dubz or not Dubz.Config or not Dubz.Config.Menu or not Dubz.Config.Menu.Enabled then return end
        local key = Dubz.Config.Keys and Dubz.Config.Keys.OpenMenu or KEY_TAB
        local down = input.IsKeyDown(key)

        if down and not wasDown then
            -- TAB pressed
            if not isOpen then
                openMenu("dashboard", false)
            else
                if Dubz.MenuLocked then
                    Dubz.MenuLocked = false
                    closeMenu()
                end
            end
        elseif (not down) and wasDown then
            -- TAB released
            if not Dubz.MenuLocked then
                closeMenu()
            end
        end

        wasDown = down
    end)

    local wasF4 = false
    hook.Add("Think","Dubz_MenuF4Market", function()
        local down = input.IsKeyDown(KEY_F4)
        if down and not wasF4 then
            if IsValid(frame) then
                closeMenu()
            else
                openMenu("market", true) -- show close button
            end
        end
        wasF4 = down
end)

do
    local hadFocus = false
    hook.Add("Think","Dubz_MenuFocusTextLock", function()
        if not isOpen then
            if hadFocus then
                Dubz.MenuLocked = false
                hadFocus = false
            end
            return
        end

        local focus = vgui.GetKeyboardFocus()
        local needsKeyboard = IsValid(focus) and (focus:GetClassName() == "DTextEntry" or focus:GetClassName() == "DMultiChoice" or focus:GetClassName() == "DBinder")

        if needsKeyboard and not hadFocus then
            Dubz.MenuLocked = true
            hadFocus = true
        elseif not needsKeyboard and hadFocus then
            Dubz.MenuLocked = false
            hadFocus = false
        end
    end)
end
end
