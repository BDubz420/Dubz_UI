Dubz = Dubz or {}
Dubz.Themes = Dubz.Themes or {}
Dubz.Colors = Dubz.Colors or {}

local THEME_DIR = "dubz_ui/themes"

local function safeIncludeTheme(path)
    local ok, err = pcall(include, path)
    if not ok then
        MsgC(Color(255, 80, 80), "[DubzUI] Failed to include theme '" .. path .. "': " .. tostring(err) .. "\n")
    end
end

local files = {}
if file and file.Find then
    local found = file.Find(THEME_DIR .. "/*.lua", "LUA") or {}
    for _, fname in ipairs(found) do table.insert(files, fname) end
else
    -- fallback when file library is unavailable (e.g. menu state)
    files = {"transparent_black.lua"}
end

table.sort(files, function(a,b) return a < b end)

for _, fname in ipairs(files) do
    safeIncludeTheme(string.format("%s/%s", THEME_DIR, fname))
end

if table.Count(Dubz.Themes) == 0 then
    Dubz.Themes["transparent_black"] = {
        Accent = Color(37,150,190),
        Background = Color(0,0,0,140),
        Text = Color(255,255,255,230),
        Line = Color(37,150,190,90),
        Panel = Color(10,10,10,160),
        Hover = Color(37,150,190,40),
        Glow = true
    }
end

local function applyTheme(name)
    if not name or name == "" then return false end
    local theme = Dubz.Themes[name]
    if not theme then return false end

    Dubz.ActiveTheme = name
    Dubz.ActiveThemeData = theme

    local colors = Dubz.Colors or {}
    colors.Background = theme.Background or colors.Background or Color(0,0,0,160)
    colors.Panel = theme.Panel or colors.Panel or colors.Background
    colors.Text = theme.Text or colors.Text or Color(255,255,255)
    colors.Line = theme.Line or colors.Line
    colors.Hover = theme.Hover or colors.Hover or Color(255,255,255,40)
    colors.Glow = theme.Glow

    if not Dubz.Config or Dubz.Config.UseThemeAccent ~= false then
        colors.Accent = theme.Accent or colors.Accent or Color(37,150,190)
    else
        colors.Accent = colors.Accent or Color(37,150,190)
    end

    Dubz.Colors = colors

    if hook and hook.Run then
        hook.Run("DubzThemeChanged", name, theme)
    end

    return true
end

function Dubz.GetTheme(name)
    if not name or name == "" then
        return Dubz.ActiveThemeData
    end
    return Dubz.Themes[name]
end

function Dubz.SetTheme(name)
    if applyTheme(name) then
        if Dubz.Log then
            Dubz.Log("Applied theme '" .. tostring(name) .. "'", "INFO")
        end
        return true
    end

    if Dubz.Log then
        Dubz.Log("Theme '" .. tostring(name) .. "' is not registered", "WARN")
    end

    return false
end

function Dubz.GetAvailableThemes()
    local list = {}
    for k in pairs(Dubz.Themes) do table.insert(list, k) end
    table.sort(list, function(a,b) return a < b end)
    return list
end

local desiredTheme = (Dubz.Config and Dubz.Config.Theme) or "transparent_black"
if not applyTheme(desiredTheme) then
    local names = Dubz.GetAvailableThemes()
    if #names > 0 then
        if Dubz.Log then
            Dubz.Log("Theme '" .. tostring(desiredTheme) .. "' missing, falling back to '" .. names[1] .. "'", "WARN")
        end
        applyTheme(names[1])
    end
end
