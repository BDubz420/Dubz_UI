-----------------------------------------
-- Dubz Chat - Darker HUD-Matching Version (FINAL CLEAN ORDER)
-- No errors, no duplicates, perfect HUD match + proximity preview
-----------------------------------------

local chatPanel, chatLog, entry
local isOpen, teamOnly = false, false
local lastMessageTime = 0
local fadeDuration = 6
local historyLimit = 200

Dubz = Dubz or {}
Dubz.ChatHistory = Dubz.ChatHistory or {}

local Theme = Dubz.Themes["transparent_black"]

local BASE_ALPHA  = 190
local SHADE_ALPHA = 20
local fadeAlpha = BASE_ALPHA

local CornerRadius = 12
local AccentBarWidth = 6

-----------------------------------------
-- CHAT POS (Above HUD)
-----------------------------------------
local function GetChatPos()
    return 20, ScrH() - 420
end

-----------------------------------------
-- PROXIMITY HELPERS
-----------------------------------------
local function GetProximityList()
    local lp = LocalPlayer()
    if not IsValid(lp) then return {} end

    local list = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply ~= lp then
            local dist = lp:GetPos():Distance(ply:GetPos())
            if dist <= 550 then
                local meters = math.floor(dist / 52)
                local col = (team and team.GetColor and team.GetColor(ply:Team())) or Color(200,200,200)
                table.insert(list, {
                    name = ply:Nick() or "Unknown",
                    col  = col,
                    dist = meters
                })
            end
        end
    end

    table.sort(list, function(a,b) return a.name < b.name end)
    return list
end

-----------------------------------------
-- DEFAULT CHAT FORMATTER
-----------------------------------------
local function FormatChat(ply, text, isTeam, isDead)
    local msg = {}

    if isDead then
        table.insert(msg, Color(255,80,80))
        table.insert(msg, "*DEAD* ")
    end

    if isTeam then
        table.insert(msg, Color(120,180,255))
        table.insert(msg, "(TEAM) ")
    end

    local lower = string.lower(text)

    if string.StartWith(lower, "//") or string.StartWith(lower, "/ooc") then
        table.insert(msg, Color(100,200,255))
        table.insert(msg, "(OOC) ")
        text = text:gsub("^//", ""):gsub("^/ooc", "")
    end

    if string.StartWith(lower, "/looc") then
        table.insert(msg, Color(150,150,255))
        table.insert(msg, "[LOOC] ")
        text = text:gsub("^/looc", "")
    end

    if string.StartWith(lower, "/advert") or string.StartWith(lower, "/ad") then
        table.insert(msg, Color(255,200,0))
        table.insert(msg, "[ADVERT] ")
        text = text:gsub("^/advert", ""):gsub("^/ad", "")
    end

    if string.StartWith(lower, "/pm") then
        table.insert(msg, Color(255,100,220))
        table.insert(msg, "[PM] ")
    end

    local col = IsValid(ply) and team.GetColor(ply:Team()) or Theme.Text
    table.insert(msg, col)
    table.insert(msg, IsValid(ply) and ply:Nick() or "Console")

    table.insert(msg, Theme.Text)
    table.insert(msg, ": " .. text)

    return msg
end
-----------------------------------------
-- HUD-STYLE CHAT BACKGROUND
-----------------------------------------
local function DrawHUDChatPanel(w, h, alpha)
    draw.RoundedBox(
        CornerRadius, 0, 0, w, h,
        Color(0,0,0, BASE_ALPHA)
    )

    if SHADE_ALPHA > 0 then
        draw.RoundedBox(
            CornerRadius, 0, 0, w, h,
            Color(0,0,0, SHADE_ALPHA)
        )
    end

    draw.RoundedBox(
        0, 0, 0, AccentBarWidth, h,
        Color(37,150,190, BASE_ALPHA)
    )
end

-----------------------------------------
-- ENTRY BOX
-----------------------------------------
local function DrawEntryBox(w, h)
    draw.RoundedBox(8, 0, 0, w, h, Color(0,0,0, BASE_ALPHA))
