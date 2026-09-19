--[[
    Vectra Hub - The Strongest Battlegrounds
    Game ID: 10449761463
]]

local TARGET_GAME_ID = 10449761463
if game.PlaceId ~= TARGET_GAME_ID and game.GameId ~= TARGET_GAME_ID then
    warn("[vectra] This script only runs on The Strongest Battlegrounds (ID: " .. tostring(TARGET_GAME_ID) .. ")")
    return
end

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/iwasswattedat12/library/refs/heads/main/vectra-library.luau?v=" .. tostring(tick())))()

local Window = Library:CreateWindow({
    Title = "vectra | The Strongest Battlegrounds",
    Size = UDim2.fromOffset(720, 440),
    ToggleKey = Enum.KeyCode.RightShift,
    Discord = "https://discord.gg/CFqYwQwSnh"
})

----------------------------------------------------------------------
-- STATE VARIABLES
----------------------------------------------------------------------
-- Combat
local AutoM1Enabled = false
local AutoM1Delay = 0.25
local FaceTargetEnabled = false
local TargetPlayerName = "None"
local SpectatingTarget = false

-- Movement
local WalkSpeedEnabled = false
local CustomWalkSpeed = 16
local JumpPowerEnabled = false
local CustomJumpPower = 50
local InfiniteJumpEnabled = false
local NoClipEnabled = false
local FlyEnabled = false
local FlySpeed = 50
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyConnection = nil
local noclipConnection = nil

-- Visuals / ESP
local PlayerEspEnabled = false
local PlayerEspHighlight = true
local PlayerEspDistance = true
local PlayerEspHealth = true
local MaxEspDistance = 1000
local ActivePlayerEsp = {}

-- Misc
local AntiAfkEnabled = true

local UI_Elements = {}

----------------------------------------------------------------------
-- CORE HELPERS
----------------------------------------------------------------------
local function getRootPart()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function getHumanoid()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("Humanoid", 5)
end

local function getPlayerList()
    local list = { "None" }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, plr.Name)
        end
    end
    return list
end

----------------------------------------------------------------------
-- COMBAT ROUTINES
----------------------------------------------------------------------
-- Auto M1 Attack
task.spawn(function()
    while true do
        if AutoM1Enabled then
            pcall(function()
                if mouse1click then
                    mouse1click()
                else
                    VirtualUser:CaptureController()
                    VirtualUser:Button1Down(Vector2.new(0, 0))
                    task.wait(0.04)
                    VirtualUser:Button1Up(Vector2.new(0, 0))
                end
            end)
            task.wait(math.max(AutoM1Delay, 0.05))
        else
            task.wait(0.2)
        end
    end
end)

-- Face Target / Nearest Opponent
RunService.Heartbeat:Connect(function()
    if not FaceTargetEnabled then return end

    local myHrp = getRootPart()
    if not myHrp then return end

    local targetChar = nil
    if TargetPlayerName and TargetPlayerName ~= "None" then
        local targetPlr = Players:FindFirstChild(TargetPlayerName)
        if targetPlr and targetPlr.Character then
            targetChar = targetPlr.Character
        end
    else
        -- Find nearest opponent
        local minDist = 80
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                local hum = plr.Character:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local dist = (hrp.Position - myHrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        targetChar = plr.Character
                    end
                end
            end
        end
    end

    if targetChar then
        local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
        if targetHrp then
            local currentPos = myHrp.Position
            local targetPos = Vector3.new(targetHrp.Position.X, currentPos.Y, targetHrp.Position.Z)
            myHrp.CFrame = CFrame.lookAt(currentPos, targetPos)
        end
    end
end)

local function teleportToPlayer(plrName, behind)
    local targetPlr = Players:FindFirstChild(plrName)
    if not targetPlr or not targetPlr.Character then
        Library:Notify({
            Title = "Targeting",
            Content = "Target player or character not found!",
            Duration = 2.5
        })
        return
    end

    local targetHrp = targetPlr.Character:FindFirstChild("HumanoidRootPart")
    local myHrp = getRootPart()
    if targetHrp and myHrp then
        if behind then
            myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3.5)
        else
            myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -3.5) * CFrame.Angles(0, math.pi, 0)
        end
        Library:Notify({
            Title = "Targeting",
            Content = (behind and "Teleported behind " or "Teleported in front of ") .. targetPlr.DisplayName,
            Duration = 2
        })
    end
