local voiceContainer
local voicePanels = {}

local function EnsureVoiceContainer()
    if IsValid(voiceContainer) then return voiceContainer end
    voiceContainer = vgui.Create("DPanel")
    voiceContainer:SetSize(260, ScrH() * 0.35)
    voiceContainer:SetPos(ScrW() - 280, ScrH() * 0.4)
    voiceContainer:SetPaintBackground(false)
    hook.Add("OnScreenSizeChanged","Dubz_VoiceResize", function()
        if IsValid(voiceContainer) then
            voiceContainer:SetPos(ScrW() - 280, ScrH() * 0.4)
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
        draw.SimpleText(name, "DubzHUD_Small", 44, h/2, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
