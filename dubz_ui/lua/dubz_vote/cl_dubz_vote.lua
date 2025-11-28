if not Dubz then return end

Dubz.Vote = Dubz.Vote or {}
Dubz.Vote.Client = Dubz.Vote.Client or {}

local VotePanels = {}  -- [id] = panel

local PendingVotes = {}
local FlushPendingVotes

local function LayoutContainer(panel)
    panel:SetSize(400, ScrH())
    panel:SetPos(ScrW() - 420, 0)
end

local function CanBuildContainer()
    if not (vgui and vgui.Create and vgui.GetWorldPanel) then return false end
    if not vgui.GetControlTable("DPanel") then return false end
    local wp = vgui.GetWorldPanel and vgui.GetWorldPanel()
    if not IsValid(wp) then return false end
    return true
end

local function EnsureVoteContainer()
    if IsValid(DubzVotingContainer) then
        return DubzVotingContainer
    end

    if not CanBuildContainer() or not IsValid(LocalPlayer()) then
        if not Dubz.Vote._containerRetry then
            Dubz.Vote._containerRetry = true
            timer.Simple(0.25, function()
                Dubz.Vote._containerRetry = nil
                EnsureVoteContainer()
            end)
        end
        return
    end

    local root = vgui.GetWorldPanel and vgui.GetWorldPanel()
    if not IsValid(root) then
        timer.Simple(0.25, EnsureVoteContainer)
        return
    end

    local ok, cont = pcall(vgui.Create, "DPanel", root)
    if not ok or not IsValid(cont) then
        timer.Simple(0.25, EnsureVoteContainer)
        return
    end

    LayoutContainer(cont)
    cont:SetMouseInputEnabled(true)
    cont:SetKeyboardInputEnabled(false)
    cont:SetZPos(32767)

    function cont:Paint(w, h)
        if next(VotePanels) then
            draw.SimpleText("Press F3 to use cursor", "DubzHUD_Small", w / 2, 16,
                Color(220, 220, 220, 220), TEXT_ALIGN_CENTER)
        end
    end

    hook.Add("OnScreenSizeChanged", "DubzVoteContainerLayout", function()
        if IsValid(DubzVotingContainer) then
            LayoutContainer(DubzVotingContainer)
        end
    end)

    DubzVotingContainer = cont
    if FlushPendingVotes then
        FlushPendingVotes()
    end
    return cont
end

hook.Add("InitPostEntity", "DubzVoteEnsureContainer", EnsureVoteContainer)

local function FlushPendingVotes()
    if not next(PendingVotes) then return end
    local cont = EnsureVoteContainer()
    if not IsValid(cont) then return end

    for id, data in pairs(PendingVotes) do
        PendingVotes[id] = nil
        Dubz.Vote.OpenPanel(data.id, data.question, data.options, data.duration, true)
    end
end

local function EnsureVoteContainer()
    if IsValid(DubzVotingContainer) then
        return DubzVotingContainer
    end

    if not CanBuildContainer() or not IsValid(LocalPlayer()) then
        if not Dubz.Vote._containerRetry then
            Dubz.Vote._containerRetry = true
            timer.Simple(0.25, function()
                Dubz.Vote._containerRetry = nil
                EnsureVoteContainer()
            end)
        end
        return
    end

    local root = vgui.GetWorldPanel and vgui.GetWorldPanel()
    if not IsValid(root) then
        timer.Simple(0.25, EnsureVoteContainer)
        return
    end

    local ok, cont = pcall(vgui.Create, "DPanel", root)
    if not ok or not IsValid(cont) then
        timer.Simple(0.25, EnsureVoteContainer)
        return
    end

    LayoutContainer(cont)
    cont:SetMouseInputEnabled(true)
    cont:SetKeyboardInputEnabled(false)
    cont:SetZPos(32767)

    function cont:Paint(w, h)
        if next(VotePanels) then
            draw.SimpleText("Press F3 to use cursor", "DubzHUD_Small", w / 2, 16,
                Color(220, 220, 220, 220), TEXT_ALIGN_CENTER)
        end
    end

    hook.Add("OnScreenSizeChanged", "DubzVoteContainerLayout", function()
        if IsValid(DubzVotingContainer) then
            LayoutContainer(DubzVotingContainer)
        end
    end)

    DubzVotingContainer = cont
    if FlushPendingVotes then
        FlushPendingVotes()
    end
    return cont
