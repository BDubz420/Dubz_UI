Dubz = Dubz or {}

-- Load Dubz UI config + core
include("autorun/dubz_ui_config.lua")
include("dubz_shared/sh_dubz_log.lua")
include("dubz_menu/ui_helpers.lua")
include("dubz_ui/themes.lua")

-- Fonts
surface.CreateFont("DubzHUD_Header", { font = "Roboto Bold", size = 22, weight = 600 })
surface.CreateFont("DubzHUD_Body",   { font = "Roboto",      size = 18, weight = 500 })
surface.CreateFont("DubzHUD_Small",  { font = "Roboto",      size = 16, weight = 400 })
surface.CreateFont("DubzHUD_Money",  { font = "Roboto Bold", size = 24, weight = 800 })

-- Disable default scoreboard + default DarkRP HUD
hook.Add("ScoreboardShow", "Dubz_NoDefaultScoreboard", function() return false end)
hook.Add("ScoreboardHide", "Dubz_NoDefaultScoreboard", function() return false end)

hook.Add("HUDShouldDraw","Dubz_DisableDefaultHUDPieces", function(name)
    if name=="DarkRP_HUD" or name=="DarkRP_LocalPlayerHUD" then return false end
    if name=="DarkRP_Hungermod" or name=="DarkRP_LocalPlayerHunger" or name=="DarkRP_Energy" then return false end
end)

-- Core UI modules
include("dubz_hud/cl_hud.lua")
include("dubz_hud/cl_chat.lua")
include("dubz_hud/cl_voice.lua")
include("dubz_overhead/cl_overhead.lua")
include("dubz_menu/cl_menu.lua")
include("dubz_menu/tabs/cl_tab_dashboard.lua")
include("dubz_menu/tabs/cl_tab_players.lua")
include("dubz_menu/tabs/cl_tab_jobs.lua")
include("dubz_menu/tabs/cl_tab_market.lua")
include("dubz_menu/tabs/cl_tab_gangs.lua")
include("dubz_menu/cl_admin.lua")
include("dubz_vote/sh_dubz_vote.lua")
include("dubz_vote/cl_dubz_vote.lua")

-- Notifications
include("dubz_notifications/cl_notifications.lua")

-- Chat admin window
hook.Add("OnPlayerChat", "Dubz_LogsChatCommand", function(ply, text)
    if ply ~= LocalPlayer() then return end

    local cfg = Dubz.Config.Admin and Dubz.Config.Admin.ChatCommand
    if not (cfg and cfg.Enabled) then return end

    local s = string.Trim(string.lower(text))
    for _, trig in ipairs(cfg.Triggers or {}) do
        if s == string.lower(trig) then
            local allowed = false
            for _, g in ipairs(cfg.Permissions or {}) do
                if ply:IsUserGroup(g) then allowed = true break end
            end

            if allowed and Dubz.OpenAdminWindow then
                Dubz.OpenAdminWindow()
            else
                chat.AddText(Color(255,80,80), "[DubzUI] No permission.")
            end
            return true
        end
    end
end)

-- Richest leaderboard sync
Dubz.RichestPlayers = Dubz.RichestPlayers or {}
Dubz.RichestGangs = Dubz.RichestGangs or {}

net.Receive("Dubz_RichestSync", function()
    local len = net.ReadUInt(16)
    local data = net.ReadData(len)
    local json = util.Decompress(data or "") or "{}"
    local tbl = util.JSONToTable(json) or {}
    Dubz.RichestPlayers = tbl.players or {}
    Dubz.RichestGangs = tbl.gangs or {}
end)

Dubz.Log("Dubz UI " .. (Dubz.Config.Version or "") .. " loaded.")
