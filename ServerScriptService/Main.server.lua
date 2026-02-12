--!strict
-- Urban Plant Tycoon Berlin - Main server bootstrap
-- HOW TO TEST (quick):
-- 1) In Workspace create Folder "TycoonFields" and add Parts (fields) with Attributes:
--    - FieldType: one of SUN_WET, SUN_DRY, SHADE_WET, SHADE_DRY
--    - OwnerUserId: your UserId for private field tests (optional for public)
-- 2) Create Parts: SeedShopPart, SellShopPart, SleepPart. This script adds ProximityPrompts automatically.
-- 3) Play test:
--    - Use prompt/buttons to open shop and buy seeds.
--    - Plant via PlantSeedRequest remote (wire this to clicking fields in client).
--    - Sleep to jump month; observe progress + month text updates.
--    - Harvest and sell in Sell Shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local TimeService = require(script.Parent.Services.TimeService)
local EconomyService = require(script.Parent.Services.EconomyService)
local FarmingService = require(script.Parent.Services.FarmingService)

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local function ensureRemoteEvent(name: string): RemoteEvent
	local remote = remotesFolder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = remotesFolder
	return created
end

local RF_RequestState = ensureRemoteEvent("RequestState")
local RE_TimeUpdate = ensureRemoteEvent("TimeUpdate")
local RE_Toast = ensureRemoteEvent("Toast")
local RE_SleepRequest = ensureRemoteEvent("SleepRequest")
local RE_BuySeedRequest = ensureRemoteEvent("BuySeedRequest")
local RE_SellHarvestRequest = ensureRemoteEvent("SellHarvestRequest")
local RE_PlantSeedRequest = ensureRemoteEvent("PlantSeedRequest")
local RE_HarvestRequest = ensureRemoteEvent("HarvestRequest")
local RE_OpenShop = ensureRemoteEvent("OpenShop")

PlayerDataService:Init()
TimeService:Init()
EconomyService:Init({
	PlayerDataService = PlayerDataService,
	TimeService = TimeService,
})
TimeService:BindEconomyService(EconomyService)
FarmingService:Init({
	PlayerDataService = PlayerDataService,
	TimeService = TimeService,
})

local function pushState(player: Player)
	local month, year = TimeService:GetCurrentDate()
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	RE_TimeUpdate:FireClient(player, {
		month = month,
		year = year,
		progress = TimeService:GetMonthProgress(),
		money = data.money,
		seeds = data.seeds,
		harvest = data.harvest,
	})
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		while not PlayerDataService:Get(player) do
			task.wait(0.1)
		end
		pushState(player)
	end)
end)

RF_RequestState.OnServerEvent:Connect(function(player)
	pushState(player)
end)

TimeService.MonthChanged.Event:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		pushState(player)
	end
end)

TimeService.MonthProgressChanged.Event:Connect(function(progress)
	for _, player in ipairs(Players:GetPlayers()) do
		RE_TimeUpdate:FireClient(player, { progress = progress })
	end
end)

RE_SleepRequest.OnServerEvent:Connect(function(player)
	local ok, msg = TimeService:RequestSleepNextMonth(player)
	RE_Toast:FireClient(player, ok, msg)
	pushState(player)
end)

RE_BuySeedRequest.OnServerEvent:Connect(function(player, plantId, qty)
	if type(plantId) ~= "string" or type(qty) ~= "number" then
		RE_Toast:FireClient(player, false, "Invalid buy request")
		return
	end
	local ok, msg = EconomyService:BuySeed(player, plantId, math.floor(qty))
	RE_Toast:FireClient(player, ok, msg)
	pushState(player)
end)

RE_SellHarvestRequest.OnServerEvent:Connect(function(player, plantId, qty)
	if type(plantId) ~= "string" or type(qty) ~= "number" then
		RE_Toast:FireClient(player, false, "Invalid sell request")
		return
	end
	local ok, msg = EconomyService:SellHarvest(player, plantId, math.floor(qty))
	RE_Toast:FireClient(player, ok, msg)
	pushState(player)
end)

RE_PlantSeedRequest.OnServerEvent:Connect(function(player, fieldInstance, plantId)
	if typeof(fieldInstance) ~= "Instance" or type(plantId) ~= "string" then
		RE_Toast:FireClient(player, false, "Invalid plant request")
		return
	end
	local ok, msg = FarmingService:PlantSeed(player, fieldInstance, plantId)
	RE_Toast:FireClient(player, ok, msg)
	pushState(player)
end)

RE_HarvestRequest.OnServerEvent:Connect(function(player, fieldInstance)
	if typeof(fieldInstance) ~= "Instance" then
		RE_Toast:FireClient(player, false, "Invalid harvest request")
		return
	end
	local ok, msg = FarmingService:HarvestField(player, fieldInstance)
	RE_Toast:FireClient(player, ok, msg)
	pushState(player)
end)

local function attachPrompt(partName: string, actionText: string, callback: (Player) -> ())
	local part = workspace:FindFirstChild(partName)
	if not part or not part:IsA("BasePart") then
		warn("[Main.server] Missing part", partName)
		return
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = partName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.Parent = part
	prompt.Triggered:Connect(callback)
end

attachPrompt("SeedShopPart", "Open Seed Shop", function(player)
	RE_OpenShop:FireClient(player, "SEED")
end)

attachPrompt("SellShopPart", "Open Sell Shop", function(player)
	RE_OpenShop:FireClient(player, "SELL")
end)

attachPrompt("SleepPart", "Sleep to next Month", function(player)
	local ok, msg = TimeService:RequestSleepNextMonth(player)
	RE_Toast:FireClient(player, ok, msg)
	pushState(player)
end)