end

-----------------------------------------
-- FADE IN
-----------------------------------------
local function FadeInChat()
    if not IsValid(chatPanel) then return end
    chatPanel:SetVisible(true)
    fadeAlpha = BASE_ALPHA
    chatPanel:SetAlpha(fadeAlpha)
end

-----------------------------------------
-- APPEND CHAT MESSAGE
-----------------------------------------
local function AppendMessage(parts)
    EnsureChatPanel()

    lastMessageTime = CurTime()
    FadeInChat()

    table.insert(Dubz.ChatHistory, parts)
    while #Dubz.ChatHistory > historyLimit do
        table.remove(Dubz.ChatHistory, 1)
    end

    for _, part in ipairs(parts) do
        if IsColor(part) then
            chatLog:InsertColorChange(part.r, part.g, part.b, part.a or 255)
        else
            chatLog:AppendText(tostring(part))
        end
    end

    chatLog:AppendText("\n")
    chatLog:GotoTextEnd()
end

-----------------------------------------
-- ENSURE CHAT PANEL EXISTS
-----------------------------------------
function EnsureChatPanel()
    if IsValid(chatPanel) then return chatPanel end

    chatPanel = vgui.Create("EditablePanel")
    chatPanel:SetSize(420, 220)
    chatPanel:SetPos(GetChatPos())
    chatPanel:SetVisible(false)
    chatPanel:SetAlpha(0)
    chatPanel:SetZPos(99999)
    chatPanel.ProximityInfo = { mode = "none", list = {} }

    function chatPanel:Paint(w, h)
        if fadeAlpha <= 0 then return end
        DrawHUDChatPanel(w, h, fadeAlpha)
    end

    -------------------------------------------------
    -- CHAT LOG
    -------------------------------------------------
    chatLog = vgui.Create("RichText", chatPanel)
    chatLog:Dock(FILL)
    chatLog:DockMargin(12, 14, 12, 26)

    function chatLog:PerformLayout()
        self:SetFontInternal("DubzHUD_Small")
        self:SetBGColor(Color(0,0,0,0))
    end

    for _, msg in ipairs(Dubz.ChatHistory) do
        for _, part in ipairs(msg) do
            if IsColor(part) then
                chatLog:InsertColorChange(part.r, part.g, part.b, part.a or 255)
            else
                chatLog:AppendText(tostring(part))
            end
        end
        chatLog:AppendText("\n")
    end

    -------------------------------------------------
    -- TEXT ENTRY
    -------------------------------------------------
    entry = vgui.Create("DTextEntry", chatPanel)
    entry:Dock(BOTTOM)
    entry:DockMargin(12, 0, 12, 10)
    entry:SetTall(28)
    entry:SetUpdateOnType(true)
    entry:SetVisible(false)

    entry:SetTextColor(Theme.Text)
    entry:SetCursorColor(Theme.Text)
    entry:SetHighlightColor(Theme.Accent)

    function entry:Paint(w, h)
        DrawEntryBox(w, h)
        self:DrawTextEntryText(Theme.Text, Theme.Accent, Theme.Text)
    end

    function entry:OnMousePressed()
        self:RequestFocus()
    end

    function entry:OnEnter()
        local raw = string.Trim(self:GetText() or "")

        if raw ~= "" then
            AppendMessage( FormatChat(LocalPlayer(), raw, teamOnly, false) )
            RunConsoleCommand(teamOnly and "say_team" or "say", raw)
        end

        CloseChat()
    end

    chatPanel.Entry = entry

    -------------------------------------------------
    -- PROXIMITY PANEL
    -------------------------------------------------
    local prox = vgui.Create("Panel", chatPanel)
    prox:Dock(BOTTOM)
    prox:DockMargin(16, 0, 16, 2)
    prox:SetTall(16)

    function prox:Paint(w, h)
        if fadeAlpha <= 0 then return end
        local info = chatPanel.ProximityInfo or { mode = "none", list = {} }
        local mode = info.mode or "none"
        if mode == "none" then return end

        local alphaFrac = math.Clamp(fadeAlpha / BASE_ALPHA, 0, 1)
        local a = math.floor(255 * alphaFrac)
        if a <= 0 then return end

        surface.SetFont("DubzHUD_Small")

        if mode == "global" then
            draw.SimpleText("Global Message", "DubzHUD_Small", 0, 0, Color(200,200,200,a))
        elseif mode == "local" then
            local list = info.list or {}
            local x = 0
            local prefix = "Nearby: "
            draw.SimpleText(prefix, "DubzHUD_Small", x, 0, Color(200,200,200,a))
            local pw,_ = surface.GetTextSize(prefix)
            x = x + pw

            if #list == 0 then
                draw.SimpleText("No one nearby", "DubzHUD_Small", x, 0, Color(200,200,200,a))
            else
                for i, entryInfo in ipairs(list) do
                    local txt = string.format("%s (%dm)", entryInfo.name, entryInfo.dist)
                    draw.SimpleText(txt, "DubzHUD_Small", x, 0, Color(entryInfo.col.r, entryInfo.col.g, entryInfo.col.b, a))
                    local tw,_ = surface.GetTextSize(txt)
                    x = x + tw

                    if i < #list then
                        draw.SimpleText(", ", "DubzHUD_Small", x, 0, Color(200,200,200,a))
                        local sw,_ = surface.GetTextSize(", ")
                        x = x + sw
                    end
                end
            end
        end
    end

    chatPanel.ProximityPanel = prox

    hook.Add("OnScreenSizeChanged", "DubzChatResize", function()
        if IsValid(chatPanel) then
            chatPanel:SetPos(GetChatPos())
        end
    end)

    return chatPanel
