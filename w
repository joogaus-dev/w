local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Root = Character:WaitForChild("HumanoidRootPart")
local Camera = Workspace.CurrentCamera

local MinMoney = 10
local CurrentTarget = nil
local TargetBusy = false
local ValidModels = {}
local WebhookURL = "https://discord.com/api/webhooks/1432330112254345270/dMT5IrE16QHHG0jGCjkrnBtamwQRd2LW4wMz6NKcO6d38Mg9yxFGKemrfKY6CGsdNy4t"

local BaseRadius = 10
local BaseSpeed = 2
local BaseJumpInterval = 1
local Angle = 0
local Center = Root.Position
local LastJumpTime = tick()
local Orbiting = true

local function ParseMoney(Text)
	Text = Text:gsub("%$", ""):gsub("%s", ""):gsub(",", ""):gsub("/s", "")
	local Num = tonumber(Text:match("([%d%.]+)")) or 0
	local Suffix = Text:match("[KMBkmb]")
	if Suffix then
		Suffix = Suffix:upper()
		if Suffix == "K" then Num = Num * 1000 elseif Suffix == "M" then Num = Num * 1000000 elseif Suffix == "B" then Num = Num * 1000000000 end
	end
	return Num
end

local function SendMessageEMBED(Url, Embed)
	local Data = {
		["embeds"] = {
			{
				["title"] = Embed.title,
				["description"] = Embed.description,
				["color"] = Embed.color or 65280,
				["fields"] = Embed.fields or {},
				["footer"] = Embed.footer and {["text"] = Embed.footer.text} or nil
			}
		}
	}
	local Body = HttpService:JSONEncode(Data)
	request({
		Url = Url,
		Method = "POST",
		Headers = {["Content-Type"] = "application/json"},
		Body = Body
	})
end

local function SendStartupEmbed()
	local Embed = {
		title = "✅ Script Started",
		description = "Auto-tracker is now running.",
		color = 65280,
		fields = {
			{name = "Target Threshold", value = "≥ $" .. tostring(MinMoney):reverse():gsub("(%d%d%d)","%1,"):reverse() .. " /s", inline = true},
			{name = "Status", value = "Looking for valid models...", inline = true}
		},
		footer = {text = "Auto-Tracker"}
	}
	SendMessageEMBED(WebhookURL, Embed)
end

SendStartupEmbed()

local function IsValidCharacter(Model)
	if not Model:IsA("Model") then return false,nil end
	local Part = Model:FindFirstChildWhichIsA("BasePart")
	if not Part then return false,nil end
	local Attachments = {}
	for _,A in pairs(Part:GetChildren()) do
		if A:IsA("Attachment") then table.insert(Attachments,A) end
	end
	if #Attachments < 2 then return false,nil end
	local Info = Part:FindFirstChild("Info")
	if not Info then return false,nil end
	local Overhead = Info:FindFirstChild("AnimalOverhead")
	if not Overhead then return false,nil end
	local Generation = Overhead:FindFirstChild("Generation")
	if not Generation or not Generation:IsA("TextLabel") then return false,nil end
	local Money = ParseMoney(Generation.Text)
	if Money < MinMoney then return false,nil end
	return true, Part
end

local function CheckPurchase(Model, Part)
	if not Model.Parent then return true end
	local PromptAttachment = Part:FindFirstChild("PromptAttachment")
	if not PromptAttachment then return true end
	local Prompt = PromptAttachment:FindFirstChildWhichIsA("ProximityPrompt")
	if not Prompt then return true end
	for _,C in pairs(Part:GetChildren()) do
		if C:IsA("Sound") then return true end
	end
	return false
end

local function SendSpawnEmbed(Part)
	local Info = Part:FindFirstChild("Info")
	if not Info then return end
	local Overhead = Info:FindFirstChild("AnimalOverhead")
	if not Overhead then return end
	local GenerationLabel = Overhead:FindFirstChild("Generation")
	local DisplayNameLabel = Overhead:FindFirstChild("DisplayName")
	if not GenerationLabel or not DisplayNameLabel then return end
	local Embed = {
		title = "💎 High-Value Spawn Detected!",
		description = "A model with ≥50M generation has spawned.",
		color = 16776960,
		fields = {
			{name = "Generation", value = GenerationLabel.Text},
			{name = "DisplayName", value = DisplayNameLabel.Text}
		},
		footer = {text = "Auto-Tracker"}
	}
	SendMessageEMBED(WebhookURL, Embed)
