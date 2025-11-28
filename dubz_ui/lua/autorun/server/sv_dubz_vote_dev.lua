-- ============================================================
-- Dubz Vote Dev Mode
-- Allows manual UI testing + spoof SteamID
-- ============================================================

CreateConVar("dubz_vote_devmode", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, 
    "Enable Dubz vote dev mode")

CreateConVar("dubz_vote_dev_steamid", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, 
    "Fake SteamID64 used when devmode is enabled")

local function IsDev(ply)
    if not IsValid(ply) then return false end
    if not GetConVar("dubz_vote_devmode"):GetBool() then return false end

    local allowedSteamID = GetConVar("dubz_vote_dev_steamid"):GetString()
    if allowedSteamID == "0" or allowedSteamID == "" then return false end

    return ply:SteamID64() == allowedSteamID
end

-- DEV COMMAND: force a UI popup
concommand.Add("dubz_vote_test", function(ply)
    if not IsValid(ply) or not IsDev(ply) then return end

    Dubz.Vote.Start("devtest_" .. CurTime(), {
        question = "DEV TEST: Do you like this popup?",
        options  = { "Yes", "No", "Maybe" },
        duration = 12,
        type     = "generic",
        payload  = {}
    })
end)

-- Optional: custom test with custom question/options
concommand.Add("dubz_vote_test_custom", function(ply, cmd, args)
    if not IsValid(ply) or not IsDev(ply) then return end
    
    local question = args[1] or "Custom Question?"
    local opts = {}
    for i = 2, #args do
        opts[#opts + 1] = args[i]
    end
    if #opts == 0 then opts = {"A", "B"} end

    Dubz.Vote.Start("devcustom_"..CurTime(), {
        question = question,
        options  = opts,
        duration = 15,
        type     = "generic"
    })
end)
