--------------------------------------------------------
-- Dubz Door UI (client)
-- For stock DarkRP doors
--------------------------------------------------------

Dubz = Dubz or {}
Dubz.DoorUI = Dubz.DoorUI or {}

local DoorUI = Dubz.DoorUI
DoorUI.State = DoorUI.State or setmetatable({}, { __mode = "k" })
local DoorStates = DoorUI.State

--------------------------------------------------------
-- Networked door state cache
--------------------------------------------------------

local function CacheDoorOwner(data, owner)
    if IsValid(owner) and owner:IsPlayer() then
        data.owner = owner
        data.ownerSid64 = owner:SteamID64() or data.ownerSid64
        data.ownerName = owner:Nick() or data.ownerName
    end
end

net.Receive("Dubz_DoorUI_DoorUpdated", function()
    local door = net.ReadEntity()
    if not IsValid(door) then return end

    local owner = net.ReadEntity()
    local ownerSid = net.ReadString()
    local ownerName = net.ReadString()
    local title = net.ReadString()
    local locked = net.ReadBool()
    local nonown = net.ReadBool()

    local data = DoorStates[door] or {}
    data.ownerSid64 = ownerSid ~= "" and ownerSid or data.ownerSid64
    data.ownerName = ownerName ~= "" and ownerName or data.ownerName
    data.title     = title
    data.locked    = locked
    data.nonown    = nonown
    data.updated   = CurTime()

    CacheDoorOwner(data, owner)

    DoorStates[door] = data
end)

hook.Add("EntityRemoved", "Dubz_DoorUI_ClearState", function(ent)
    if DoorStates[ent] then
        DoorStates[ent] = nil
    end
end)

--------------------------------------------------------
-- Helpers / detection
--------------------------------------------------------

local function Notify(msg, col)
    col = col or Color(0, 200, 255)
    if DarkRP and DarkRP.notify then
        DarkRP.notify(LocalPlayer(), 0, 4, msg)
    else
        chat.AddText(col, "[Door] ", color_white, msg)
    end
end

local function IsDoor(ent)
    if not IsValid(ent) then return false end

    -- DarkRP extension
    if ent.isDoor then
        local ok, res = pcall(function() return ent:isDoor() end)
        if ok then return res end
    end

    local class = string.lower(ent:GetClass() or "")
    return class:find("door", 1, true) ~= nil
        or class:find("prop_door", 1, true) ~= nil
        or class:find("func_door", 1, true) ~= nil
end

local function GetOwner(ent)
    local data = DoorStates[ent]
    if data then
        if IsValid(data.owner) then
            return data.owner
        end

        if data.ownerSid64 and data.ownerSid64 ~= "" then
            for _, ply in ipairs(player.GetAll()) do
                if ply:SteamID64() == data.ownerSid64 then
                    CacheDoorOwner(data, ply)
                    return ply
                end
            end
        end
    end

    if not ent.getDoorOwner then return nil end
    local owner = ent:getDoorOwner()
    if IsValid(owner) and owner:IsPlayer() then
        return owner
    end
    return nil
end

local function GetOwnerName(ent)
    local data = DoorStates[ent]
    if data and data.ownerName and data.ownerName ~= "" then
        return data.ownerName
    end

    local owner = GetOwner(ent)
    return IsValid(owner) and owner:Nick() or nil
end

local function GetCoOwners(ent)
    if not ent.getKeysCoOwners then return {} end

    local out = {}
    local co = ent:getKeysCoOwners() or {}

    -- keys are entity indexes
    for idx in pairs(co) do
        local ply = Entity(idx)
        if IsValid(ply) and ply:IsPlayer() then
            table.insert(out, ply)
        end
    end

    return out
end

local function IsNonOwnable(ent)
    local data = DoorStates[ent]
    if data and data.nonown ~= nil then
        return data.nonown
    end

    if ent.getKeysNonOwnable then
        return ent:getKeysNonOwnable()
    end
    return false
end

local function IsOwned(ent)
    if ent.isKeysOwned then
        return ent:isKeysOwned()
    end
    return false
end