end

local function GetRandomRadius() return BaseRadius + math.random(-2, 3) + math.random() end
local function GetRandomSpeed() return BaseSpeed + math.random(-1, 2) * 0.5 + math.random() end
local function GetRandomJumpInterval() return BaseJumpInterval + math.random(-1, 2) * 0.2 end

local Radius = GetRandomRadius()
local Speed = GetRandomSpeed()
local JumpInterval = GetRandomJumpInterval()

local function UpdateTarget()
	if TargetBusy then return end
	local ClosestModel = nil
	local ClosestPart = nil
	local ShortestDistance = math.huge
	for Model,Part in pairs(ValidModels) do
		if Model.Parent and not CheckPurchase(Model, Part) then
			local Dist = (Root.Position - Part.Position).Magnitude
			if Dist < ShortestDistance then
				ShortestDistance = Dist
				ClosestModel = Model
				ClosestPart = Part
			end
		end
	end
	if ClosestModel then
		CurrentTarget = {Model=ClosestModel, Part=ClosestPart}
		TargetBusy = true
		Orbiting = false
	end
end

RunService.RenderStepped:Connect(function(DeltaTime)
	for Model,Part in pairs(ValidModels) do
		if not Model.Parent or CheckPurchase(Model, Part) then
			ValidModels[Model] = nil
		end
	end
	if CurrentTarget and CurrentTarget.Model and CurrentTarget.Model.Parent then
		local Model, Part = CurrentTarget.Model, CurrentTarget.Part
		local Direction = (Part.Position - Root.Position)
		local Distance = Direction.Magnitude
		if Distance > 3 then
			Humanoid:MoveTo(Part.Position)
			local IgnoreList = {Character}
			for _,Desc in ipairs(Model:GetDescendants()) do
				if Desc:IsA("BasePart") then table.insert(IgnoreList, Desc) end
			end
			if Workspace:FindFirstChild("RenderedMovingAnimals") then
				for _,Desc in ipairs(Workspace.RenderedMovingAnimals:GetDescendants()) do
					if Desc:IsA("BasePart") then table.insert(IgnoreList, Desc) end
				end
			end
			local RayC = Ray.new(Root.Position, Direction.Unit*Distance)
			local Hit = Workspace:FindPartOnRayWithIgnoreList(RayC, IgnoreList)
			if Hit and Hit.CanCollide and Humanoid.FloorMaterial ~= Enum.Material.Air then
				Humanoid.Jump = true
			end
		else
			local PromptAttachment = Part:FindFirstChild("PromptAttachment")
			if PromptAttachment then
				local Prompt = PromptAttachment:FindFirstChildWhichIsA("ProximityPrompt")
				if Prompt then
					Prompt:InputHoldBegin(Enum.UserInputType.Keyboard)
					task.wait(0.5)
					Prompt:InputHoldEnd(Enum.UserInputType.Keyboard)
				end
			end
			CurrentTarget = nil
			TargetBusy = false
			Orbiting = true
			Center = Root.Position
			Radius = GetRandomRadius()
			Speed = GetRandomSpeed()
			JumpInterval = GetRandomJumpInterval()
		end
		Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, Part.Position), 0.15)
	elseif Orbiting then
		Angle = Angle + Speed * DeltaTime
		if Angle > 2 * math.pi then
			Angle = Angle - 2 * math.pi
			Radius = GetRandomRadius()
			Speed = GetRandomSpeed()
			JumpInterval = GetRandomJumpInterval()
		end
		local TargetPos = Vector3.new(Center.X + Radius * math.cos(Angle), Root.Position.Y, Center.Z + Radius * math.sin(Angle))
		local Direction = (TargetPos - Root.Position).Unit
		Humanoid:Move(Direction, false)
		if tick() - LastJumpTime >= JumpInterval then
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			LastJumpTime = tick()
		end
	end
	UpdateTarget()
end)

local function TryModel(Model)
	local Valid, Part = IsValidCharacter(Model)
	if Valid and Part and not CheckPurchase(Model, Part) then
		ValidModels[Model] = Part
		UpdateTarget()
		SendSpawnEmbed(Part)
	end
end

Workspace.ChildAdded:Connect(function(Model)
	task.wait(0.1)
	TryModel(Model)
end)

for _,Model in pairs(Workspace:GetChildren()) do
	TryModel(Model)
end