end

hook.Add("InitPostEntity", "DubzVoteEnsureContainer", EnsureVoteContainer)

local function FlushPendingVotes()
    if not next(PendingVotes) then return end
    local cont = EnsureVoteContainer()
    if not IsValid(cont) then return end

    for id, data in pairs(PendingVotes) do
        PendingVotes[id] = nil
        Dubz.Vote.OpenPanel(data.id, data.question, data.options, data.duration, true)
    end
end

--------------------------------------------------------
-- Helper: DrawBubble fallback
--------------------------------------------------------
local function DrawBubble(x,y,w,h,col)
    if Dubz.DrawBubble then
        Dubz.DrawBubble(x,y,w,h,col)
    else
        draw.RoundedBox(12,x,y,w,h,col)
    end
end

-- Open a vote panel
function Dubz.Vote.OpenPanel(id, question, options, duration, suppressQueue)
    local container = EnsureVoteContainer()
    if not IsValid(container) then
        if suppressQueue then return end
        PendingVotes[id] = {
            id       = id,
            question = question,
            options  = (istable(options) and table.Copy(options)) or {},
            duration = duration
        }

        if not timer.Exists("Dubz_Vote_PendingRetry") then
            timer.Create("Dubz_Vote_PendingRetry", 0.5, 0, function()
                if not next(PendingVotes) then
                    timer.Remove("Dubz_Vote_PendingRetry")
                    return
                end
                FlushPendingVotes()
            end)
        end
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

    for w in string.gmatch(base or "", "%S+") do
        table.insert(segments, { text = w, col = baseCol })
    end

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

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    function p:OnRemove()
        if VotePanels[self.Id] == self then
            VotePanels[self.Id] = nil
        end
    end

    if #segments == 0 and question ~= "" then
        table.insert(segments, { text = question, col = baseCol })
    end

    return segments
end

local function MeasureQuestionHeight(question, font, maxWidth)
    local segments = BuildQuestionSegments(question)
    if #segments == 0 then return 0 end

    surface.SetFont(font)
    local _, lineH = surface.GetTextSize("Ay")
    local spaceW   = surface.GetTextSize(" ")
    local lineWidth = 0
    local lineCount = 1

    for _, seg in ipairs(segments) do
        local w = surface.GetTextSize(seg.text)
        local add = (lineWidth > 0 and spaceW or 0) + w

        if lineWidth > 0 and (lineWidth + add) > maxWidth then
            lineCount = lineCount + 1
            lineWidth = w
        else
            lineWidth = lineWidth + add
        end
    end

    return lineCount * lineH
end

local function DrawWrappedQuestion(question, font, x, startY, maxWidth)
    local segments = BuildQuestionSegments(question)
    if #segments == 0 then return startY end

    surface.SetFont(font)
    local _, lineH = surface.GetTextSize("Ay")
    local spaceW   = surface.GetTextSize(" ")

    local cursorX, cursorY = x, startY
    local lineWidth = 0

    for _, seg in ipairs(segments) do
        local wordW = surface.GetTextSize(seg.text)
        local add   = (lineWidth > 0 and spaceW or 0) + wordW

        if lineWidth > 0 and (lineWidth + add) > maxWidth then
            lineWidth = 0
            cursorX   = x
            cursorY   = cursorY + lineH
        end

        if lineWidth > 0 then
            cursorX = cursorX + spaceW
        end

        draw.SimpleText(seg.text, font, cursorX, cursorY, seg.col)
        cursorX   = cursorX + wordW
        lineWidth = lineWidth + add
    end

    return cursorY + lineH
