local chatPanel, chatLog
local OpenChat, CloseChat
local isOpen, teamOnly = false, false
local messageLimit = 200
Dubz = Dubz or {}
Dubz.ChatHistory = Dubz.ChatHistory or {}

local function EnsureChatPanel()
    if IsValid(chatPanel) then return chatPanel end
    chatPanel = vgui.Create("DPanel", vgui.GetWorldPanel())
    chatPanel:SetSize(420, 240)
    chatPanel:SetMouseInputEnabled(false)
    chatPanel.SetMouseInputEnabled(chatPanel, false)
    chatPanel:SetKeyboardInputEnabled(false)
    chatPanel:SetVisible(true)
    chatPanel:SetZPos(200)
    function chatPanel:Paint(w,h)
        Dubz.DrawBubble(0,0,w,h, Color(10,10,10,220))
    end

    local function UpdateChatPosition()
        if not IsValid(chatPanel) then return end
        local y = math.max(16, ScrH() - chatPanel:GetTall() - 520)
        chatPanel:SetPos(20, y)
    end
    chatPanel.UpdateChatPosition = UpdateChatPosition
    UpdateChatPosition()

    chatLog = vgui.Create("RichText", chatPanel)
    chatLog:Dock(FILL)
    chatLog:DockMargin(8,8,8,40)
    function chatLog:PerformLayout()
        self:SetFontInternal("DubzHUD_Small")
        self:SetBGColor(Color(0,0,0,0))
    end
    for _, parts in ipairs(Dubz.ChatHistory) do
        for _, item in ipairs(parts) do
            if IsColor(item) then
                chatLog:InsertColorChange(item.r, item.g, item.b, item.a or 255)
            else
                chatLog:AppendText(tostring(item))
            end
        end
        chatLog:AppendText("\n")
    end

    local entry = vgui.Create("DTextEntry", chatPanel)
    entry:Dock(BOTTOM)
    entry:SetTall(0)
    entry:SetUpdateOnType(true)
    entry:SetPlaceholderText("Type a message...")
    entry:SetVisible(false)
    if Dubz.HookTextEntry then Dubz.HookTextEntry(entry) end
    function entry:Paint(w, h)
        Dubz.DrawBubble(0, 0, w, h, Color(18, 18, 18, 240))
        self:DrawTextEntryText(Color(235,235,235), Dubz.GetAccentColor() or Color(70,150,220), Color(235,235,235))
    end
    function entry:OnEnter()
        local txt = string.Trim(self:GetText() or "")
        if txt == "" then
            self:SetText("")
            CloseChat()
            return
        end
        local cmd = teamOnly and "say_team" or "say"
        RunConsoleCommand(cmd, txt)
        self:SetText("")
        CloseChat()
    end
    chatPanel.Entry = entry

    hook.Add("OnScreenSizeChanged","Dubz_ChatResize", function()
        if IsValid(chatPanel) and chatPanel.UpdateChatPosition then
            chatPanel:UpdateChatPosition()
        end
    end)

    return chatPanel
end

local function AppendMessage(parts)
    local panel = EnsureChatPanel()
    chatLog = chatLog or panel and panel:GetChildren()[1]
    table.insert(Dubz.ChatHistory, parts)
    while #Dubz.ChatHistory > messageLimit do
        table.remove(Dubz.ChatHistory, 1)
    end
    if not IsValid(chatLog) then return end
    for _, item in ipairs(parts) do
        if IsColor(item) then
            chatLog:InsertColorChange(item.r, item.g, item.b, item.a or 255)
        else
            chatLog:AppendText(tostring(item))
        end
    end
    chatLog:AppendText("\n")
    chatLog:GotoTextEnd()
end

function OpenChat(teamChat)
    local panel = EnsureChatPanel()
    teamOnly = teamChat or false
    panel:SetMouseInputEnabled(true)
    panel:SetKeyboardInputEnabled(true)
    panel.Entry:SetKeyboardInputEnabled(true)
    panel:MakePopup()
    panel:MoveToFront()
    panel:SetAlpha(255)
    chatLog:DockMargin(8,8,8,40)
    panel.Entry:SetTall(28)
    panel.Entry:SetVisible(true)
    panel.Entry:SetText("")
    if teamOnly then
        panel.Entry:SetPlaceholderText("Team message...")
    else
        panel.Entry:SetPlaceholderText("Type a message...")
    end
    panel.Entry:RequestFocus()
    panel.Entry:MakePopup()
    timer.Simple(0, function()
        if IsValid(panel.Entry) then
            panel.Entry:RequestFocus()
        end
    end)
    gui.EnableScreenClicker(true)
    isOpen = true
end

function CloseChat()
    if not IsValid(chatPanel) then return end
    if IsValid(chatPanel.Entry) then
        chatPanel.Entry:SetText("")
        chatPanel.Entry:SetVisible(false)
        chatPanel.Entry:SetTall(0)
    end
    chatLog:DockMargin(8,8,8,8)
    chatPanel:SetMouseInputEnabled(false)
    chatPanel:SetKeyboardInputEnabled(false)
    chatPanel:SetVisible(true)
    gui.EnableScreenClicker(false)
    isOpen = false
end

hook.Add("PlayerBindPress","Dubz_OpenChat", function(ply, bind, pressed)
    if not pressed then return end
    if bind == "messagemode" then
        OpenChat(false)
        return true
    elseif bind == "messagemode2" then
        OpenChat(true)
        return true
    elseif bind == "cancelselect" and isOpen then
        CloseChat()
        return true
    end
end)

hook.Add("StartChat","Dubz_BlockDefaultChat", function(isTeam)
    OpenChat(isTeam)
    return true
end)

hook.Add("FinishChat","Dubz_CloseChatPanel", function()
    if isOpen then CloseChat() end
end)

hook.Add("HUDShouldDraw", "Dubz_HideDefaultChat", function(name)
    if name == "CHudChat" then return false end
end)

hook.Add("Think", "Dubz_ChatEscapeClose", function()
    if not isOpen then return end
    if input.IsKeyDown(KEY_ESCAPE) then
        CloseChat()
    end
end)

local function FormatPlayerMessage(ply, text, teamChat, isDead)
    local parts = {}
    if isDead then
        table.insert(parts, Color(255,80,80))
        table.insert(parts, "*DEAD* ")
    end
    if teamChat then
        table.insert(parts, Color(120,180,255))
        table.insert(parts, "(TEAM) ")
    end
    local nameCol = (IsValid(ply) and team.GetColor(ply:Team())) or Color(200,200,200)
    table.insert(parts, nameCol)
    table.insert(parts, IsValid(ply) and ply:Nick() or "Console")
    table.insert(parts, Color(255,255,255))
    table.insert(parts, ": " .. text)
    return parts
end

hook.Add("OnPlayerChat","Dubz_CustomChatCapture", function(ply, text, teamChat, isDead)
    AppendMessage(FormatPlayerMessage(ply, text, teamChat, isDead))
    return true
end)

hook.Add("ChatText","Dubz_SystemChatCapture", function(_, name, text, type)
    local parts = {}
    table.insert(parts, Color(200,200,200))
    if type == "joinleave" then
        table.insert(parts, name .. " " .. text)
    else
        table.insert(parts, text)
    end
    AppendMessage(parts)
    return true
end)

local originalAddText = chat.AddText
function chat.AddText(...)
    if originalAddText then originalAddText(...) end
    AppendMessage({...})
end
