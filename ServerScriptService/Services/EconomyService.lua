--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlantDefinitions = require(ReplicatedStorage.Shared.PlantDefinitions)

local EconomyService = {}
EconomyService.__index = EconomyService

local playerDataService = nil
local timeService = nil

local function isPositiveInt(value: any): boolean
	return type(value) == "number" and value > 0 and value % 1 == 0
end

function EconomyService:Init(dependencies)
	playerDataService = dependencies.PlayerDataService
	timeService = dependencies.TimeService
end

function EconomyService:SpendMoney(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end
	return playerDataService:AdjustMoney(player, -amount)
end

function EconomyService:BuySeed(player: Player, plantId: string, qty: number): (boolean, string)
	if not isPositiveInt(qty) then
		return false, "Invalid quantity"
	end
	local plant = PlantDefinitions[plantId]
	if not plant then
		return false, "Unknown plant"
	end

	local totalCost = plant.seedCost * qty
	local paid = playerDataService:AdjustMoney(player, -totalCost)
	if not paid then
		return false, "Not enough money"
	end
	playerDataService:AdjustSeed(player, plantId, qty)
	return true, string.format("Bought %d x %s", qty, plant.displayName)
end

local function getSeasonalMultiplier(currentMonth: number, harvestWindowMonths: {number}): number
	for _, month in ipairs(harvestWindowMonths) do
		if month == currentMonth then
			return 1.08
		end
	end
	return 1.0
end

function EconomyService:SellHarvest(player: Player, plantId: string, qty: number): (boolean, string, number)
	if not isPositiveInt(qty) then
		return false, "Invalid quantity", 0
	end
	local plant = PlantDefinitions[plantId]
	if not plant then
		return false, "Unknown plant", 0
	end

	local available = playerDataService:Get(player)
	if not available then
		return false, "Data not loaded", 0
	end
	if (available.harvest[plantId] or 0) < qty then
		return false, "Not enough harvest", 0
	end

	local month = 1
	if timeService then
		month = select(1, timeService:GetCurrentDate())
	end
	local seasonalMultiplier = getSeasonalMultiplier(month, plant.harvestWindowMonths)
	local unitPrice = math.floor(plant.sellPrice * seasonalMultiplier)
	local total = unitPrice * qty

	playerDataService:AdjustHarvest(player, plantId, -qty)
	playerDataService:AdjustMoney(player, total)

	return true, string.format("Sold %d x %s", qty, plant.displayName), total
end

return setmetatable({}, EconomyService)
