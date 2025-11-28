if not Dubz then return end

--------------------------------------------------------
-- Dubz Vote UI (Client)
--------------------------------------------------------

Dubz.Vote        = Dubz.Vote or {}
Dubz.Vote.Client = Dubz.Vote.Client or {}

local VotePanels   = {}
local PendingVotes = {}

--------------------------------------------------------
-- Helper: "[F3] Unlock Mouse" hint (Dubz style)
--------------------------------------------------------
local function DrawDubzHint_Centered(key, label, votePanelWidth)
    if not votePanelWidth or votePanelWidth <= 0 then return end

    local keyW, keyH = 26, 18
    local pad        = 8

    surface.SetFont("DubzHUD_Small")
    local tw = surface.GetTextSize(label)
    local totalW = keyW + pad + tw

    local x = ScrW() - votePanelWidth - 20 + (votePanelWidth - totalW) * 0.5
    local y = 20

    local accent = Dubz.GetAccentColor and Dubz.GetAccentColor() or Color(37,150,190)

    draw.RoundedBox(6, x, y, keyW, keyH, accent)
    draw.SimpleText(
        key,
        "DubzHUD_Small",
        x + keyW / 2, y + keyH / 2,
        Color(255,255,255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        label,
        "DubzHUD_Small",
        x + keyW + pad, y + keyH / 2,
        Color(230,230,230),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )
end

--------------------------------------------------------
-- Helper: find job inside question (longest team name)
--------------------------------------------------------
local function SplitQuestionJob(question)
    question = tostring(question or "")
    if question == "" then return "", "" end

    local qlower = string.lower(question)
    local bestName, bestPos = nil, nil

    for _, t in pairs(team.GetAllTeams()) do
        local name = t.Name
        if name and name ~= "" then
            local nlower = string.lower(name)
            local pos = string.find(qlower, nlower, 1, true)
            if pos and (not bestName or #name > #bestName) then
                bestName = name
                bestPos  = pos
            end
        end
    end

    if not bestName or not bestPos then
        return question, ""
    end

    local base = string.sub(question, 1, bestPos - 1)
    return base, bestName
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

--------------------------------------------------------
-- Wrapped question helpers (Option B: inline colored job)
--------------------------------------------------------
local function BuildQuestionSegments(question)
    question = tostring(question or "")
    local base, job = SplitQuestionJob(question)

    local segments = {}

    local baseCol = Color(255,255,255)
    local jobCol  = Color(255,255,255)

    if job ~= "" then
        for _, t in pairs(team.GetAllTeams()) do
            if string.lower(t.Name) == string.lower(job) then
                jobCol = t.Color or jobCol
                break
            end
        end
    end

    for w in string.gmatch(base or "", "%S+") do
        table.insert(segments, { text = w, col = baseCol })
    end

    if job ~= "" then
        for w in string.gmatch(job or "", "%S+") do
            table.insert(segments, { text = w, col = jobCol })
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

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local localName = lp:Nick()
    local base, job = SplitQuestionJob(question)

    if DarkRP and DarkRP.notify then
        if string.StartWith(question, localName) then
            if job ~= "" then
                DarkRP.notify(lp, 0, 5, "You started a vote to become " .. job)
            else
                DarkRP.notify(lp, 0, 5, "You started a vote.")
            end
        else
            local msg = string.Trim((base or "") .. (job or ""))
            DarkRP.notify(lp, 0, 5, msg)
        end
    end

    Dubz.Vote.OpenPanel(id, question, options, duration)
end)

--------------------------------------------------------
-- DarkRP notifications for vote end
--------------------------------------------------------
net.Receive("Dubz_Vote_End", function()
    local id      = net.ReadString()
    local count   = net.ReadUInt(8)
    local results = {}

    for i = 1, count do
        results[i] = net.ReadUInt(12)
    end

    local winner    = net.ReadUInt(8)
    local cancelled = net.ReadBool()

    local pnl      = VotePanels[id]
    local question = pnl and pnl.Question or ""
    local lp       = LocalPlayer()
    if IsValid(pnl) then pnl:SlideOut() end
    if not IsValid(lp) then return end

    local localName = lp:Nick()
    local base, job = SplitQuestionJob(question)

    if not (DarkRP and DarkRP.notify) then return end

    if string.StartWith(question, localName) then
        if cancelled then
            if job ~= "" then
                DarkRP.notify(lp, 1, 4, "The vote for " .. job .. " was cancelled.")
            else
                DarkRP.notify(lp, 1, 4, "The vote was cancelled.")
            end
        elseif winner == 1 then
            if job ~= "" then
                DarkRP.notify(lp, 0, 4, "You have been made " .. job .. "!")
            else
                DarkRP.notify(lp, 0, 4, "You won the vote.")
            end
        else
            if job ~= "" then
                DarkRP.notify(lp, 1, 4, "You have not been made " .. job .. ".")
            else
                DarkRP.notify(lp, 1, 4, "You did not win the vote.")
            end
        end
    end
end)

--------------------------------------------------------
-- Cast vote
--------------------------------------------------------
function Dubz.Vote.Cast(id, choice)
    net.Start("Dubz_Vote_Cast")
        net.WriteString(id)
        net.WriteUInt(choice, 8)
    net.SendToServer()
end

--------------------------------------------------------
-- Dev test command
--------------------------------------------------------
concommand.Add("dubz_vote_test_cl", function()
    Dubz.Vote.OpenPanel(
        "cltest_" .. CurTime(),
        "Client Test Vote for a very long role name that should wrap correctly when it gets too big",
        { "Yes", "No" },
        15
    )
end)
