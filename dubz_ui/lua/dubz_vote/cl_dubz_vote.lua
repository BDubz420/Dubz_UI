if not Dubz then return end

Dubz.Vote = Dubz.Vote or {}
Dubz.Vote.Client = Dubz.Vote.Client or {}

local VotePanels = {}  -- [id] = panel

local function LayoutContainer(panel)
    panel:SetSize(400, ScrH())
    panel:SetPos(ScrW() - 420, 0)
end

local function EnsureVoteContainer()
    if IsValid(DubzVotingContainer) then
        return DubzVotingContainer
    end

    if not (vgui and vgui.Create) then return end

    local cont = vgui.Create("DPanel")
    if not IsValid(cont) then
        if not Dubz.Vote._containerRetry then
            Dubz.Vote._containerRetry = true
            timer.Simple(0, function()
                Dubz.Vote._containerRetry = nil
                EnsureVoteContainer()
            end)
        end
        return
    end

    LayoutContainer(cont)
    cont:SetMouseInputEnabled(true)
    cont:SetKeyboardInputEnabled(false)
    cont:SetZPos(32767)

    function cont:Paint(w, h)
        draw.SimpleText("Press F3 to use cursor", "DubzHUD_Small", w / 2, 16,
            Color(220, 220, 220, 220), TEXT_ALIGN_CENTER)
    end

    hook.Add("OnScreenSizeChanged", "DubzVoteContainerLayout", function()
        if IsValid(DubzVotingContainer) then
            LayoutContainer(DubzVotingContainer)
        end
    end)

    DubzVotingContainer = cont
    return cont
end

hook.Add("InitPostEntity", "DubzVoteEnsureContainer", EnsureVoteContainer)

local function DrawBubble(x, y, w, h, col)
    if Dubz.DrawBubble then
        Dubz.DrawBubble(x, y, w, h, col)
    else
        draw.RoundedBox(12, x, y, w, h, col)
    end
end

-- Open a vote panel
function Dubz.Vote.OpenPanel(id, question, options, duration)
    local container = EnsureVoteContainer()
    if not IsValid(container) then
        timer.Simple(0, function()
            if VotePanels[id] then return end
            Dubz.Vote.OpenPanel(id, question, options, duration)
        end)
        return
    end

    local accent = Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(40,140,200)

    if IsValid(VotePanels[id]) then VotePanels[id]:Remove() end

    local p = vgui.Create("DPanel", container)
    p:SetSize(360, 190)
    p:SetAlpha(0)
    p.Duration = math.max(duration or 15, 1)
    p.EndTime = CurTime() + p.Duration
    p.Closing = false
    p.Id = id

    local parentW = container:GetWide()
    local offsetY = 50 + (#container:GetChildren() - 1) * 12

    p:SetPos(parentW, offsetY)
    p:MoveTo(parentW - 360 - 20, offsetY, 0.25, 0, 0.2)
    p:AlphaTo(255, 0.2)

    function p:SlideOut()
        if self.Closing then return end
        self.Closing = true
        local x, y = self:GetPos()
        self:MoveTo(parentW, y, 0.25, 0, 0.2)
        self:AlphaTo(0, 0.2, 0, function()
            if IsValid(self) then self:Remove() end
        end)
    end

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    function p:Paint(w, h)
        DrawBubble(0, 0, w, h, Color(25,25,25,240))

        local frac = math.Clamp((self.EndTime - CurTime()) / self.Duration, 0, 1)
        surface.SetDrawColor(accent)
        surface.DrawRect(0, 0, w * frac, 5)

        draw.SimpleText(question, "DubzHUD_Header", w/2, 60, Color(255,255,255), TEXT_ALIGN_CENTER)
    end

    local btnPanel = vgui.Create("DPanel", p)
    btnPanel:Dock(BOTTOM)
    btnPanel:SetTall(44)
    btnPanel:DockMargin(0, 6, 0, 8)
    btnPanel.Paint = nil

    local function MakeButton(text, index)
        local b = vgui.Create("DButton", btnPanel)
        b:SetSize(150, 32)
        b:SetText("")
        b.ChoiceIndex = index

        function b:Paint(w, h)
            local col = self:IsHovered()
                and Color(accent.r+15, accent.g+15, accent.b+15)
                or  accent
            draw.RoundedBox(8,0,0,w,h,col)
            draw.SimpleText(text, "DubzHUD_Small", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        function b:OnCursorEntered()
            surface.PlaySound("buttons/lightswitch2.wav")
        end

        function b:DoClick()
            surface.PlaySound("buttons/button15.wav")
            Dubz.Vote.Cast(id, self.ChoiceIndex)
            p:SlideOut()
        end

        return b
    end

    if #options == 2 and
       string.find(string.lower(options[1] or ""), "yes", 1, true) and
       string.find(string.lower(options[2] or ""), "no", 1, true) then

        local yes = MakeButton("YES", 1)
        yes:SetPos(20, 6)

        local no = MakeButton("NO", 2)
        no:SetPos(360 - 20 - 150, 6)
    else
        local spacing = 10
        local btnWidth = math.max(90, math.min(150,
            (p:GetWide() - 40 - spacing * (#options - 1)) / #options
        ))

        local totalW = btnWidth * #options + spacing * (#options - 1)
        local startX = (p:GetWide() - totalW) / 2
        local x = startX

        for i, opt in ipairs(options) do
            local b = MakeButton(opt or "Option", i)
            b:SetSize(btnWidth, 32)
            b:SetPos(x, 6)
            x = x + btnWidth + spacing
        end
    end

    function p:Think()
        if not self.Closing and CurTime() >= self.EndTime then
            self:SlideOut()
        end
    end

    VotePanels[id] = p
end

-- Send vote choice
function Dubz.Vote.Cast(id, choice)
    net.Start("Dubz_Vote_Cast")
        net.WriteString(id)
        net.WriteUInt(choice, 8)
    net.SendToServer()
end

-- Receive start from server
net.Receive("Dubz_Vote_Start", function()
    local id = net.ReadString()
    local question = net.ReadString()
    local count = net.ReadUInt(8)

    local options = {}
    for i = 1, count do
        options[i] = net.ReadString()
    end

    local duration = net.ReadUInt(8)

    Dubz.Vote.OpenPanel(id, question, options, duration)
end)

-- Receive end from server
net.Receive("Dubz_Vote_End", function()
    local id = net.ReadString()
    local count = net.ReadUInt(8)
    local results = {}
    for i = 1, count do
        results[i] = net.ReadUInt(12)
    end
    local winner = net.ReadUInt(8)
    local cancelled = net.ReadBool()

    local pnl = VotePanels[id]
    if IsValid(pnl) then
        pnl:SlideOut()
    end

    -- Optional: show result as notification
    if notification and notification.AddLegacy then
        local txt
        if cancelled then
            txt = string.format("Vote '%s' was cancelled.", id)
        elseif winner > 0 then
            txt = string.format("Vote '%s' finished. Option #%d won with %d votes.",
                id, winner, results[winner] or 0)
        else
            txt = string.format("Vote '%s' ended with no winner.", id)
        end

        if txt then
            notification.AddLegacy(txt, cancelled and 1 or 0, 5)
        end
    end
end)