end

----------------------------------------------------------------------
-- MOVEMENT SYSTEMS
----------------------------------------------------------------------
-- WalkSpeed & JumpPower loops
RunService.Heartbeat:Connect(function()
    local hum = getHumanoid()
    if not hum then return end

    if WalkSpeedEnabled then
        hum.WalkSpeed = CustomWalkSpeed
    end
    if JumpPowerEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = CustomJumpPower
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if InfiniteJumpEnabled then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- NoClip
local function setNoclip(enabled)
    if enabled then
        if noclipConnection then noclipConnection:Disconnect() end
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

-- Flight
local function startFly()
    local hrp = getRootPart()
    if not hrp then return end

    if flyBodyVelocity then flyBodyVelocity:Destroy() end
    if flyBodyGyro then flyBodyGyro:Destroy() end

    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBodyVelocity.Velocity = Vector3.zero
    flyBodyVelocity.Parent = hrp

    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBodyGyro.P = 1e4
    flyBodyGyro.CFrame = hrp.CFrame
    flyBodyGyro.Parent = hrp

    flyConnection = RunService.RenderStepped:Connect(function()
        if not FlyEnabled or not hrp or not flyBodyVelocity or not flyBodyGyro then return end

        local moveDir = Vector3.zero
        local camCF = Camera.CFrame

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + camCF.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - camCF.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - camCF.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + camCF.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end

        if moveDir.Magnitude > 0 then
            flyBodyVelocity.Velocity = moveDir.Unit * FlySpeed
        else
            flyBodyVelocity.Velocity = Vector3.zero
        end

        flyBodyGyro.CFrame = camCF
    end)
end

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
end

----------------------------------------------------------------------
-- PLAYER ESP
----------------------------------------------------------------------
local function removePlayerEsp(player)
    if ActivePlayerEsp[player] then
        pcall(function()
            if ActivePlayerEsp[player].Billboard then
                ActivePlayerEsp[player].Billboard:Destroy()
            end
            if ActivePlayerEsp[player].Highlight then
                ActivePlayerEsp[player].Highlight:Destroy()
            end
        end)
        ActivePlayerEsp[player] = nil
    end
end

local function createPlayerEsp(player)
    if player == LocalPlayer or ActivePlayerEsp[player] then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "Vectra_PlayerEsp"
    bb.Adornee = hrp
    bb.Size = UDim2.new(0, 160, 0, 48)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.ClipsDescendants = false

    local TagFrame = Instance.new("Frame")
    TagFrame.Name = "TagFrame"
    TagFrame.Size = UDim2.new(1, 0, 1, 0)
    TagFrame.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
    TagFrame.BackgroundTransparency = 0.2
    TagFrame.BorderSizePixel = 0
    TagFrame.Parent = bb

    local TagCorner = Instance.new("UICorner")
    TagCorner.CornerRadius = UDim.new(0, 6)
    TagCorner.Parent = TagFrame

    local TagStroke = Instance.new("UIStroke")
    TagStroke.Color = Library.Theme.Accent
    TagStroke.Thickness = 1.2
    TagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    TagStroke.Parent = TagFrame

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Name = "NameLabel"
    NameLabel.Size = UDim2.new(1, -8, 0, 16)
    NameLabel.Position = UDim2.new(0, 4, 0, 4)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
    NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameLabel.TextSize = 11
    NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    NameLabel.Parent = TagFrame

    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Name = "InfoLabel"
    InfoLabel.Size = UDim2.new(1, -8, 0, 14)
    InfoLabel.Position = UDim2.new(0, 4, 0, 20)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Font = Enum.Font.GothamMedium
    InfoLabel.Text = string.format("HP: %d/%d | 0 studs", math.floor(hum.Health), math.floor(hum.MaxHealth))
    InfoLabel.TextColor3 = Library.Theme.TextMuted
    InfoLabel.TextSize = 10
    InfoLabel.Parent = TagFrame

    local BarBg = Instance.new("Frame")
    BarBg.Name = "BarBg"
    BarBg.Size = UDim2.new(1, -12, 0, 3)
    BarBg.Position = UDim2.new(0, 6, 1, -6)
    BarBg.BackgroundColor3 = Color3.fromRGB(35, 37, 48)
    BarBg.BorderSizePixel = 0
    BarBg.Parent = TagFrame

    local BarBgCorner = Instance.new("UICorner")
    BarBgCorner.CornerRadius = UDim.new(1, 0)
    BarBgCorner.Parent = BarBg

    local BarFill = Instance.new("Frame")
    BarFill.Name = "BarFill"
    local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    BarFill.Size = UDim2.new(hpRatio, 0, 1, 0)
    BarFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    BarFill.BorderSizePixel = 0
    BarFill.Parent = BarBg

    local BarFillCorner = Instance.new("UICorner")
    BarFillCorner.CornerRadius = UDim.new(1, 0)
    BarFillCorner.Parent = BarFill

    local hl = nil
    if PlayerEspHighlight then
        hl = Instance.new("Highlight")
        hl.Name = "Vectra_Highlight"
        hl.Adornee = char
        hl.FillColor = Library.Theme.Accent
        hl.FillTransparency = 0.65
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0.2
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
    end

    pcall(function()
        bb.Parent = gethui and gethui() or LocalPlayer:WaitForChild("PlayerGui")
    end)

    ActivePlayerEsp[player] = {
        Billboard = bb,
        Highlight = hl,
        InfoLabel = InfoLabel,
        BarFill = BarFill,
        TagFrame = TagFrame,
        TagStroke = TagStroke
    }
end

-- Periodic update for Player ESP
task.spawn(function()
    while true do
        if PlayerEspEnabled then
            local myHrp = getRootPart()
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local data = ActivePlayerEsp[player]
                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
                        local hrp = char.HumanoidRootPart
                        local hum = char.Humanoid

                        local dist = myHrp and math.floor((hrp.Position - myHrp.Position).Magnitude) or 0
                        if dist <= MaxEspDistance and hum.Health > 0 then
                            if not data then
                                createPlayerEsp(player)
                                data = ActivePlayerEsp[player]
                            end

                            if data and data.InfoLabel then
                                local infoText = ""
                                if PlayerEspHealth then
                                    infoText = string.format("HP: %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
                                end
                                if PlayerEspDistance then
                                    infoText = infoText ~= "" and (infoText .. " | " .. tostring(dist) .. "s") or (tostring(dist) .. "s")
                                end
                                data.InfoLabel.Text = infoText

                                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                                if data.BarFill then
                                    data.BarFill.Size = UDim2.new(ratio, 0, 1, 0)
                                    if ratio > 0.5 then
                                        data.BarFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                                    elseif ratio > 0.25 then
                                        data.BarFill.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
                                    else
                                        data.BarFill.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
                                    end
                                end

                                if data.Highlight then
                                    data.Highlight.Enabled = PlayerEspHighlight
                                end
                            end
                        else
                            if data then
                                removePlayerEsp(player)
                            end
                        end
                    else
                        if data then
                            removePlayerEsp(player)
                        end
                    end
                end
            end
        else
            for player, _ in pairs(ActivePlayerEsp) do
                removePlayerEsp(player)
            end
        end
        task.wait(0.2)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removePlayerEsp(player)
end)

----------------------------------------------------------------------
-- ANTI-AFK
----------------------------------------------------------------------
pcall(function()
    LocalPlayer.Idled:Connect(function()
        if AntiAfkEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end
    end)
end)

----------------------------------------------------------------------
-- CONFIG SYSTEM
----------------------------------------------------------------------
local ConfigFolder = "VectraConfigs_TSB"
local CurrentConfigName = "default"

local function ensureConfigFolder()
    pcall(function()
        if makefolder and not isfolder(ConfigFolder) then
            makefolder(ConfigFolder)
        end
    end)
end
ensureConfigFolder()

local function saveConfig(name)
    name = (name and name ~= "") and name or CurrentConfigName
    local data = {
        Timestamp = os.time(),
        AutoM1Enabled = AutoM1Enabled,
        AutoM1Delay = AutoM1Delay,
        FaceTargetEnabled = FaceTargetEnabled,
        WalkSpeedEnabled = WalkSpeedEnabled,
        CustomWalkSpeed = CustomWalkSpeed,
        JumpPowerEnabled = JumpPowerEnabled,
        CustomJumpPower = CustomJumpPower,
        InfiniteJumpEnabled = InfiniteJumpEnabled,
        NoClipEnabled = NoClipEnabled,
        FlyEnabled = FlyEnabled,
        FlySpeed = FlySpeed,
        PlayerEspEnabled = PlayerEspEnabled,
        PlayerEspHighlight = PlayerEspHighlight,
        PlayerEspDistance = PlayerEspDistance,
        PlayerEspHealth = PlayerEspHealth,
        MaxEspDistance = MaxEspDistance,
        AntiAfkEnabled = AntiAfkEnabled
    }

    local encoded = HttpService:JSONEncode(data)
    pcall(function()
        if writefile then
            ensureConfigFolder()
            writefile(ConfigFolder .. "/" .. name .. ".json", encoded)
            Library:Notify({ Title = "Config", Content = "Saved config: " .. name, Duration = 2.5 })
        end
    end)
end

local function loadConfig(name)
    name = (name and name ~= "") and name or CurrentConfigName
    local path = ConfigFolder .. "/" .. name .. ".json"
    local raw = nil
    pcall(function()
        if readfile and isfile and isfile(path) then
            raw = readfile(path)
        end
    end)

    if not raw then
        Library:Notify({ Title = "Config", Content = "Config not found: " .. name, Duration = 2.5 })
        return
    end

    local data = nil
    pcall(function() data = HttpService:JSONDecode(raw) end)
    if not data then return end

    if data.AutoM1Enabled ~= nil and UI_Elements.AutoM1Toggle then UI_Elements.AutoM1Toggle:Set(data.AutoM1Enabled) end
    if data.AutoM1Delay and UI_Elements.AutoM1DelaySlider then UI_Elements.AutoM1DelaySlider:Set(data.AutoM1Delay) end
    if data.FaceTargetEnabled ~= nil and UI_Elements.FaceTargetToggle then UI_Elements.FaceTargetToggle:Set(data.FaceTargetEnabled) end
    if data.WalkSpeedEnabled ~= nil and UI_Elements.WalkSpeedToggle then UI_Elements.WalkSpeedToggle:Set(data.WalkSpeedEnabled) end
    if data.CustomWalkSpeed and UI_Elements.WalkSpeedSlider then UI_Elements.WalkSpeedSlider:Set(data.CustomWalkSpeed) end
    if data.JumpPowerEnabled ~= nil and UI_Elements.JumpPowerToggle then UI_Elements.JumpPowerToggle:Set(data.JumpPowerEnabled) end
    if data.CustomJumpPower and UI_Elements.JumpPowerSlider then UI_Elements.JumpPowerSlider:Set(data.CustomJumpPower) end
    if data.InfiniteJumpEnabled ~= nil and UI_Elements.InfJumpToggle then UI_Elements.InfJumpToggle:Set(data.InfiniteJumpEnabled) end
    if data.NoClipEnabled ~= nil and UI_Elements.NoClipToggle then UI_Elements.NoClipToggle:Set(data.NoClipEnabled) end
    if data.FlyEnabled ~= nil and UI_Elements.FlyToggle then UI_Elements.FlyToggle:Set(data.FlyEnabled) end
    if data.FlySpeed and UI_Elements.FlySpeedSlider then UI_Elements.FlySpeedSlider:Set(data.FlySpeed) end
    if data.PlayerEspEnabled ~= nil and UI_Elements.PlayerEspToggle then UI_Elements.PlayerEspToggle:Set(data.PlayerEspEnabled) end
    if data.PlayerEspHighlight ~= nil and UI_Elements.PlayerEspHighlightToggle then UI_Elements.PlayerEspHighlightToggle:Set(data.PlayerEspHighlight) end
    if data.MaxEspDistance and UI_Elements.MaxEspDistanceSlider then UI_Elements.MaxEspDistanceSlider:Set(data.MaxEspDistance) end

    Library:Notify({ Title = "Config", Content = "Loaded config: " .. name, Duration = 2.5 })
end

----------------------------------------------------------------------
-- UI TABS & SECTIONS
----------------------------------------------------------------------
-- Combat Tab
local CombatTab = Window:CreateTab("Combat")

local CombatSection = CombatTab:CreateSection("Combat Assist", "Left")

UI_Elements.AutoM1Toggle = CombatSection:CreateToggle({
    Name = "Auto M1 / Attack",
    Default = false,
    Callback = function(v)
        AutoM1Enabled = v
    end
})

UI_Elements.AutoM1DelaySlider = CombatSection:CreateSlider({
    Name = "Attack Delay",
    Min = 0.05,
    Max = 1.0,
    Default = 0.25,
    Precision = 2,
    Suffix = "s",
    Callback = function(v)
        AutoM1Delay = v
    end
})

UI_Elements.FaceTargetToggle = CombatSection:CreateToggle({
    Name = "Face Nearest / Target",
    Default = false,
    Callback = function(v)
        FaceTargetEnabled = v
    end
})

local TargetSection = CombatTab:CreateSection("Targeting", "Right")

UI_Elements.TargetDropdown = TargetSection:CreateDropdown({
    Name = "Target Player",
    Options = getPlayerList(),
    Default = "None",
    Callback = function(choice)
        TargetPlayerName = choice
    end
})

TargetSection:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        local current = getPlayerList()
        UI_Elements.TargetDropdown:Refresh(current, "None")
        Library:Notify({ Title = "Targeting", Content = "Player list refreshed (" .. tostring(#current - 1) .. " players)", Duration = 2 })
    end
})

TargetSection:CreateButton({
    Name = "Teleport Behind Target",
    Callback = function()
        teleportToPlayer(TargetPlayerName, true)
    end
})

TargetSection:CreateButton({
    Name = "Teleport In Front of Target",
    Callback = function()
        teleportToPlayer(TargetPlayerName, false)
    end
})

UI_Elements.SpectateToggle = TargetSection:CreateToggle({
    Name = "Spectate Target",
    Default = false,
    Callback = function(v)
        SpectatingTarget = v
        if v and TargetPlayerName ~= "None" then
            local targetPlr = Players:FindFirstChild(TargetPlayerName)
            if targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("Humanoid") then
                Camera.CameraSubject = targetPlr.Character.Humanoid
            end
        else
            local hum = getHumanoid()
            if hum then Camera.CameraSubject = hum end
        end
    end
})

-- Movement Tab
local MovementTab = Window:CreateTab("Movement")

local CharacterSection = MovementTab:CreateSection("Character Mods", "Left")

UI_Elements.WalkSpeedToggle = CharacterSection:CreateToggle({
    Name = "Enable WalkSpeed",
    Default = false,
    Callback = function(v)
        WalkSpeedEnabled = v
        if not v then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = 16 end
        end
    end
})

UI_Elements.WalkSpeedSlider = CharacterSection:CreateSlider({
    Name = "Speed Value",
    Min = 16,
    Max = 150,
    Default = 16,
    Suffix = " spd",
    Callback = function(v)
        CustomWalkSpeed = v
    end
})

UI_Elements.JumpPowerToggle = CharacterSection:CreateToggle({
    Name = "Enable JumpPower",
    Default = false,
    Callback = function(v)
        JumpPowerEnabled = v
        if not v then
            local hum = getHumanoid()
            if hum then hum.JumpPower = 50 end
        end
    end
})

UI_Elements.JumpPowerSlider = CharacterSection:CreateSlider({
    Name = "Jump Value",
    Min = 50,
    Max = 250,
    Default = 50,
    Suffix = " pwr",
    Callback = function(v)
        CustomJumpPower = v
    end
})

UI_Elements.InfJumpToggle = CharacterSection:CreateToggle({
    Name = "Infinite Jump",
    Default = false,
    Callback = function(v)
        InfiniteJumpEnabled = v
    end
})

UI_Elements.NoClipToggle = CharacterSection:CreateToggle({
    Name = "NoClip",
    Default = false,
    Callback = function(v)
        NoClipEnabled = v
        setNoclip(v)
    end
})

local FlySection = MovementTab:CreateSection("Flight", "Right")

UI_Elements.FlyToggle = FlySection:CreateToggle({
    Name = "Enable Fly",
    Default = false,
    Callback = function(v)
        FlyEnabled = v
        if v then
            startFly()
        else
            stopFly()
        end
    end
})

UI_Elements.FlySpeedSlider = FlySection:CreateSlider({
    Name = "Fly Speed",
    Min = 10,
    Max = 200,
    Default = 50,
    Suffix = " spd",
    Callback = function(v)
        FlySpeed = v
    end
})

FlySection:CreateKeybind({
    Name = "Fly Keybind",
    Default = Enum.KeyCode.F,
    Callback = function()
        FlyEnabled = not FlyEnabled
        UI_Elements.FlyToggle:Set(FlyEnabled)
        if FlyEnabled then
            startFly()
        else
            stopFly()
        end
    end
})

-- Visuals Tab
local VisualsTab = Window:CreateTab("Visuals")

local EspSection = VisualsTab:CreateSection("Player ESP", "Left")

UI_Elements.PlayerEspToggle = EspSection:CreateToggle({
    Name = "Enable Player ESP",
    Default = false,
    Callback = function(v)
        PlayerEspEnabled = v
        if not v then
            for player, _ in pairs(ActivePlayerEsp) do
                removePlayerEsp(player)
            end
        end
    end
})

UI_Elements.PlayerEspHighlightToggle = EspSection:CreateToggle({
    Name = "ESP Highlights / Chams",
    Default = true,
    Callback = function(v)
        PlayerEspHighlight = v
        for _, data in pairs(ActivePlayerEsp) do
            if data.Highlight then
                data.Highlight.Enabled = v
            end
        end
    end
})

UI_Elements.PlayerEspDistanceToggle = EspSection:CreateToggle({
    Name = "Show Distance",
    Default = true,
    Callback = function(v)
        PlayerEspDistance = v
    end
})

UI_Elements.PlayerEspHealthToggle = EspSection:CreateToggle({
    Name = "Show Health Bar & Text",
    Default = true,
    Callback = function(v)
        PlayerEspHealth = v
        for _, data in pairs(ActivePlayerEsp) do
            if data.BarFill and data.BarFill.Parent then
                data.BarFill.Parent.Visible = v
            end
        end
    end
})

local EspSettingsSection = VisualsTab:CreateSection("ESP Settings", "Right")

UI_Elements.MaxEspDistanceSlider = EspSettingsSection:CreateSlider({
    Name = "Max ESP Distance",
    Min = 50,
    Max = 2500,
    Default = 1000,
    Suffix = " studs",
    Callback = function(v)
        MaxEspDistance = v
    end
})

-- Misc Tab
local MiscTab = Window:CreateTab("Misc")

local UtilitiesSection = MiscTab:CreateSection("Utilities", "Left")

UI_Elements.AntiAfkToggle = UtilitiesSection:CreateToggle({
    Name = "Anti-AFK",
    Default = true,
    Callback = function(v)
        AntiAfkEnabled = v
    end
})

UtilitiesSection:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

UtilitiesSection:CreateButton({
    Name = "Server Hop",
    Callback = function()
        pcall(function()
            local sfUrl = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
            local req = game:HttpGet(sfUrl)
            local data = HttpService:JSONDecode(req)
            if data and data.data then
                for _, server in ipairs(data.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                        return
                    end
                end
            end
            Library:Notify({ Title = "Server Hop", Content = "No alternative servers found.", Duration = 3 })
        end)
    end
})

local ConfigSection = MiscTab:CreateSection("Configuration", "Right")

local configInputName = "default"
ConfigSection:CreateInput({
    Name = "Config Name",
    Placeholder = "Enter config name...",
    Default = "default",
    Callback = function(text)
        if text and text ~= "" then
            configInputName = text
        end
    end
})

ConfigSection:CreateButton({
    Name = "Save Config",
    Callback = function()
        saveConfig(configInputName)
    end
})

ConfigSection:CreateButton({
    Name = "Load Config",
    Callback = function()
        loadConfig(configInputName)
    end
})

Library:Notify({
    Title = "vectra",
    Content = "The Strongest Battlegrounds script loaded successfully!",
    Duration = 3.5
})
