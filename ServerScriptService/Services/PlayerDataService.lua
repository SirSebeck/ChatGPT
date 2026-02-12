--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PlantDefinitions = require(game.ReplicatedStorage.Shared.PlantDefinitions)

type PlayerData = {
	money: number,
	seeds: {[string]: number},
	harvest: {[string]: number},
	unlocks: {[string]: boolean},
	stats: {
		totalHarvested: number,
		totalSold: number,
	},
}

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local PROFILE_STORE = DataStoreService:GetDataStore("UrbanPlantTycoonBerlin_v1")
local sessionData: {[Player]: PlayerData} = {}
local saveDebounce: {[Player]: boolean} = {}

local MAX_RETRY = 3
local RETRY_WAIT = 1

local function deepCopySeeds(): {[string]: number}
	local seeds: {[string]: number} = {}
	for plantId, _ in pairs(PlantDefinitions) do
		seeds[plantId] = 0
	end
	return seeds
end

local function defaultData(): PlayerData
	return {
		money = 250,
		seeds = deepCopySeeds(),
		harvest = deepCopySeeds(),
		unlocks = {
			BASIC_PLOTS = true,
		},
		stats = {
			totalHarvested = 0,
			totalSold = 0,
		},
	}
end

local function sanitizeData(raw: any): PlayerData
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end

	if type(raw.money) == "number" then
		data.money = math.max(0, math.floor(raw.money))
	end

	for plantId, _ in pairs(PlantDefinitions) do
		if type(raw.seeds) == "table" and type(raw.seeds[plantId]) == "number" then
			data.seeds[plantId] = math.max(0, math.floor(raw.seeds[plantId]))
		end
		if type(raw.harvest) == "table" and type(raw.harvest[plantId]) == "number" then
			data.harvest[plantId] = math.max(0, math.floor(raw.harvest[plantId]))
		end
	end

	if type(raw.unlocks) == "table" then
		for key, value in pairs(raw.unlocks) do
			if type(key) == "string" and type(value) == "boolean" then
				data.unlocks[key] = value
			end
		end
	end

	if type(raw.stats) == "table" then
		if type(raw.stats.totalHarvested) == "number" then
			data.stats.totalHarvested = math.max(0, math.floor(raw.stats.totalHarvested))
		end
		if type(raw.stats.totalSold) == "number" then
			data.stats.totalSold = math.max(0, math.floor(raw.stats.totalSold))
		end
	end

	return data
end

local function keyForPlayer(userId: number): string
	return string.format("player_%d", userId)
end

local function runWithRetry(fn: () -> any)
	local attempt = 1
	while attempt <= MAX_RETRY do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn("[PlayerDataService] DataStore attempt failed:", result)
		attempt += 1
		task.wait(RETRY_WAIT * attempt)
	end
	return false, nil
end

function PlayerDataService:LoadPlayer(player: Player)
	local success, data = runWithRetry(function()
		return PROFILE_STORE:GetAsync(keyForPlayer(player.UserId))
	end)

	if success then
		sessionData[player] = sanitizeData(data)
	else
		sessionData[player] = defaultData()
	end
end

function PlayerDataService:SavePlayer(player: Player)
	if saveDebounce[player] then
		return
	end
	local data = sessionData[player]
	if not data then
		return
	end

	saveDebounce[player] = true
	runWithRetry(function()
		PROFILE_STORE:SetAsync(keyForPlayer(player.UserId), data)
	end)
	task.delay(2, function()
		saveDebounce[player] = nil
	end)
end

function PlayerDataService:Get(player: Player): PlayerData?
	return sessionData[player]
end

function PlayerDataService:AdjustMoney(player: Player, delta: number): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	if data.money + delta < 0 then
		return false
	end
	data.money = math.max(0, math.floor(data.money + delta))
	return true
end

function PlayerDataService:AdjustSeed(player: Player, plantId: string, delta: number): boolean
	local data = sessionData[player]
	if not data or data.seeds[plantId] == nil then
		return false
	end
	if data.seeds[plantId] + delta < 0 then
		return false
	end
	data.seeds[plantId] = math.max(0, math.floor(data.seeds[plantId] + delta))
	return true
end

function PlayerDataService:AdjustHarvest(player: Player, plantId: string, delta: number): boolean
	local data = sessionData[player]
	if not data or data.harvest[plantId] == nil then
		return false
	end
	if data.harvest[plantId] + delta < 0 then
		return false
	end
	data.harvest[plantId] = math.max(0, math.floor(data.harvest[plantId] + delta))
	if delta > 0 then
		data.stats.totalHarvested += delta
	end
	return true
end

function PlayerDataService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:LoadPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayer(player)
		sessionData[player] = nil
		saveDebounce[player] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:SavePlayer(player)
		end
	end)
end

return setmetatable({}, PlayerDataService)
