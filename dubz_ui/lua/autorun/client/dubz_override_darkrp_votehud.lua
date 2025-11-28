-- Completely disable DarkRP's built-in vote HUD.
-- We let Dubz.Vote handle everything visually instead.

local function KillDarkRPVoteHUD()
    if not DarkRP then return end

    -- Nuke the draw functions if they exist
    DarkRP.drawVoteScreen       = function() end
    DarkRP.drawVoteScreenHints  = function() end
end

hook.Add("InitPostEntity", "Dubz_KillDarkRPVoteHUD", KillDarkRPVoteHUD)
hook.Add("OnGamemodeLoaded", "Dubz_KillDarkRPVoteHUD", KillDarkRPVoteHUD)
timer.Simple(5, KillDarkRPVoteHUD) -- fallback in case DarkRP loads late
