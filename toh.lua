--[[
    ROCKET Script v3 | Tower of Hell
    Delta Executor | Android / iOS | Одним файлом
    Мод-меню + тач-джойстик + античит-обход
]]

-- ================== СЕРВИСЫ ==================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local Stats            = game:GetService("Stats")

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP  = Char:WaitForChild("HumanoidRootPart")
local Hum  = Char:WaitForChild("Humanoid")

-- ================== КОНФИГ ==================
local CFG = {
    GodMode       = false,
    Fly           = false,
    FlySpeed      = 120,
    AntiVoid      = true,
    InfiniteJump  = false,
    NoClip        = false,
    SpeedHack     = false,
    SpeedValue    = 100,
    JumpPower     = false,
    JumpValue     = 120,
    AntiAFK       = true,
    AntiKick      = true,
    DesyncMode    = false,
}

-- ================== УТИЛИТЫ ==================
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "ROCKET",
            Text  = text or "",
            Duration = 3,
        })
    end)
end

local function safeDestroy(obj)
    pcall(function() if obj and obj.Parent then obj:Destroy() end end)
end

-- ================== ANTICHEAT BYPASS ==================
-- Глушим возможные клиентские детекторы движения.
-- 1) Отключаем логирование киков через Player:Kick на клиенте
-- 2) Глушим античит-мониторинг скорости
-- 3) Анти-AFK
-- 4) Защита от "You have been kicked"

local function installAnticheatBypass()
    -- 1) Блокируем Kick на локальном клиенте
    if CFG.AntiKick then
        pcall(function()
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "Kick" and self == LP then
                    return
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end)
    end

    -- 2) Анти-AFK (имитация действий каждые 60 сек)
    if CFG.AntiAFK then
        LP.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end
end

-- ================== GODMODE ==================
local godMTApplied = false
local function enableGodMode()
    if not Hum then return end
    Hum.MaxHealth = math.huge
    Hum.Health = math.huge
    Hum.BreakJointsOnDeath = false
    Hum.RequiresNeck = false

    -- Слой 1: хук TakeDamage
    if not godMTApplied then
        godMTApplied = true
        pcall(function()
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "TakeDamage" and self == Hum and CFG.GodMode then
                    return
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end)
    end

    -- Слой 2: HealthChanged -> откат
    if not Hum:FindFirstChild("RocketGodConn") then
        local tag = Instance.new("BoolValue")
        tag.Name = "RocketGodConn"
        tag.Parent = Hum
        Hum.HealthChanged:Connect(function(h)
            if CFG.GodMode and h < Hum.MaxHealth then
                Hum.Health = Hum.MaxHealth
            end
        end)
    end
end

-- ================== FLY (тач-джойстик) ==================
local flyBV, flyBG, flyConn, flyJoystick