end

--------------------------------------------------------
-- Reposition vote panels (oldest → newest)
--------------------------------------------------------
local function Dubz_RepositionVotes()
    local sorted = {}

    for _, pnl in pairs(VotePanels) do
        if IsValid(pnl) then table.insert(sorted, pnl) end
    end

    table.sort(sorted, function(a,b)
        return (a.SortIndex or 0) < (b.SortIndex or 0)
    end)

    local y = 60
    for _, pnl in ipairs(sorted) do
        if IsValid(pnl) then
            pnl:SetPos(ScrW() - pnl:GetWide() - 20, y)
            y = y + pnl:GetTall() + 8
        end
    end

    if Dubz_UpdateLawsPanelPosition then
        Dubz_UpdateLawsPanelPosition()
    end
end

--------------------------------------------------------
-- Laws panel offset (uses global lawPanel from HUD)
--------------------------------------------------------
function Dubz_UpdateLawsPanelPosition()
    if not IsValid(lawPanel) then return end

    local count = 0
    for _, pnl in pairs(VotePanels) do
        if IsValid(pnl) then count = count + 1 end
    end

    lawPanel:SetPos(
        ScrW() - lawPanel:GetWide() - 20,
        120 + (count * 110)
    )
end

--------------------------------------------------------
-- Show F3 hint while votes active
--------------------------------------------------------
hook.Add("HUDPaint", "Dubz_VoteUnlockHint", function()
    if not next(VotePanels) then return end

    for _, pnl in pairs(VotePanels) do
        if IsValid(pnl) then
            DrawDubzHint_Centered("F3", "Unlock Mouse", pnl:GetWide())
            break
        end
    end
end)

--------------------------------------------------------
-- Where to parent vote panels
--------------------------------------------------------
local function GetVoteParent()
    local root = vgui.GetWorldPanel and vgui.GetWorldPanel() or nil
    if not IsValid(root) then return nil end
    return root
end

