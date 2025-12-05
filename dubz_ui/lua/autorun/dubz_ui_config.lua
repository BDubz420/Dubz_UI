Dubz = Dubz or {}
Dubz.Config = Dubz.Config or {}
Dubz.Colors = Dubz.Colors or {}
Dubz.Themes = Dubz.Themes or {}

Dubz.Config.Version = "v0.6.7"

-- Theme / Accent
Dubz.Colors.Accent = Color(37,150,190)
Dubz.Colors.Background = Color(0,0,0,160)

Dubz.Config.Theme = "transparent_black"
Dubz.Config.UseThemeAccent = true
Dubz.Config.AccentRainbow = false
Dubz.Config.RainbowSpeed = 0.2

-- Dev & Logging
Dubz.Config.DevMode = false
Dubz.Config.SaveLogsToFile = true
Dubz.Config.MaxLogs = 800

-- Admin / Logs
Dubz.Config.Admin = {
    ChatCommand = {
        Enabled = true,
        Triggers = { "!dubzlogs", "/dubzlogs", "!logs" },
        Permissions = { "admin", "superadmin" }
    }
}

-- Keys / Menu
Dubz.Config.Keys = { OpenMenu = KEY_TAB }
Dubz.Config.Menu = {
    Enabled = true,
    CornerRadius = 12,
    SidebarWidth = 280,
    Background = Color(0,0,0,180),
    AnimationSpeed = 10,
    DimBackground = true,
    Tabs = {
        { id = "dashboard", label = "Dashboard", icon = "dashboard" },
        { id = "players",   label = "Players",   icon = "players" },
        { id = "jobs",      label = "Jobs",      icon = "jobs" },
        { id = "market",    label = "Market",    icon = "market" },
        { id = "gangs",    label = "Gangs",    icon = "market" }
    }
}
Dubz.Config.DiscordInvite = "https://discord.gg/wMNqh7RBAd"

-- HUD
Dubz.Config.HUD = {
    Enabled = true,
    Width = 420,
    Height = 148,
    CornerRadius = 12,
    Padding = 12,
    AccentBarWidth = 6,
    Margin = 20,
    SmoothSpeed = 8.0,
    MoneyFontScale = 1.3,
    Hints = {
        Enabled = true,
        Layout = "horizontal",
        Opacity = 220,
        KeyWidth = 26,
        KeyHeight = 18,
        KeyCorner = 5,
        TextSpacing = 8,
        Spacing = 32,
        Position = { x = 12, y = -4 },
        Keys = {
            { key = "Tab", action = "Menu" },
            { key = "Y",  action = "Chat" },
            { key = "F4", action = "Market" },
            { key = "Z",  action = "Undo" }
        }
    },
    Hunger = {
        Enabled = true,
        Label = "Hunger",
        Color = Color(80,200,120,200),
        Background = Color(0,0,0,80),
        OffsetY = 6,
        Smooth = true,
        EnableStarvingWarning = true,
        StarvingThreshold = 15,
        StarvingText = "STARVING!",
        StarvingColor = Color(220,50,50),
        PulseSpeed = 3,
        PlayWarningSound = false
    },
    Payday = {
        Enabled = true,
        Height = 20,
        Width = 220,
        Padding = 6,
        Sound = "buttons/button5.wav",
        AnimateWalletTime = 0.6
    }
}

-- Overhead
Dubz.Config.Overhead = {
    Enabled = true,
    MaxDistance = 900,
    Scale = 0.15,
    HeightOffset = 10
}

-- Dashboard
Dubz.Config.Dashboard = {
    UpdateRate = 0.5,
    TopRichestCount = 5,
    Charts = {
        ShowEconomyPie = true,
        ShowPlayerCount = true
    }
}

-- Gangs
Dubz.Config.Gangs = {
    -- Core toggles / naming
    Enabled = true,                   -- master enable for the entire gang system
    TabTitle = "Gangs",              -- label used in the tab menu

    -- Membership + creation
    MaxMembers = 12,                 -- max members per gang
    StartCost = 50000,               -- cost to create a gang
    NameMaxLength = 24,              -- max characters for gang name
    DescMaxLength = 160,             -- max characters for gang description
    RankTitleMaxLength = 20,         -- max characters for custom rank titles

    -- Invites
    InviteExpire = 120,              -- seconds before an invite expires
    AllowOfficerInvite = false,      -- if true, Officers+ can invite; otherwise only Leader

    -- Bank / economy
    BankEnabled = true,              -- enable the shared gang bank
    AllowDeposit = true,             -- if false, bank is read-only
    MinBankWithdrawRank = "Leader",  -- minimum rank allowed to withdraw ("Member","Officer","Leader")

    -- Wars
    Wars = {
        Enabled = true,
        DeclareCost = 10000,         -- cost to declare war
        TributePercent = 0.10,       -- % of losing gang's bank paid to winner
        Duration = 1800,             -- war length in seconds
        MinMembers = 1               -- minimum online members required to declare war
    },

    -- Dashboard integration
    ShowOnDashboard = true,          -- show the richest gangs widget on dashboard
    DashboardTopCount = 5            -- how many gangs to show in the dashboard list
}

-- Players Tab (menu scoreboard replacement)
Dubz.Config.PlayersTab = {
    Enabled = true,
    InfoPanelHeight = 120,
    Spacing = 4,
    AdminButtons = {
        goto = true,
        bring = true,
        spectate = true,
        kick = true,
        freeze = true,
        unfreeze = true
    }
}

-- Details Popup (used in jobs/entities for model/info windows)
Dubz.Config.Details = {
    FrameW = 540,
    FrameH = 420,
    AllowClose = true
}

-- Market (Entities, Shipments, Ammo)
Dubz.Config.Market = {
    ShowEntities = true,
    ShowShipments = true,
    ShowAmmo = true
}

-- Jobs
Dubz.Config.Jobs = {
    Show = true
}

Dubz.Config.Territories = {
    Enabled = true,

    -- Entity / placement
    EntityClass = "ent_dubz_graffiti_spot",
    Model = "models/props_docks/dock03_pole01a_256.mdl",
    CaptureRadius = 250,         -- how far from the pole to count players
    CaptureTime = 20,            -- seconds of uncontested presence to capture
    DecayTime = 15,              -- time to lose progress when nobody is near
    ThinkInterval = 0.25,        -- capture logic tick rate
    NeutralColor = Color(140,140,140),

    -- Income settings
    Income = {
        Enabled = true,
        Interval = 60,           -- seconds between payouts per pole
        TotalPerTick = 500,      -- total money generated per tick

        GangBankShare = 0.8,     -- 80% of TotalPerTick -> gang bank
        MemberShare = 0.2,       -- 20% -> online members of that gang

        GiveOnlineMembers = true, -- if false, 100% goes to gang bank
        RequireOwnerOnline = false -- if true, no income if no member of gang is online
    },

    -- “claimed by” players tracking
    ClaimTracking = {
        Enabled = true,          -- if false, we don’t show individual claimers
        MaxClaimers = 3,         -- how many names to keep per capture
        ShowNames3D2D = true     -- show on the pole’s floating UI
    },

    -- Toolgun settings
    Tool = {
        Enabled = true,
        AdminOnly = true,        -- only admins can place/remove poles
        Category = "Dubz UI",
        Name = "Gang Territory Pole"
    }
}

Dubz.Config.GraffitiFonts = {
    { id = "StreetBold", file = "streetwars.ttf" },
    { id = "SpraySharp", file = "spraysharp.ttf" },
    { id = "UrbanTag",   file = "urbantag.ttf" }
}