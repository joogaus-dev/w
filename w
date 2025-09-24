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
local HeartbeatConnection

local VotePanel = Player.PlayerGui:WaitForChild("GameUI"):WaitForChild("Interface"):WaitForChild("VotePanel")

Player.CharacterAdded:Connect(function(NewCharacter)
	Character = NewCharacter
	Humanoid = Character:WaitForChild("Humanoid")
	RootPart = Character:WaitForChild("HumanoidRootPart")
	StartAutoFarm()
end)

local function HasForceField(TargetPlayer)
	if not TargetPlayer or not TargetPlayer.Character then return true end
	return TargetPlayer.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function HasSpawnedLobby(TargetPlayer)
	if not TargetPlayer or not TargetPlayer.Character then return true end
	return TargetPlayer.Character:FindFirstChild("HasSpawnedLobby") ~= nil
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
		if TargetPlayer ~= Player and TargetPlayer.Character and TargetPlayer.Character:FindFirstChild("HumanoidRootPart") and not HasForceField(TargetPlayer) and not HasSpawnedLobby(TargetPlayer) then
			table.insert(TargetPlayers, TargetPlayer)
		end
	end
end

local function GetCurrentTarget()
	UpdateTargetPlayers()
	if #TargetPlayers == 0 then return nil end
	if CurrentTargetIndex > #TargetPlayers then
		CurrentTargetIndex = 1
	end
	return TargetPlayers[CurrentTargetIndex]
end

local function MoveToDefaultPosition()
	if RootPart then
		RootPart.CFrame = CFrame.new(Vector3.new(0,12345,0)) * CFrame.Angles(math.rad(90),0,0)
	end
end

local function LayUnderTarget(Target)
	if not Target or not Target.Character or not Target.Character:FindFirstChild("HumanoidRootPart") or HasForceField(Target) or HasSpawnedLobby(Target) then
		MoveToDefaultPosition()
		return
	end
	local TargetRoot = Target.Character.HumanoidRootPart
	local TargetPos = TargetRoot.Position
	local Offset = Vector3.new(0, -2.6, 0)
	local Position = TargetPos + Offset
	if RootPart then
		RootPart.CFrame = CFrame.lookAt(Position, TargetPos + Vector3.new(0, 1.5, 0))
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

local PlaceId = game.PlaceId
local ServersUrl = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Desc&limit=100"

local function ListServers(Cursor)
	local Raw = game:HttpGet(ServersUrl .. ((Cursor and "&cursor="..Cursor) or ""))
	return HttpService:JSONDecode(Raw)
end

local function ServerHop()
	local CurrentJobId = game.JobId
	while true do
		local Servers = ListServers()
		if Servers and Servers.data then
			local PossibleServers = {}
			for _, S in ipairs(Servers.data) do
			    if S.id ~= CurrentJobId and S.playing < S.maxPlayers then
                table.insert(PossibleServers, S)
end

			end
			if #PossibleServers > 0 then
				local RandomServer = PossibleServers[math.random(1,#PossibleServers)]
				if Character and Character:FindFirstChild("HumanoidRootPart") then
					Character.HumanoidRootPart.Anchored = true
				end
				local Success, Err = pcall(function()
					TeleportService:TeleportToPlaceInstance(PlaceId, RandomServer.id, Player)
				end)
				if Success then break else task.wait(1) end
			else
				task.wait(2)
			end
		else
			task.wait(2)
		end
	end
end

local function CheckServerHop()
	local VoteVisible = VotePanel and VotePanel.Visible
	local LowPlayers = #Players:GetPlayers() <= 5
	if VoteVisible or LowPlayers then
		ServerHop()
	end
end

VotePanel:GetPropertyChangedSignal("Visible"):Connect(CheckServerHop)
RunService.Heartbeat:Connect(CheckServerHop)


VotePanel:GetPropertyChangedSignal("Visible"):Connect(function()
    if VotePanel.Visible then
        ServerHop()
    end
end)

local function StartAutoFarm()
	if HeartbeatConnection then HeartbeatConnection:Disconnect() end
	IsRunning = true
	HeartbeatConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		if IsRunning then MainLoop(DeltaTime) end
	end)
end

StartAutoFarm()

RunService.RenderStepped:Connect(function()
	for _, v in pairs(ReplicatedStorage:GetChildren()) do
		v:Destroy()
	end
end)
