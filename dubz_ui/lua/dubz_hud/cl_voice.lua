if not Dubz then return end

local voiceContainer
local voicePanels = {}

------------------------------------------
-- VOICE PANELS (who is currently talking)
------------------------------------------
local function EnsureVoiceContainer()
    if IsValid(voiceContainer) then return voiceContainer end

    voiceContainer = vgui.Create("DPanel")
    voiceContainer:SetSize(260, ScrH() * 0.35)
    voiceContainer:SetPos(ScrW() - 280, ScrH() * 0.40)
    voiceContainer:SetPaintBackground(false)

    hook.Add("OnScreenSizeChanged","Dubz_VoiceResize", function()
        if IsValid(voiceContainer) then
            voiceContainer:SetPos(ScrW() - 280, ScrH() * 0.40)
        end
    end)

    return voiceContainer
end

local function CreateVoicePanel(ply)
    local parent = EnsureVoiceContainer()
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0,0,0,6)
    panel:SetTall(40)

    function panel:Paint(w,h)
        Dubz.DrawBubble(0,0,w,h, Color(20,20,20,220))

        local name = IsValid(ply) and ply:Nick() or "Player"
        draw.SimpleText(
            name,
            "DubzHUD_Small",
            44, h / 2,
            Color(255,255,255),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
    end

    local avatar = vgui.Create("AvatarImage", panel)
    avatar:SetSize(32,32)
    avatar:SetPos(6,4)
    if IsValid(ply) then avatar:SetPlayer(ply, 32) end
    panel.Avatar = avatar

    return panel
end

hook.Add("PlayerStartVoice","Dubz_VoiceHUD_Start", function(ply)
    if not IsValid(ply) then return end
    if voicePanels[ply] and IsValid(voicePanels[ply]) then return end

    voicePanels[ply] = CreateVoicePanel(ply)
end)

local function RemoveVoicePanel(ply)
    local panel = voicePanels[ply]
    if IsValid(panel) then panel:Remove() end
    voicePanels[ply] = nil

    if IsValid(voiceContainer) and #voiceContainer:GetChildren() == 0 then
        voiceContainer:Remove()
        voiceContainer = nil
    end
end

hook.Add("PlayerEndVoice","Dubz_VoiceHUD_End", function(ply)
    RemoveVoicePanel(ply)
end)

hook.Add("EntityRemoved","Dubz_VoiceCleanup", function(ent)
    if voicePanels[ent] then
        RemoveVoicePanel(ent)
    end
end)

------------------------------------------
-- CUSTOM "WHO CAN HEAR YOU" UI (Dubz)
------------------------------------------

local hearList  = {}
local hearAlpha = 0

local CHAT_TOP_OFFSET = 250   -- aligns top edge to chat's top
local PADDING_X = 12
local PADDING_Y = 8
local LINE_SPACE = 20

-- Build list of players that can hear LOCAL PLAYER
local function RebuildHearList()
    hearList = {}

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= lp and IsValid(ply) then
            local canHear = hook.Run("PlayerCanHearPlayersVoice", ply, lp)
            if canHear == true then
                table.insert(hearList, ply)
            end
        end
    end

    -- Sort by name
    table.sort(hearList, function(a, b)
        return a:Nick() < b:Nick()
    end)
end

hook.Add("PlayerStartVoice", "Dubz_WhoCanHearYou_Start", function(ply)
    if ply ~= LocalPlayer() then return end
    RebuildHearList()
    hearAlpha = 255
end)

hook.Add("PlayerEndVoice", "Dubz_WhoCanHearYou_End", function(ply)
    if ply ~= LocalPlayer() then return end
end)

hook.Add("Think", "Dubz_WhoCanHearYou_Think", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:IsSpeaking() then
        RebuildHearList()
    end
end)
--[[
hook.Add("HUDPaint", "Dubz_DrawWhoCanHearYou", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- Fade logic
    if lp:IsSpeaking() then
        hearAlpha = Lerp(FrameTime() * 10, hearAlpha, 255)
    else
        hearAlpha = Lerp(FrameTime() * 5, hearAlpha, 0)
    end

    if hearAlpha <= 1 then return end

    surface.SetFont("DubzHUD_Small")

    local header = "Players who can hear you:"
    local headerW, headerH = surface.GetTextSize(header)

    -- longest name for width
    local maxNameW = headerW
    for _, ply in ipairs(hearList) do
        local w = surface.GetTextSize(ply:Nick())
        if w > maxNameW then maxNameW = w end
    end

    ----------------------------------------------------------
    -- FINAL POSITION: SAME AS OLD "NO ONE CAN HEAR YOU" TEXT
    -- YOUR SCREENSHOTS SHOW THIS IS ABOUT 170px FROM BOTTOM
    ----------------------------------------------------------
    local TARGET_Y = ScrH() - 170    -- << perfect matching position
    local TARGET_X = 20

    local paddingX  = 12
    local paddingY  = 8
    local lineSpace = 20

    local totalNames = #hearList
    local boxW = maxNameW + paddingX * 2
    local boxH = paddingY * 2 + headerH + (totalNames * lineSpace)

    ----------------------------------------------------------
    -- Draw downward from target Y (matches old GMod voice UI)
    ----------------------------------------------------------
    local x = TARGET_X
    local y = TARGET_Y

    -- Background
    Dubz.DrawBubble(
        x, y,
        boxW, boxH,
        Color(0, 0, 0, math.floor(180 * (hearAlpha / 255)))
    )

    -- Header
    draw.SimpleText(
        header,
        "DubzHUD_Small",
        x + paddingX,
        y + paddingY,
        Color(255, 255, 255, hearAlpha)
    )

    -- Names below header
    local ny = y + paddingY + headerH + 4

    for _, ply in ipairs(hearList) do
        local col = team.GetColor(ply:Team()) or Color(255,255,255)
        draw.SimpleText(
            ply:Nick(),
            "DubzHUD_Small",
            x + paddingX,
            ny,
            Color(col.r, col.g, col.b, hearAlpha)
        )
        ny = ny + lineSpace
    end
end)

--]]
hook.Add("HUDShouldDraw", "Dubz_HideDefaultGModVoiceUI", function(name)
    if name == "CHudVoiceStatus" then return false end
    if name == "CHudVoiceSelfStatus" then return false end
end)

-- Also remove DarkRP's clientside receiver icons just in case
hook.Add("HUDShouldDraw", "Dubz_HideDarkRPReceiverUI", function(name)
    if name == "DarkRP_HearNotice" then return false end
end)

hook.Add("PlayerStartVoice", "Dubz_DisableVoiceIcon", function(ply)
    ply.DRPShowIcon = false
end)