local function startFly()
    if flyBV then return end

    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = HRP

    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBG.P = 1e4
    flyBG.Parent = HRP

    local pg = LP:WaitForChild("PlayerGui")
    local oldJS = pg:FindFirstChild("RocketFlyJS")
    if oldJS then oldJS:Destroy() end

    local jsGui = Instance.new("ScreenGui")
    jsGui.Name = "RocketFlyJS"
    jsGui.ResetOnSpawn = false
    jsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    jsGui.Parent = pg

    -- Джойстик движения
    local base = Instance.new("Frame")
    base.Size = UDim2.new(0, 150, 0, 150)
    base.Position = UDim2.new(0, 30, 1, -200)
    base.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    base.BackgroundTransparency = 0.35
    base.BorderSizePixel = 0
    base.Active = true
    base.Parent = jsGui
    Instance.new("UICorner", base).CornerRadius = UDim.new(1, 0)
    local bstroke = Instance.new("UIStroke", base)
    bstroke.Color = Color3.fromRGB(255, 60, 60)
    bstroke.Thickness = 2

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 62, 0, 62)
    knob.Position = UDim2.new(0.5, -31, 0.5, -31)
    knob.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    knob.BorderSizePixel = 0
    knob.Parent = base
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    -- Кнопки вверх/вниз
    local upBtn = Instance.new("TextButton")
    upBtn.Size = UDim2.new(0, 65, 0, 65)
    upBtn.Position = UDim2.new(0, 200, 1, -270)
    upBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
    upBtn.Text = "▲"
    upBtn.TextColor3 = Color3.new(1,1,1)
    upBtn.TextSize = 28
    upBtn.Font = Enum.Font.GothamBold
    upBtn.BorderSizePixel = 0
    upBtn.AutoButtonColor = false
    upBtn.Parent = jsGui
    Instance.new("UICorner", upBtn).CornerRadius = UDim.new(1, 0)

    local dnBtn = Instance.new("TextButton")
    dnBtn.Size = UDim2.new(0, 65, 0, 65)
    dnBtn.Position = UDim2.new(0, 200, 1, -195)
    dnBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    dnBtn.Text = "▼"
    dnBtn.TextColor3 = Color3.new(1,1,1)
    dnBtn.TextSize = 28
    dnBtn.Font = Enum.Font.GothamBold
    dnBtn.BorderSizePixel = 0
    dnBtn.AutoButtonColor = false
    dnBtn.Parent = jsGui
    Instance.new("UICorner", dnBtn).CornerRadius = UDim.new(1, 0)

    -- Кнопка отключения полёта
    local offBtn = Instance.new("TextButton")
    offBtn.Size = UDim2.new(0, 44, 0, 44)
    offBtn.Position = UDim2.new(0, 200, 1, -340)
    offBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    offBtn.Text = "✕"
    offBtn.TextColor3 = Color3.new(1,1,1)
    offBtn.TextSize = 20
    offBtn.Font = Enum.Font.GothamBold
    offBtn.BorderSizePixel = 0
    offBtn.AutoButtonColor = false
    offBtn.Parent = jsGui
    Instance.new("UICorner", offBtn).CornerRadius = UDim.new(1, 0)

    offBtn.MouseButton1Click:Connect(function()
        CFG.Fly = false
        stopFly()
    end)

    -- Состояние
    local moveVec = Vector2.zero
    local upHeld, dnHeld = false, false
    local dragging = false

    local function updateKnob(input)
        local center = base.AbsolutePosition + base.AbsoluteSize / 2
        local delta = Vector2.new(input.Position.X, input.Position.Y) - center
        local maxR = base.AbsoluteSize.X / 2 - 31
        if delta.Magnitude > maxR then
            delta = delta.Unit * maxR
        end
        knob.Position = UDim2.new(0.5, delta.X - 31, 0.5, delta.Y - 31)
        moveVec = delta / maxR
    end

    base.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateKnob(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
            updateKnob(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            moveVec = Vector2.zero
            knob.Position = UDim2.new(0.5, -31, 0.5, -31)
        end
    end)

    upBtn.MouseButton1Down:Connect(function() upHeld = true end)
    upBtn.MouseButton1Up:Connect(function() upHeld = false end)
    upBtn.MouseLeave:Connect(function() upHeld = false end)
    dnBtn.MouseButton1Down:Connect(function() dnHeld = true end)
    dnBtn.MouseButton1Up:Connect(function() dnHeld = false end)
    dnBtn.MouseLeave:Connect(function() dnHeld = false end)

    flyConn = RunService.RenderStepped:Connect(function()
        if not HRP or not HRP.Parent then return end
        local cam = workspace.CurrentCamera

        local right = cam.CFrame.RightVector
        local look  = cam.CFrame.LookVector
        local dir = (right * moveVec.X) + (look * -moveVec.Y)

        if upHeld then dir += Vector3.new(0, 1, 0) end
        if dnHeld then dir -= Vector3.new(0, 1, 0) end

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end

        if dir.Magnitude > 0 then
            flyBV.Velocity = dir.Unit * CFG.FlySpeed
        else
            flyBV.Velocity = Vector3.zero
        end
        flyBG.CFrame = cam.CFrame
    end)

    flyJoystick = jsGui
end

function stopFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    safeDestroy(flyJoystick)
    flyJoystick = nil
end

-- ================== ANTI-VOID ==================
task.spawn(function()
    while task.wait(0.3) do
        if CFG.AntiVoid and HRP and HRP.Parent and HRP.Position.Y < -50 then
            pcall(function()
                HRP.CFrame = CFrame.new(0, 50, 0)
                HRP.Velocity = Vector3.zero
            end)
        end
    end
end)

-- ================== INFINITE JUMP ==================
UserInputService.JumpRequest:Connect(function()
    if CFG.InfiniteJump and Hum then
        Hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- ================== NOCLIP ==================
RunService.Stepped:Connect(function()
    if CFG.NoClip and Char then
        for _, p in ipairs(Char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end
end)

-- ================== SPEED / JUMP ==================
RunService.Heartbeat:Connect(function()
    if not Hum then return end
    if CFG.SpeedHack and Hum.WalkSpeed ~= CFG.SpeedValue then
        Hum.WalkSpeed = CFG.SpeedValue
    end
    if CFG.JumpPower and Hum.UseJumpPower and Hum.JumpPower ~= CFG.JumpValue then
        Hum.JumpPower = CFG.JumpValue
    end
end)

-- ================== RESPAWN ==================
LP.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart")
    Hum  = c:WaitForChild("Humanoid")
    task.wait(0.3)
    if CFG.GodMode then enableGodMode() end
    if CFG.Fly then
        stopFly()
        startFly()
    end
end)

-- ================== МОД-МЕНЮ ==================
local function createMenu()
    safeDestroy(CoreGui:FindFirstChild("RocketMenu"))

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RocketMenu"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end

    -- ===== Главный фрейм =====
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 300, 0, 400)
    Main.Position = UDim2.new(0.5, -150, 0.5, -200)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
    local mstr = Instance.new("UIStroke", Main)
    mstr.Color = Color3.fromRGB(255, 60, 60)
    mstr.Thickness = 2

    -- ===== Шапка =====
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 42)
    Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    Header.BorderSizePixel = 0
    Header.Parent = Main
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 14, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🚀 ROCKET | ToH"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.Parent = Header

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 28, 0, 28)
    MinBtn.Position = UDim2.new(1, -66, 0, 7)
    MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    MinBtn.Text = "–"
    MinBtn.TextColor3 = Color3.new(1,1,1)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 16
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = Header
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -32, 0, 7)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    CloseBtn.Text = "×"
    CloseBtn.TextColor3 = Color3.new(1,1,1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 18
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = Header
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    -- ===== Скролл =====
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -20, 1, -62)
    Scroll.Position = UDim2.new(0, 10, 0, 52)
    Scroll.BackgroundTransparency = 1
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 5
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Scroll.Parent = Main

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Scroll

    -- ===== Тумблер =====
    local function makeToggle(name, key, callback)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, -6, 0, 40)
        Btn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
        Btn.Text = ""
        Btn.AutoButtonColor = false
        Btn.BorderSizePixel = 0
        Btn.Parent = Scroll
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -80, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(230, 230, 230)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.Parent = Btn

        local Ind = Instance.new("Frame")
        Ind.Size = UDim2.new(0, 44, 0, 22)
        Ind.Position = UDim2.new(1, -56, 0.5, -11)
        Ind.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        Ind.BorderSizePixel = 0
        Ind.Parent = Btn
        Instance.new("UICorner", Ind).CornerRadius = UDim.new(1, 0)

        local Dot = Instance.new("Frame")
        Dot.Size = UDim2.new(0, 18, 0, 18)
        Dot.Position = UDim2.new(0, 2, 0.5, -9)
        Dot.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
        Dot.BorderSizePixel = 0
        Dot.Parent = Ind
        Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

        local state = CFG[key] or false
        if state then
            Ind.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
            Dot.Position = UDim2.new(1, -20, 0.5, -9)
        end

        local function render()
            TweenService:Create(Ind, TweenInfo.new(0.15), {
                BackgroundColor3 = state and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 60, 70)
            }):Play()
            TweenService:Create(Dot, TweenInfo.new(0.15), {
                Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            }):Play()
        end

        Btn.MouseButton1Click:Connect(function()
            state = not state
            CFG[key] = state
            render()
            if callback then pcall(callback, state) end
        end)
    end

    -- ===== Слайдер =====
    local function makeSlider(name, key, min, max, default, callback)
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -6, 0, 58)
        Frame.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
        Frame.BorderSizePixel = 0
        Frame.Parent = Scroll
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -20, 0, 20)
        Label.Position = UDim2.new(0, 12, 0, 5)
        Label.BackgroundTransparency = 1
        Label.Text = name .. ": " .. default
        Label.TextColor3 = Color3.fromRGB(230, 230, 230)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 13
        Label.Parent = Frame

        local Bar = Instance.new("Frame")
        Bar.Size = UDim2.new(1, -24, 0, 10)
        Bar.Position = UDim2.new(0, 12, 0, 38)
        Bar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        Bar.BorderSizePixel = 0
        Bar.Active = true
        Bar.Parent = Frame
        Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)

        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        Fill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        Fill.BorderSizePixel = 0
        Fill.Parent = Bar
        Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local function setFromX(x)
            local rel = math.clamp((x - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * rel)
            Fill.Size = UDim2.new(rel, 0, 1, 0)
            Label.Text = name .. ": " .. val
            CFG[key] = val
            if callback then pcall(callback, val) end
        end

        Bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                setFromX(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
                setFromX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.T
