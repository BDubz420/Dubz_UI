
Dubz.RegisterTab("discord","Discord","discord", function(parent)
    local pnl = vgui.Create("DPanel", parent)
    pnl:Dock(FILL); pnl:DockMargin(12,12,12,12)
    function pnl:Paint(w,h)
        draw.SimpleText("Discord opens from sidebar button.", "DubzHUD_Body", 12, 12, color_white)
    end
end)