end
-----------------------------------------
-- CLOSE CHAT
-----------------------------------------
function CloseChat()
    if not IsValid(chatPanel) then return end

    entry:SetVisible(false)
    entry:KillFocus()

    chatPanel:SetMouseInputEnabled(false)
    chatPanel:SetKeyboardInputEnabled(false)

    gui.EnableScreenClicker(false)

    local wp = vgui.GetWorldPanel()
    if IsValid(wp) then wp:RequestFocus() end

    isOpen = false
    lastMessageTime = CurTime()

    if chatPanel.ProximityInfo then
        chatPanel.ProximityInfo.mode = "none"
        chatPanel.ProximityInfo.list = {}
    end
end

-----------------------------------------
-- OPEN CHAT
-----------------------------------------
local function OpenChat(teamChat)
    EnsureChatPanel()

    teamOnly = teamChat or false
    isOpen = true

    fadeAlpha = BASE_ALPHA
    chatPanel:SetVisible(true)
    chatPanel:SetAlpha(BASE_ALPHA)

    entry:SetVisible(true)
    entry:SetText("")
    entry:SetPlaceholderText(teamOnly and "Team message..." or "Type a message...")

    chatPanel.ProximityInfo.mode = "none"
    chatPanel.ProximityInfo.list = {}

    chatPanel:MakePopup()
    gui.EnableScreenClicker(true)
    entry:RequestFocus()
end

-----------------------------------------
-- AUTO FADE OUT
-----------------------------------------
hook.Add("Think", "DubzChatFadeThink", function()
    if isOpen or not IsValid(chatPanel) then return end

    if CurTime() - lastMessageTime > fadeDuration then
        fadeAlpha = math.max(fadeAlpha - FrameTime() * 200, 0)
        chatPanel:SetAlpha(fadeAlpha)
        if fadeAlpha <= 0 then
            chatPanel:SetVisible(false)
        end
    end
end)

-----------------------------------------
-- KEYBINDS
-----------------------------------------
hook.Add("PlayerBindPress","DubzChatBinds",function(ply,bind,pressed)
    if not pressed then return end
    if bind == "messagemode" then OpenChat(false) return true end
    if bind == "messagemode2" then OpenChat(true) return true end
end)

