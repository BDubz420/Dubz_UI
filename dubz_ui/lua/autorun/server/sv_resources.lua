-- Ensure all graffiti fonts are sent to clients
local function Dubz_AddGraffitiFonts()
    if not Dubz or not Dubz.Config or not Dubz.Config.GraffitiFonts then return end

    for _, f in ipairs(Dubz.Config.GraffitiFonts) do
        local path = "resource/fonts/" .. f.file

        if file.Exists(path, "GAME") then
            resource.AddSingleFile(path)
        end
    end
end

hook.Add("Initialize", "Dubz_AddGraffitiFonts", Dubz_AddGraffitiFonts)
hook.Add("PostGamemodeLoaded", "Dubz_AddGraffitiFonts", Dubz_AddGraffitiFonts)
hook.Add("OnReloaded", "Dubz_AddGraffitiFonts", Dubz_AddGraffitiFonts)