local function IsOwnedByLocal(ent)
    local ply = LocalPlayer()
    local owner = GetOwner(ent)
    if owner == ply then return true end

    for _, v in ipairs(GetCoOwners(ent)) do
        if v == ply then
            return true
        end
    end

    return false
end

local function GetTitle(ent)
    local data = DoorStates[ent]
    if data and data.title then
        return data.title
    end

    if ent.getKeysTitle then
        return ent:getKeysTitle() or ""
    end
    return ""
end

local function GetLockedState(ent)
    local data = DoorStates[ent]
    if data and data.locked ~= nil then
        return data.locked
    end

    return ent:GetInternalVariable("m_bLocked") or false
end

local function GetDoorGroups()
    local out = {}
    if DarkRP and DarkRP.getDoorGroups then
        local groups = DarkRP.getDoorGroups()
        if istable(groups) then
            for name, _ in pairs(groups) do
                table.insert(out, name)
            end
        end
    end
    table.sort(out, function(a,b) return a:lower() < b:lower() end)
    return out
end

local function GetPotentialCoOwners(ent)
    local owner = GetOwner(ent)
    local co = {}
    for _, p in ipairs(GetCoOwners(ent)) do
        co[p] = true
    end

    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if ply ~= owner and ply ~= LocalPlayer() and not co[ply] then
            if ply:Alive() and ply:GetPos():Distance(ent:GetPos()) < 500 then
                table.insert(out, ply)
            end
        end
    end

    table.SortByMember(out, "Nick", true)
    return out
end

local function GetRemovableCoOwners(ent)
    local out = {}
    for _, ply in ipairs(GetCoOwners(ent)) do
        if ply ~= GetOwner(ent) then
            table.insert(out, ply)
        end
    end
    table.SortByMember(out, "Nick", true)
    return out
end

--------------------------------------------------------
-- Dubz-style drawing helpers
--------------------------------------------------------

local FONT_TITLE = "DubzHUD_Header"
local FONT_BODY  = "DubzHUD_Body"
local FONT_SMALL = "DubzHUD_Small"

surface.CreateFont("DubzDoor_Title", {
    font = "Montserrat Bold",
    size = 24,
    weight = 700,
})

surface.CreateFont("DubzDoor_Owner", {
    font = "Montserrat Medium",
    size = 22,   -- slightly larger for readability
    weight = 500,
})

surface.CreateFont("DubzDoor_Lock", {
    font = "Montserrat Medium",
    size = 20,
    weight = 600,
})

local ACCENT = (Dubz.GetAccentColor and Dubz.GetAccentColor()) or Color(0, 200, 255)
local WHITE  = Color(255,255,255)
local GRAY   = Color(210,210,210)

local function DrawBubble(x,y,w,h,col)
    col = col or Color(0,0,0,200)
    if Dubz.DrawBubble then
        Dubz.DrawBubble(x,y,w,h,col)
    else
        draw.RoundedBox(12, x, y, w, h, col)
    end
end

local function DrawLockIcon(cx, cy, size, locked)
    local col = locked and Color(230, 80, 80) or Color(80, 220, 100)
    local outline = Color(0,0,0,220)

    local half = size * 0.5
    local bodyH = size * 0.55
    local bodyW = size * 0.7
    local bodyX = cx - bodyW * 0.5
    local bodyY = cy - bodyH * 0.5 + size * 0.15

    -- shackle
    surface.SetDrawColor(col)
    surface.DrawOutlinedRect(cx - bodyW*0.35, bodyY - size*0.4, bodyW*0.7, size*0.45, 2)
    -- fill a bit
    surface.DrawRect(cx - bodyW*0.35 + 2, bodyY - size*0.4 + 2, bodyW*0.7 - 4, size*0.22)

    -- body
    surface.DrawRect(bodyX, bodyY, bodyW, bodyH)
    surface.SetDrawColor(outline)
    surface.DrawOutlinedRect(bodyX, bodyY, bodyW, bodyH, 2)

    -- keyhole
    surface.SetDrawColor(0,0,0,230)
    surface.DrawRect(cx - 2, bodyY + bodyH*0.25, 4, bodyH*0.45)
    surface.DrawRect(cx - 4, bodyY + bodyH*0.2, 8, 6)