--------------------------------------------------------
-- Create a vote UI panel
--------------------------------------------------------
function Dubz.Vote.OpenPanel(id, question, options, duration, suppressQueue)
    question = tostring(question or "")

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local localName   = lp:Nick()
    local isInitiator = string.StartWith(question, localName)

    -- Initiator does NOT see the vote UI box
    if isInitiator then return end

    local parent = GetVoteParent()
    if not IsValid(parent) then
        if not suppressQueue then
            PendingVotes[id] = {
                id       = id,
                question = question,
                options  = options,
                duration = duration
            }
        end
        return
    end

    if IsValid(VotePanels[id]) then
        VotePanels[id]:Remove()
        VotePanels[id] = nil
    end

    local panelWidth     = 360
    local textPaddingTop = 18
    local textSpacing    = 4
    local btnPanelH      = 38
    local bottomMargin   = 8
    local maxTextW       = panelWidth - 28

    local textHeight = MeasureQuestionHeight(question, "DubzHUD_Header", maxTextW)
    if textHeight <= 0 then textHeight = 24 end

    local panelHeight = textPaddingTop + textHeight + textSpacing + btnPanelH + bottomMargin

    -------------------------------------------
    -- CLEAN VOTE PANEL (NO INVISIBLE BLOCKERS)
    -------------------------------------------
    local p = vgui.Create("DPanel", parent)
    p:SetSize(panelWidth, panelHeight)
    p:SetAlpha(0)
    p:SetMouseInputEnabled(true)      -- panel receives mouse
    p:SetKeyboardInputEnabled(false)
    p.Question = question
    p.Duration = duration or 15
    p.EndTime  = CurTime() + p.Duration
    p.Id       = id

    Dubz.Vote._Index = (Dubz.Vote._Index or 0) + 1
    p.SortIndex = Dubz.Vote._Index

    -------------------------------------------
    -- SLIDE-IN ANIMATION
    -------------------------------------------
    local startX = ScrW()
    local endX   = ScrW() - p:GetWide() - 20

    p:SetPos(startX, 60)
    p:MoveTo(endX, 60, 0.20, 0, 0.1, function()
        if IsValid(p) then
            p:SetAlpha(255)
            Dubz_RepositionVotes()
        end
    end)

    function p:SlideOut()
        if self.Closing then return end
        self.Closing = true

        self:MoveTo(self.x + 40, self.y, 0.15, 0, 0.15)
        self:AlphaTo(0, 0.15, 0, function()
            if IsValid(self) then
                VotePanels[self.Id] = nil
                self:Remove()
                Dubz_RepositionVotes()
            end
        end)
    end

    function p:Think()
        if CurTime() >= self.EndTime then
            self:SlideOut()
        end
    end

    -------------------------------------------
    -- PAINT: TEXT + ACCENT BAR ONLY
    -- Nothing here receives mouse input
    -------------------------------------------
    function p:Paint(w, h)
        DrawBubble(0, 0, w, h, Color(0, 0, 0, 190))

        local accent = Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(37,150,190)
        draw.RoundedBox(0, 0, 0, 6, h, accent)

        local textX = 14
        local textY = textPaddingTop
        local maxW  = w - 28

        -- draw wrapped question text
        local bottomY = DrawWrappedQuestion(self.Question, "DubzHUD_Header", textX, textY, maxW)

        -- draw timer on same row as buttons
        surface.SetFont("DubzHUD_Small")
        local _, timerH = surface.GetTextSize("00:00")

        local rowTop = h - btnPanelH - bottomMargin + (btnPanelH - timerH) * 0.5
        local remainStr = ("00:%02d"):format(math.max(0, math.floor(self.EndTime - CurTime())))

        draw.SimpleText(
            remainStr,
            "DubzHUD_Small",
            textX,
            rowTop,
            Color(210,210,210)
        )
    end

    -------------------------------------------
    -- BUTTON ROW (TRUE INTERACTIVE LAYER)
    -------------------------------------------
    local btnBase = vgui.Create("DPanel", p)
    btnBase:Dock(BOTTOM)
    btnBase:SetTall(btnPanelH)
    btnBase:DockMargin(0, 0, 0, bottomMargin)
    btnBase:SetPaintBackground(false)
    btnBase:SetMouseInputEnabled(true)    -- ensures buttons receive input ONLY here

    local function MakeBtn(text, idx, col)
        local b = vgui.Create("DButton", btnBase)
        b:SetText("")
        b:SetSize(110, 30)
        b:SetZPos(9999)                   -- ensure buttons are always above text
        b:SetMouseInputEnabled(true)

        function b:Paint(w, h)
            local hovered = self:IsHovered()
            local c = hovered and Color(col.r + 20, col.g + 20, col.b + 20) or col

            draw.RoundedBox(6, 0, 0, w, h, c)
            draw.SimpleText(
                text,
                "DubzHUD_Small",
                w/2, h/2,
                Color(255,255,255),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end

        function b:DoClick()
            Dubz.Vote.Cast(id, idx)
            p:SlideOut()
        end

        return b
    end

    -------------------------------------------
    -- BUTTONS
    -------------------------------------------
    local yes = MakeBtn("Yes", 1, Color(30,160,60))
    local no  = MakeBtn("No", 2, Color(170,40,40))

    yes:SetPos(p:GetWide() - 240, 4)
    no:SetPos (p:GetWide() - 120, 4)

    VotePanels[id] = p
    Dubz_RepositionVotes()
end

--------------------------------------------------------
-- DarkRP notifications for vote start
--------------------------------------------------------
net.Receive("Dubz_Vote_Start", function()
    local id       = net.ReadString()
    local question = net.ReadString()
    local count    = net.ReadUInt(8)

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
