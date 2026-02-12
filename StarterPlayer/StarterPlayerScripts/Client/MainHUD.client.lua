--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("MainHUD") :: ScreenGui
local container = (hud:FindFirstChild("Root") and hud.Root:IsA("Frame")) and hud.Root or nil

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RE_RequestState = remotes:WaitForChild("RequestState")
local RE_TimeUpdate = remotes:WaitForChild("TimeUpdate")
local RE_Toast = remotes:WaitForChild("Toast")
local RE_SleepRequest = remotes:WaitForChild("SleepRequest")
local RE_BuySeedRequest = remotes:WaitForChild("BuySeedRequest")
local RE_SellHarvestRequest = remotes:WaitForChild("SellHarvestRequest")
local RE_OpenShop = remotes:WaitForChild("OpenShop")

local progressFrame = hud:WaitForChild("ProgressBarFrame") :: Frame
local fillFrame = progressFrame:WaitForChild("FillFrame") :: Frame
local monthText = hud:WaitForChild("MonthText") :: TextLabel
local moneyText = hud:WaitForChild("MoneyText") :: TextLabel
local toastText = hud:WaitForChild("ToastText") :: TextLabel
local sleepButton = hud:WaitForChild("SleepButton") :: TextButton
local openSeedShopButton = hud:WaitForChild("OpenSeedShopButton") :: TextButton
local openSellShopButton = hud:WaitForChild("OpenSellShopButton") :: TextButton
local seedShopFrame = hud:WaitForChild("SeedShopFrame") :: Frame
local sellShopFrame = hud:WaitForChild("SellShopFrame") :: Frame

local function monthName(month: number): string
	local names = {"Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"}
	return names[month] or tostring(month)
end

local function applySeasonLook(month: number)
	if not container then
		return
	end
	if month >= 3 and month <= 5 then
		container.BackgroundColor3 = Color3.fromRGB(63, 96, 58)
	elseif month >= 6 and month <= 8 then
		container.BackgroundColor3 = Color3.fromRGB(99, 113, 55)
	elseif month >= 9 and month <= 11 then
		container.BackgroundColor3 = Color3.fromRGB(97, 71, 38)
	else
		container.BackgroundColor3 = Color3.fromRGB(67, 78, 101)
	end
end

local function tweenProgress(progress: number)
	local clamped = math.clamp(progress, 0, 1)
	TweenService:Create(fillFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(clamped, 1),
	}):Play()
end

local function toast(ok: boolean, msg: string)
	toastText.Text = (ok and "✅ " or "❌ ") .. msg
	toastText.TextTransparency = 0
	task.delay(2.5, function()
		toastText.TextTransparency = 0.35
	end)
end

local function updateShopList(frame: Frame, title: string, buttonRemote: RemoteEvent, sourceTable: {[string]: number})
	local list = frame:FindFirstChild("List") :: Frame
	if not list then
		return
	end
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	frame.Visible = true
	(frame:FindFirstChild("Title") :: TextLabel).Text = title

	local y = 0
	for plantId, amount in pairs(sourceTable) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -8, 0, 24)
		b.Position = UDim2.new(0, 4, 0, y)
		b.Text = string.format("%s (x%d)", plantId, amount)
		b.Parent = list
		y += 26
		b.MouseButton1Click:Connect(function()
			buttonRemote:FireServer(plantId, 1)
		end)
	end
end

local latestState = {
	money = 0,
	seeds = {} :: {[string]: number},
	harvest = {} :: {[string]: number},
}

RE_TimeUpdate.OnClientEvent:Connect(function(payload)
	if payload.month and payload.year then
		monthText.Text = string.format("%s %d", monthName(payload.month), payload.year)
		applySeasonLook(payload.month)
	end
	if payload.progress ~= nil then
		tweenProgress(payload.progress)
	end
	if payload.money ~= nil then
		latestState.money = payload.money
		moneyText.Text = string.format("€ %d", payload.money)
	end
	if payload.seeds then
		latestState.seeds = payload.seeds
	end
	if payload.harvest then
		latestState.harvest = payload.harvest
	end
end)

RE_Toast.OnClientEvent:Connect(toast)

sleepButton.MouseButton1Click:Connect(function()
	RE_SleepRequest:FireServer()
end)

openSeedShopButton.MouseButton1Click:Connect(function()
	updateShopList(seedShopFrame, "Seed Shop", RE_BuySeedRequest :: RemoteEvent, latestState.seeds)
	sellShopFrame.Visible = false
end)

openSellShopButton.MouseButton1Click:Connect(function()
	updateShopList(sellShopFrame, "Sell Shop", RE_SellHarvestRequest :: RemoteEvent, latestState.harvest)
	seedShopFrame.Visible = false
end)

RE_OpenShop.OnClientEvent:Connect(function(shopType)
	if shopType == "SEED" then
		openSeedShopButton:Activate()
	elseif shopType == "SELL" then
		openSellShopButton:Activate()
	end
end)

RE_RequestState:FireServer()