hook.Add("StartChat","DubzChatBlockDefault",function() return true end)
hook.Add("FinishChat","DubzChatFinish",function()
    if isOpen then CloseChat() end
end)

-----------------------------------------
-- ENTRY COLOR CHANGE + PROXIMITY PREVIEW
-----------------------------------------
hook.Add("ChatTextChanged", "Dubz_LocalCommandTagging", function(text)
    if not isOpen or not IsValid(chatPanel) then return end
    if not IsValid(entry) then return end

    local lower = text:lower()

    if string.StartWith(lower, "//") or string.StartWith(lower, "/ooc") then
        entry:SetTextColor(Color(100,200,255))
        chatPanel.ProximityInfo.mode = "global"
        chatPanel.ProximityInfo.list = {}
        return
    elseif string.StartWith(lower, "/advert") or string.StartWith(lower, "/ad") then
        entry:SetTextColor(Color(255,200,0))
        chatPanel.ProximityInfo.mode = "global"
        chatPanel.ProximityInfo.list = {}
        return
    elseif string.StartWith(lower, "/looc") then
        entry:SetTextColor(Color(150,150,255))
        chatPanel.ProximityInfo.mode = "global"
        chatPanel.ProximityInfo.list = {}
        return
    end

    entry:SetTextColor(Theme.Text)
    chatPanel.ProximityInfo.mode = "local"
    chatPanel.ProximityInfo.list = GetProximityList()
end)

-----------------------------------------
-- CHAT HOOKS
-----------------------------------------
hook.Add("OnPlayerChat", "DubzChatPlayer", function(ply, text, teamChat, isDead)

    if ply == LocalPlayer() then
        return true
    end

    local lower = text:lower()

    if string.StartWith(lower, "//")
    or string.StartWith(lower, "/ooc")
    or string.StartWith(lower, "/advert")
    or string.StartWith(lower, "/ad")
    or string.StartWith(lower, "/looc")
    or string.StartWith(lower, "/pm") then
        return true
    end

    AppendMessage(FormatChat(ply, text, teamChat, isDead))
    return true
end)

hook.Add("ChatText","DubzChatSystem",function(_,name,text)
    AppendMessage({ Theme.Text, name .. " " .. text })
    return true
end)

-----------------------------------------
-- FIXED BUG: chat.AddText override
-----------------------------------------
local oldAdd = chat.AddText
function chat.AddText(...)
    if oldAdd then oldAdd(...) end
    AppendMessage({...})
end    -- ★ FIXED: removed incorrect extra ")"

-----------------------------------------
-- DARKRP CHAT TYPES
-----------------------------------------
hook.Add("DarkRPFinishedChat","Dubz_DarkRPChatSupport",function(ply,text,type)
    if not text or text == "" then return end

    local msg = {}

    if type=="advert" then
        table.insert(msg,Color(255,200,0));   table.insert(msg,"[ADVERT] ")
    elseif type=="ooc" then
        table.insert(msg,Color(100,200,255)); table.insert(msg,"(OOC) ")
    elseif type=="looc" then
        table.insert(msg,Color(150,150,255)); table.insert(msg,"[LOOC] ")
    elseif type=="pm" then
        table.insert(msg,Color(255,100,220)); table.insert(msg,"[PM] ")
    elseif type=="gang" then
        table.insert(msg,Color(0,255,0));     table.insert(msg,"[GANG] ")
    elseif type=="group" then
        table.insert(msg,Color(255,180,180)); table.insert(msg,"[GROUP] ")
    end

    local col = IsValid(ply) and team.GetColor(ply:Team()) or Theme.Text
    table.insert(msg, col)
    table.insert(msg, IsValid(ply) and ply:Nick()..": " or "Console: ")

    table.insert(msg, Theme.Text)
    table.insert(msg, text)

    AppendMessage(msg)
end)
