local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local IsRunning = true
local CurrentTargetIndex = 1
local TargetPlayers = {}
local LastTargetSwitch = 0
local LastClickTime = 0

local VotePanel = Player.PlayerGui:WaitForChild("GameUI"):WaitForChild("Interface"):WaitForChild("VotePanel")

local function HasForceField(TargetPlayer)
    if not TargetPlayer or not TargetPlayer.Character then return true end
    return TargetPlayer.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function EquipKnife()
    local Backpack = Player:FindFirstChild("Backpack")
    if not Backpack then return false end
    local Knife = Backpack:FindFirstChild("Knife")
    if Knife then
        Humanoid:EquipTool(Knife)
        return true
    end
    for _, Obj in pairs(workspace:GetDescendants()) do
        if Obj.Name == "Knife" and Obj:IsA("Tool") and not Obj.Parent:IsA("Player") then
            if Obj:FindFirstChild("Handle") then
                RootPart.CFrame = Obj.Handle.CFrame
                task.wait(0.1)
                Obj.Parent = Backpack
                Humanoid:EquipTool(Obj)
                return true
            end
        end
    end
    return false
end

local function HasKnifeEquipped()
    local Tool = Character:FindFirstChildOfClass("Tool")
    return Tool and Tool.Name == "Knife"
end

local function AutoClick()
    local CurrentTime = tick()
    if CurrentTime - LastClickTime >= 0.1 then
        VirtualUser:ClickButton1(Vector2.new(0,0))
        LastClickTime = CurrentTime
    end
end

local function UpdateTargetPlayers()
    TargetPlayers = {}
    for _, TargetPlayer in pairs(Players:GetPlayers()) do
        if TargetPlayer ~= Player and TargetPlayer.Character and TargetPlayer.Character:FindFirstChild("HumanoidRootPart") and not HasForceField(TargetPlayer) then
            table.insert(TargetPlayers, TargetPlayer)
        end
    end
end

local function GetCurrentTarget()
    UpdateTargetPlayers()
    if #TargetPlayers == 0 then return nil end
    if CurrentTargetIndex > #TargetPlayers then CurrentTargetIndex = 1 end
    return TargetPlayers[CurrentTargetIndex]
end

local function MoveToDefaultPosition()
    if RootPart then
        RootPart.CFrame = CFrame.new(Vector3.new(0,12345,0)) * CFrame.Angles(math.rad(90),0,0)
    end
end

local function LayUnderTarget(Target)
    if not Target or not Target.Character or not Target.Character:FindFirstChild("HumanoidRootPart") or HasForceField(Target) then
        MoveToDefaultPosition()
        return
    end
    local TargetRoot = Target.Character.HumanoidRootPart
    local Position = TargetRoot.Position - Vector3.new(0,3,0)
    if RootPart then
        local Spin = tick() * 5
        local LookAt = CFrame.new(Position, TargetRoot.Position)
        RootPart.CFrame = LookAt * CFrame.Angles(0, Spin, 0)
    end
end

local function DisableMovement()
    if Humanoid then
        Humanoid.PlatformStand = true
        Humanoid.WalkSpeed = 0
        Humanoid.JumpPower = 0
    end
end

local function SwitchTarget(Target)
    local CurrentTime = tick()
    if not Target or (Target.Humanoid and Target.Humanoid.Health <= 0) or (CurrentTime - LastTargetSwitch >= 2) then
        CurrentTargetIndex = CurrentTargetIndex + 1
        LastTargetSwitch = CurrentTime
    end
end

local function MainLoop(DeltaTime)
    if not Character or not Character.Parent or not RootPart or not Humanoid then return end
    if not HasKnifeEquipped() then EquipKnife() end
    DisableMovement()
    local Target = GetCurrentTarget()
    LayUnderTarget(Target)
    AutoClick()
    SwitchTarget(Target)
end

local function SafeDestroy(Obj)
    if Obj and Obj.Parent then
        Obj:Destroy()
    end
end

local function RemoveReplicatedStorageObjects()
    for _, Obj in ipairs(ReplicatedStorage:GetChildren()) do
        SafeDestroy(Obj)
    end
end

ReplicatedStorage.ChildAdded:Connect(SafeDestroy)
task.spawn(function()
    while true do
        RemoveReplicatedStorageObjects()
        task.wait()
    end
end)

Humanoid.Died:Connect(function()
    IsRunning = false
end)

Player.CharacterAdded:Connect(function(NewCharacter)
    Character = NewCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    IsRunning = true
end)

-- New biggest-server hop method
local PlaceId, JobId = game.PlaceId, game.JobId
local ServersUrl = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Desc&limit=100"

local function ListServers(cursor)
    local Raw = game:HttpGet(ServersUrl .. ((cursor and "&cursor="..cursor) or ""))
    return HttpService:JSONDecode(Raw)
end

local function ServerHop()
    local BestServer, BestPlayers = nil, -1
    local Servers = ListServers()
    if Servers and Servers.data then
        for _, s in ipairs(Servers.data) do
            if s.id ~= JobId and s.playing < s.maxPlayers then
                if s.playing > BestPlayers then
                    BestPlayers = s.playing
                    BestServer = s
                end
            end
        end
    end
    if BestServer then
        if Character and Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.Anchored = true
        end
        TeleportService:TeleportToPlaceInstance(PlaceId, BestServer.id, Player)
    end
end

local function CheckServerHop()
    local VoteVisible = VotePanel.Visible
    local LowPlayers = #Players:GetPlayers() < 5
    if VoteVisible or LowPlayers then
        ServerHop()
    end
end

VotePanel:GetPropertyChangedSignal("Visible"):Connect(CheckServerHop)
RunService.Heartbeat:Connect(CheckServerHop)

local function StartAutoFarm()
    IsRunning = true
    RunService.Heartbeat:Connect(function(DeltaTime)
        if IsRunning then
            MainLoop(DeltaTime)
        end
    end)
end

StartAutoFarm()