end

local function GetDoorCenterWorld(door)
    if not IsValid(door) then return nil end
    local mins, maxs = door:OBBMins(), door:OBBMaxs()
    local center = (mins + maxs) * 0.5
    return door:LocalToWorld(center)
end

--------------------------------------------------------
-- HUD: middle-of-door info
--------------------------------------------------------

local function DrawDoorHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local tr = ply:GetEyeTrace()
    if not tr.Hit then return end

    local door = tr.Entity
    if not IsDoor(door) then return end

    if ply:GetPos():DistToSqr(door:GetPos()) > (200*200) then return end

    -- allow non-owner players to see info
    local blocked = IsNonOwnable(door)
    if blocked and not ply:IsAdmin() then return end

    local centerWorld = GetDoorCenterWorld(door)
    if not centerWorld then return end

    local scr = centerWorld:ToScreen()
    if not scr.visible then return end

    ----------------------------------------
    -- Door data (visible to all clients)
    ----------------------------------------
    local owner  = GetOwner(door)
    local title  = GetTitle(door)
    local locked = GetLockedState(door)

    local ownerText = GetOwnerName(door) or "Unowned"
    local titleText = (title ~= "" and title) or ""

    ----------------------------------------
    -- Draw clean transparent UI (no bubble)
    ----------------------------------------
    local x = scr.x
    local y = scr.y - 46

    -- transparent background instead of bubble
    --draw.RoundedBox(8, x - 120, y - 12, 240, 90, Color(0, 0, 0, 180))

    -- door label
    draw.SimpleText("Door", "DubzDoor_Title", x, y, ACCENT, TEXT_ALIGN_CENTER)
    y = y + 22

    -- owner
    draw.SimpleText(ownerText, "DubzDoor_Owner", x, y, color_white, TEXT_ALIGN_CENTER)
    y = y + 24

    if titleText ~= "" then
        draw.SimpleText(titleText, "DubzDoor_Owner", x, y, GRAY, TEXT_ALIGN_CENTER)
        y = y + 22
    end

    ----------------------------------------
    -- All players see lock status
    ----------------------------------------
    local lockColor = locked and Color(255,100,100) or Color(120,255,120)
    local lockText  = locked and "Locked" or "Unlocked"

    DrawLockIcon(x - 45, y + 13, 18, locked)
    draw.SimpleText(lockText, "DubzDoor_Lock", x, y + 12, lockColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "Dubz_DoorUI_DrawHUD", DrawDoorHUD)

--------------------------------------------------------
-- F2 menu + popups
--------------------------------------------------------

DoorUI.ActiveFrame = DoorUI.ActiveFrame or nil

local function CloseDoorMenu()
    if IsValid(DoorUI.ActiveFrame) then
        DoorUI.ActiveFrame:Close()
    end
    DoorUI.ActiveFrame = nil
end

local function RunChatCommand(fmt, ...)
    local text = string.Trim(string.format(fmt, ...))
    if text == "" then return end
    RunConsoleCommand("say", text)
end

