local chatPanel, chatLog
local isOpen, teamOnly = false, false
local messageLimit = 200
Dubz = Dubz or {}
Dubz.ChatHistory = Dubz.ChatHistory or {}

local function EnsureChatPanel()
    if IsValid(chatPanel) then return chatPanel end
    chatPanel = vgui.Create("DPanel")
    chatPanel:SetSize(420, 220)
    chatPanel:SetPos(20, ScrH() - 260)
    chatPanel:SetVisible(false)
    chatPanel:SetZPos(200)
    function chatPanel:Paint(w,h)
        Dubz.DrawBubble(0,0,w,h, Color(10,10,10,220))
    end

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
    entry:SetTall(28)
    entry:SetUpdateOnType(true)
    entry:SetPlaceholderText("Type a message...")
    if Dubz.HookTextEntry then Dubz.HookTextEntry(entry) end
    function entry:OnEnter()
        local txt = string.Trim(self:GetText() or "")
        if txt == "" then
            chatPanel:SetVisible(false)
            gui.EnableScreenClicker(false)
            isOpen = false
            self:SetText("")
            return
        end
        local cmd = teamOnly and "say_team" or "say"
        RunConsoleCommand(cmd, txt)
        self:SetText("")
        chatPanel:SetVisible(false)
        gui.EnableScreenClicker(false)
        isOpen = false
    end
    chatPanel.Entry = entry

    hook.Add("OnScreenSizeChanged","Dubz_ChatResize", function()
        if IsValid(chatPanel) then
            chatPanel:SetPos(20, ScrH() - chatPanel:GetTall() - 40)
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

local function OpenChat(teamChat)
    local panel = EnsureChatPanel()
    teamOnly = teamChat or false
    panel:SetVisible(true)
    panel.Entry:SetText("")
    if teamOnly then
        panel.Entry:SetPlaceholderText("Team message...")
    else
        panel.Entry:SetPlaceholderText("Type a message...")
    end
    panel.Entry:RequestFocus()
    gui.EnableScreenClicker(true)
    isOpen = true
end

local function CloseChat()
    if not IsValid(chatPanel) then return end
    chatPanel:SetVisible(false)
    if IsValid(chatPanel.Entry) then chatPanel.Entry:SetText("") end
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
    end
end)

hook.Add("StartChat","Dubz_BlockDefaultChat", function()
    return true
end)

hook.Add("FinishChat","Dubz_CloseChatPanel", function()
    if isOpen then CloseChat() end
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
