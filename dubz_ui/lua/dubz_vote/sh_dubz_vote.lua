Dubz = Dubz or {}
Dubz.Vote = Dubz.Vote or {}
Dubz.Vote.Active = Dubz.Vote.Active or {}
Dubz.Vote.Config = Dubz.Vote.Config or {}

-- Default settings
Dubz.Vote.Config.DefaultDuration = Dubz.Vote.Config.DefaultDuration or 15 -- seconds

-- Helper to log
function Dubz.Vote.Log(msg)
    if Dubz.Log then
        Dubz.Log("[VOTE] " .. msg)
    else
        print("[DubzVote] " .. msg)
    end
end
