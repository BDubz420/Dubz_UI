
function Dubz.OpenAdminWindow()
    local ov = vgui.Create("DPanel"); ov:SetSize(ScrW(), ScrH()); ov:SetPos(0,0)
    function ov:Paint(w,h) draw.RoundedBox(0,0,0,w,h, Color(0,0,0,170)) end

    local win = vgui.Create("DFrame", ov); win:SetSize(700, 520); win:Center(); win:SetTitle(""); win:MakePopup()
    function win:OnClose() ov:Remove() end
    function win:Paint(w,h) Dubz.DrawBubble(0,0,w,h, Color(18,18,18,240)) end

    local tabs = vgui.Create("DPropertySheet", win); tabs:Dock(FILL); tabs:DockMargin(8,8,8,8)

    local overview = vgui.Create("DPanel", tabs)
    function overview:Paint(w,h)
        draw.SimpleText("Admin Overview","DubzHUD_Header", 12, 12, Dubz.GetAccentColor())
        draw.SimpleText("Use the Logs tab to view real-time UI logs.","DubzHUD_Body", 12, 42, Color(230,230,230))
    end
    tabs:AddSheet("Overview", overview, nil, false, false, "Summary")

    local logs = vgui.Create("DPanel", tabs); logs:Dock(FILL)
    function logs:Paint(w,h) Dubz.DrawBubble(0,0,w,h, Color(24,24,24,220)) end
    local top = vgui.Create("DPanel", logs); top:Dock(TOP); top:SetTall(36)
    local search = vgui.Create("DTextEntry", top); search:Dock(LEFT); search:SetWide(240); search:SetPlaceholderText("Search...")
    local filter = vgui.Create("DComboBox", top); filter:Dock(LEFT); filter:SetWide(120); filter:AddChoice("ALL"); filter:AddChoice("INFO"); filter:AddChoice("WARN"); filter:AddChoice("ERROR"); filter:ChooseOptionID(1)
    local clear = vgui.Create("DButton", top); clear:Dock(RIGHT); clear:SetWide(80); clear:SetText("Clear")
    local export = vgui.Create("DButton", top); export:Dock(RIGHT); export:SetWide(80); export:SetText("Export")

    local list = vgui.Create("DListView", logs)
    list:Dock(FILL); list:AddColumn("Time", 1); list:AddColumn("Level", 2); list:AddColumn("Message", 3)

    local function refresh()
        list:Clear()
        local q = string.lower(search:GetValue() or "")
        local level = filter:GetSelected() and select(1, filter:GetSelected()) or "ALL"
        for _, e in ipairs(Dubz.Logs or {}) do
            if level ~= "ALL" and e.level ~= level then goto cont end
            if q ~= "" and not string.find(string.lower(e.msg), q, 1, true) then goto cont end
            list:AddLine(e.time or "??", e.level or "INFO", e.msg or "")
            ::cont::
        end
    end
    search.OnValueChange = refresh
    filter.OnSelect = function() refresh() end
    clear.DoClick = function()
        Dubz.Logs = {}
        if file.Exists("dubz_ui/logs.txt","DATA") then file.Write("dubz_ui/logs.txt","") end
        refresh()
    end
    export.DoClick = function()
        if not file.Exists("dubz_ui","DATA") then file.CreateDir("dubz_ui") end
        local buff = ""
        for _, e in ipairs(Dubz.Logs or {}) do
            buff = buff .. string.format("[%s] [%s] %s\n", e.time, e.level, e.msg)
        end
        file.Write("dubz_ui/logs_export.txt", buff)
        chat.AddText(Color(60,255,90), "[DubzUI] Logs exported to data/dubz_ui/logs_export.txt")
    end

    timer.Create("Dubz_AdminLogsRefresh", 1, 0, function() if IsValid(list) then refresh() else timer.Remove("Dubz_AdminLogsRefresh") end end)
    refresh()

    tabs:AddSheet("Logs", logs, nil, false, false, "View logs")
    win:InvalidateLayout(true)
    return win
end

function Dubz.OpenAdminLogsTab()
    local w = Dubz.OpenAdminWindow and Dubz.OpenAdminWindow()
    timer.Simple(0, function()
        if not IsValid(w) then return end
        for _, child in ipairs(w:GetChildren()) do
            if child:GetClassName() == "DPropertySheet" then
                child:SetActiveTab(child.Items[2].Tab)
            end
        end
    end)
end
