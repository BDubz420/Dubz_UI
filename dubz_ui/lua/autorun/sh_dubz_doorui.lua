-- sh_dubz_doorui.lua
-- Main loader for Dubz Door UI System

if SERVER then
    AddCSLuaFile("dubz_doorui/cl_dubz_doorui.lua")

    ------------------------------------------------------------
    -- NETWORK STRINGS
    ------------------------------------------------------------
    util.AddNetworkString("Dubz_DoorUI_RequestGroups")
    util.AddNetworkString("Dubz_DoorUI_SendGroups")
    util.AddNetworkString("Dubz_DoorUI_SetGroup")

    util.AddNetworkString("Dubz_DoorUI_DoorUpdated")
    -- sends: door, owner entity, owner sid64, owner name, title, locked, nonownable


    ------------------------------------------------------------
    -- HELPERS
    ------------------------------------------------------------
    local function IsDoor(ent)
        if not IsValid(ent) then return false end
        if ent.isDoor then
            local ok, res = pcall(function() return ent:isDoor() end)
            if ok and res then return true end
        end

        local class = string.lower(ent:GetClass() or "")
        return class:find("door", 1, true) ~= nil
            or class:find("prop_door", 1, true) ~= nil
            or class:find("func_door", 1, true) ~= nil
    end

    local function SendDoorState(arg1, arg2)
        local door = arg1
        local target = arg2

        if not IsDoor(arg1) then
            if IsDoor(arg2) then
                door = arg2
                target = nil
            else
                return
            end
        end

        if not IsValid(door) then return end

        local owner = (door.getDoorOwner and door:getDoorOwner()) or NULL
        if not IsValid(owner) or not owner:IsPlayer() then
            owner = NULL
        end

        local ownerSid = IsValid(owner) and owner:SteamID64() or ""
        local ownerName = IsValid(owner) and owner:Nick() or ""

        local title = (door.getKeysTitle and door:getKeysTitle()) or ""

        local locked = false
        if door.getKeysLocked then
            locked = door:getKeysLocked()
        end

        local nonown = false
        if door.getKeysNonOwnable then
            nonown = door:getKeysNonOwnable()
        end

        net.Start("Dubz_DoorUI_DoorUpdated")
            net.WriteEntity(door)
            net.WriteEntity(owner)
            net.WriteString(ownerSid or "")
            net.WriteString(ownerName or "")
            net.WriteString(title)
            net.WriteBool(locked)
            net.WriteBool(nonown)

        if IsValid(target) and target:IsPlayer() then
            net.Send(target)
        else
            net.Broadcast()
        end
    end

    local function SendAllDoorStates(ply)
        if not IsValid(ply) then return end
        for _, ent in ipairs(ents.GetAll()) do
            if IsDoor(ent) then
                SendDoorState(ent, ply)
            end
        end
    end


    ------------------------------------------------------------
    -- CLIENT REQUESTS DOOR GROUPS
    ------------------------------------------------------------
    net.Receive("Dubz_DoorUI_RequestGroups", function(_, ply)
        if not IsValid(ply) or not ply:IsAdmin() then return end

        local groups = DarkRP.getDoorGroups()

        net.Start("Dubz_DoorUI_SendGroups")
            net.WriteUInt(table.Count(groups), 12)

            for name,_ in pairs(groups) do
                net.WriteString(name)
            end
        net.Send(ply)
    end)


    ------------------------------------------------------------
    -- ADMIN SETS DOOR GROUP
    ------------------------------------------------------------
    net.Receive("Dubz_DoorUI_SetGroup", function(_, ply)
        if not IsValid(ply) or not ply:IsAdmin() then return end

        local door  = net.ReadEntity()
        local group = net.ReadString()

        if not IsValid(door) or not door:isKeysOwnable() then return end

        if group == "" then
            door:removeKeysDoorGroup()
            DarkRP.notify(ply, 1, 4, "Removed door group.")
        else
            door:setKeysDoorGroup(group)
            DarkRP.notify(ply, 0, 4, "Door group set to: " .. group)
        end

        SendDoorState(door)
    end)


    ------------------------------------------------------------
    -- DARKRP HOOKS → FULL DOOR SYNC
    ------------------------------------------------------------
    hook.Add("onKeysLocked",          "DubzDoorUI_Sync", SendDoorState)
    hook.Add("onKeysUnlocked",        "DubzDoorUI_Sync", SendDoorState)
    hook.Add("onDoorSold",            "DubzDoorUI_Sync", SendDoorState)
    hook.Add("onDoorBought",          "DubzDoorUI_Sync", SendDoorState)
    hook.Add("onKeysTitleChanged",    "DubzDoorUI_Sync", SendDoorState)
    hook.Add("onKeysNonOwnableValueChanged", "DubzDoorUI_Sync", SendDoorState)

    hook.Add("PlayerInitialSpawn", "DubzDoorUI_InitSync", function(ply)
        timer.Simple(2, function()
            SendAllDoorStates(ply)
        end)
    end)

end



----------------------------------------------------------------
-- CLIENT LOAD
----------------------------------------------------------------
if CLIENT then
    include("dubz_doorui/cl_dubz_doorui.lua")
end