---------------------------------------------
-- Themed button helper (with hover)
---------------------------------------------
local function AddStackedButton(parent, txt, col, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(34)
    btn:Dock(TOP)
    btn:DockMargin(12, 6, 12, 0)
    btn:SetText("")
    btn._hover = 0

    function btn:Paint(w,h)
        self._hover = Lerp(FrameTime() * 10, self._hover, self:IsHovered() and 1 or 0)
        local bgCol = Color(
            Lerp(self._hover, col.r*0.9, col.r),
            Lerp(self._hover, col.g*0.9, col.g),
            Lerp(self._hover, col.b*0.9, col.b),
            255
        )
        draw.RoundedBox(8, 0, 0, w, h, bgCol)
        draw.SimpleText(txt, FONT_BODY, w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        if onClick then onClick() end
    end

    return btn
end

---------------------------------------------
-- Themed combo popup
---------------------------------------------
local function CreateDubzComboPopup(title, items, onSelect)
    if #items == 0 then
        Notify("No options available for this door.")
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(260, 140)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(true)

    frame.Paint = function(self,w,h)
        DrawBubble(0,0,w,h,Color(0,0,0,220))
        draw.SimpleText(title, FONT_TITLE, 14, 8, ACCENT)
    end

    local combo = vgui.Create("DComboBox", frame)
    combo:SetPos(16, 40)
    combo:SetSize(228, 26)
    combo:SetValue("Select...")

    combo:SetTextColor(color_white)
    combo:SetFont(FONT_BODY)
    combo:SetSortItems(false)

    function combo:Paint(w,h)
        draw.RoundedBox(6, 0, 0, w, h, Color(25,25,25,255))
        draw.SimpleText(self:GetText(), FONT_BODY, 8, h/2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("▼", FONT_BODY, w-16, h/2, Color(160,160,160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    function combo:OpenMenu()
        if self.Menu then
            self.Menu:Remove()
            self.Menu = nil
        end

        self.Menu = DermaMenu(false, self)
        local menu = self.Menu
        menu.Paint = function(pw,ph)
            DrawBubble(0,0,pw,ph,Color(10,10,10,240))
        end

        for _, data in ipairs(items) do
            local opt = menu:AddOption(data.label, function()
                self:SetText(data.label)
                if onSelect then onSelect(data) end
                if IsValid(frame) then frame:Close() end
            end)

            opt:SetTextColor(color_white)
            function opt:Paint(w,h)
                local hov = self:IsHovered()
                local bg = hov and Color(40,120,220,255) or Color(20,20,20,255)
                draw.RoundedBox(0,0,0,w,h,bg)
                draw.SimpleText(self:GetText(), FONT_BODY, 8, h/2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        -- scrollbar styling
        local scroll = menu:GetVBar()
        if IsValid(scroll) then
            function scroll:Paint(w,h)
                draw.RoundedBox(4, w/2-3, 0, 6, h, Color(0,0,0,180))
            end
            function scroll.btnUp:Paint() end
            function scroll.btnDown:Paint() end
            function scroll.btnGrip:Paint(w,h)
                draw.RoundedBox(4, 0, 0, w, h, Color(80,150,220,255))
            end
        end

        local x, y = self:LocalToScreen(0, self:GetTall())
        menu:SetMinimumWidth(self:GetWide())
        menu:Open()
        menu:SetPos(x, y)
    end

    for _, data in ipairs(items) do
        combo:AddChoice(data.label, data)
    end
end

---------------------------------------------
-- Title popup
---------------------------------------------
local function OpenTitlePopup()
    local frame = vgui.Create("DFrame")
    frame:SetSize(280, 130)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()

    frame.Paint = function(self,w,h)
        DrawBubble(0,0,w,h,Color(0,0,0,220))
        draw.SimpleText("Set Door Title", FONT_TITLE, 14, 8, ACCENT)
    end

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(16, 40)
    entry:SetSize(248, 24)
    entry:SetText("")
    entry:SetUpdateOnType(false)

    local btn = vgui.Create("DButton", frame)
    btn:SetPos(16, 74)
    btn:SetSize(248, 26)
    btn:SetText("")
    btn._hover = 0

    btn.Paint = function(self,w,h)
        self._hover = Lerp(FrameTime()*10, self._hover, self:IsHovered() and 1 or 0)
        local col = Color(
            Lerp(self._hover, 50, ACCENT.r),
            Lerp(self._hover, 80, ACCENT.g),
            Lerp(self._hover, 100, ACCENT.b),
            255
        )
        draw.RoundedBox(6,0,0,w,h,col)
        draw.SimpleText("Confirm", FONT_BODY, w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        local txt = string.Trim(entry:GetText() or "")
        if txt == "" then
            Notify("Title cannot be empty.", Color(255,120,120))
            return
        end
        RunChatCommand("/title %s", txt)
        frame:Close()
    end
end

---------------------------------------------
-- Main door menu (F2)
---------------------------------------------
function OpenDoorMenu(ent)
    CloseDoorMenu()

    if not IsDoor(ent) then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local blocked = IsNonOwnable(ent)
    local isOwner = IsOwnedByLocal(ent)
    local isAdmin = ply:IsAdmin()

    if blocked and not isAdmin then
        Notify("This door cannot be owned.")
        return
    end

    local title = GetTitle(ent)
    local owner = GetOwner(ent)

    local frame = vgui.Create("DFrame")
    DoorUI.ActiveFrame = frame
    frame:SetSize(260, 330)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(true)

    frame.Paint = function(self, w, h)
        DrawBubble(0,0,w,h,Color(0,0,0,180))
        draw.SimpleText("Door", FONT_TITLE, 14, 8, ACCENT)
        local ownerName = GetOwnerName(ent)
        draw.SimpleText(ownerName and ("Owner: " .. ownerName) or "Unowned",
                        FONT_BODY, 14, 34, GRAY)
    end

    local container = vgui.Create("Panel", frame)
    container:SetPos(0, 64)
    container:SetSize(frame:GetWide(), frame:GetTall() - 64)

    -- Buy/Sell
    if not blocked then
        local buyTxt = isOwner and "Sell Door" or "Buy Door"
        AddStackedButton(container, buyTxt, Color(75,80,70), function()
            RunChatCommand("/toggleown")
            frame:Close()
        end)
    end

    -- Title
    AddStackedButton(container, "Set Title", ACCENT, function()
        OpenTitlePopup()
        frame:Close()
    end)

    -- Door group (admin only, or owner? we'll keep it admin like DarkRP)
    AddStackedButton(container, "Set Door Group", Color(90,90,170), function()
        local groups = {}
        for _, name in ipairs(GetDoorGroups()) do
            table.insert(groups, {label = name, value = name})
        end

        CreateDubzComboPopup("Set Door Group", groups, function(data)
            RunChatCommand("/togglegroup %s", data.value)
        end)

        frame:Close()
    end)

    -- Add co-owner
    AddStackedButton(container, "Add Co-owner", Color(80,160,200), function()
        if not IsOwned(ent) then
            Notify("You must own this door first.", Color(255,140,140))
            return
        end
        if not isOwner and not isAdmin then
            Notify("Only the owner can add co-owners.", Color(255,140,140))
            return
        end

        local players = {}
        for _, ply2 in ipairs(GetPotentialCoOwners(ent)) do
            table.insert(players, {label = ply2:Nick(), value = ply2})
        end

        CreateDubzComboPopup("Add Co-owner", players, function(data)
            if IsValid(data.value) then
                RunChatCommand("/addowner %s", data.value:Nick())
            end
        end)

        frame:Close()
    end)

    -- Remove co-owner
    AddStackedButton(container, "Remove Co-owner", Color(220,150,90), function()
        if not IsOwned(ent) then
            Notify("This door has no owner.", Color(255,140,140))
            return
        end
        if not isOwner and not isAdmin then
            Notify("Only the owner can remove co-owners.", Color(255,140,140))
            return
        end

        local players = {}
        for _, ply2 in ipairs(GetRemovableCoOwners(ent)) do
            table.insert(players, {label = ply2:Nick(), value = ply2})
        end

        CreateDubzComboPopup("Remove Co-owner", players, function(data)
            if IsValid(data.value) then
                RunChatCommand("/removeowner %s", data.value:Nick())
            end
        end)

        frame:Close()
    end)

    -- Admin: toggle ownable
    if isAdmin then
        local label = blocked and "Enable Buying" or "Disable Buying"
        AddStackedButton(container, label, Color(220,80,80), function()
            RunChatCommand("/toggleownable")
            frame:Close()
        end)
    end
end

--------------------------------------------------------
-- Hook F2 (ShowTeam) to open our door menu
--------------------------------------------------------

hook.Add("ShowTeam", "Dubz_DoorUI_ShowTeam", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsDoor(ent) then
        -- let gamemode handle non-door F2
        return
    end

    OpenDoorMenu(ent)
    return true -- block default DarkRP door menu
end)

--------------------------------------------------------
-- Close menu on death / context menu
--------------------------------------------------------

hook.Add("PlayerDeath", "Dubz_DoorUI_CloseOnDeath", function(ply)
    if ply ~= LocalPlayer() then return end
    CloseDoorMenu()
end)

hook.Add("OnContextMenuOpen", "Dubz_DoorUI_CloseOnContext", function()
    CloseDoorMenu()
end)
