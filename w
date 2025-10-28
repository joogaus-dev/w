local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Root = Character:WaitForChild("HumanoidRootPart")
local Camera = Workspace.CurrentCamera

local MinMoney = 50000000
local CurrentTarget = nil
local TargetBusy = false
local ValidModels = {}
local WebhookURL = "https://discord.com/api/webhooks/1432330112254345270/dMT5IrE16QHHG0jGCjkrnBtamwQRd2LW4wMz6NKcO6d38Mg9yxFGKemrfKY6CGsdNy4t"

--// UTILITIES //--

local function ParseMoney(Text)
	Text = Text:gsub("%$", ""):gsub("%s", ""):gsub(",", ""):gsub("/s", "")
	local Num = tonumber(Text:match("([%d%.]+)")) or 0
	local Suffix = Text:match("[KMBkmb]")
	if Suffix then
		Suffix = Suffix:upper()
		if Suffix == "K" then Num = Num * 1000
		elseif Suffix == "M" then Num = Num * 1000000
		elseif Suffix == "B" then Num = Num * 1000000000
		end
	end
	return Num
end

local function SendMessageEMBED(url, embed)
	local data = {
		["embeds"] = {
			{
				["title"] = embed.title,
				["description"] = embed.description,
				["color"] = embed.color or 65280,
				["fields"] = embed.fields or {},
				["footer"] = embed.footer and {["text"] = embed.footer.text} or nil
			}
		}
	}
	local body = HttpService:JSONEncode(data)
	request({
		Url = url,
		Method = "POST",
		Headers = {["Content-Type"] = "application/json"},
		Body = body
	})
end

--// SEND STARTUP WEBHOOK //--
local function SendStartupEmbed()
	local embed = {
		title = "✅ Script Started",
		description = "Auto-tracker is now running.",
		color = 65280,
		fields = {
			{name = "Target Threshold", value = "≥ $" .. tostring(MinMoney):reverse():gsub("(%d%d%d)","%1,"):reverse() .. " /s", inline = true},
			{name = "Status", value = "Looking for valid models...", inline = true}
		},
		footer = {text = "Auto-Tracker"}
	}
	SendMessageEMBED(WebhookURL, embed)
end

SendStartupEmbed()

--// VALIDATION + LOGIC //--

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
	for _,c in pairs(Part:GetChildren()) do
		if c:IsA("Sound") then return true end
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
	local embed = {
		title = "💎 High-Value Spawn Detected!",
		description = "A model with ≥50M generation has spawned.",
		color = 16776960,
		fields = {
			{name = "Generation", value = GenerationLabel.Text},
			{name = "DisplayName", value = DisplayNameLabel.Text}
		},
		footer = {text = "Auto-Tracker"}
	}
	SendMessageEMBED(WebhookURL, embed)
end

local function UpdateTarget()
	if TargetBusy then return end
	local closestModel = nil
	local closestPart = nil
	local shortestDistance = math.huge
	for Model,Part in pairs(ValidModels) do
		if Model.Parent and not CheckPurchase(Model, Part) then
			local dist = (Root.Position - Part.Position).Magnitude
			if dist < shortestDistance then
				shortestDistance = dist
				closestModel = Model
				closestPart = Part
			end
		end
	end
	if closestModel then
		CurrentTarget = {Model=closestModel, Part=closestPart}
		TargetBusy = true
	end
end

--// MOVEMENT LOOP //--

RunService.RenderStepped:Connect(function()
	for Model,Part in pairs(ValidModels) do
		if not Model.Parent or CheckPurchase(Model, Part) then
			ValidModels[Model] = nil
		end
	end
	if CurrentTarget and CurrentTarget.Model and CurrentTarget.Model.Parent then
		local Model, Part = CurrentTarget.Model, CurrentTarget.Part
		local direction = (Part.Position - Root.Position)
		local distance = direction.Magnitude
		if distance > 3 then
			Humanoid:MoveTo(Part.Position)
			local ignoreList = {Character}
			for _,desc in ipairs(Model:GetDescendants()) do
				if desc:IsA("BasePart") then table.insert(ignoreList, desc) end
			end
			if Workspace:FindFirstChild("RenderedMovingAnimals") then
				for _,desc in ipairs(Workspace.RenderedMovingAnimals:GetDescendants()) do
					if desc:IsA("BasePart") then table.insert(ignoreList, desc) end
				end
			end
			local ray = Ray.new(Root.Position, direction.Unit*distance)
			local hit = Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
			if hit and hit.CanCollide and Humanoid.FloorMaterial ~= Enum.Material.Air then
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
		end
		Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, Part.Position), 0.15)
	else
		TargetBusy = false
		CurrentTarget = nil
	end
	UpdateTarget()
end)

--// MODEL DETECTION //--

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


while true do wait(10) game:GetService"Players".LocalPlayer.Character:FindFirstChildOfClass'Humanoid':ChangeState("Jumping") end
