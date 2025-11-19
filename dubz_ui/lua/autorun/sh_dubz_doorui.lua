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
    -- sends: door, owner, title, locked, nonownable


    ------------------------------------------------------------
    -- HELPERS
    ------------------------------------------------------------
    local function SendDoorState(door)
        if not IsValid(door) then return end

        net.Start("Dubz_DoorUI_DoorUpdated")
            net.WriteEntity(door)
            net.WriteEntity(door:getDoorOwner() or NULL)
            net.WriteString(door:getKeysTitle() or "")

            -- FIXED: proper DarkRP lock sync
            local locked = false
            if door.getKeysLocked then
                locked = door:getKeysLocked()
            end
            net.WriteBool(locked)

            -- Send non-ownable flag to client
            local nonown = false
            if door.getKeysNonOwnable then
                nonown = door:getKeysNonOwnable()
            end
            net.WriteBool(nonown)

        net.Broadcast()
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

end



----------------------------------------------------------------
-- CLIENT LOAD
----------------------------------------------------------------
if CLIENT then
    include("dubz_doorui/cl_dubz_doorui.lua")
end
