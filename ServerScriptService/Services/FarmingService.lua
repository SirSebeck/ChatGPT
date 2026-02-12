--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlantDefinitions = require(ReplicatedStorage.Shared.PlantDefinitions)

local FarmingService = {}
FarmingService.__index = FarmingService

local playerDataService = nil
local timeService = nil

-- Growth/Yield tuning for simple but clear gameplay rules.
local MULTIPLIER_FULL_MATCH = {growth = 1.6, yield = 1.5}
local MULTIPLIER_PARTIAL_MATCH = {growth = 1.1, yield = 1.1}
local MULTIPLIER_NO_MATCH = {growth = 0.7, yield = 0.7}

-- Prepared hook for later weather events (not forced in prototype).
local weatherEventState = {
	active = false,
	type = "NONE", -- e.g. HEATWAVE, DROUGHT
	growthMultiplier = 1,
	yieldMultiplier = 1,
}

local function hasMonth(months: {number}, target: number): boolean
	for _, m in ipairs(months) do
		if m == target then
			return true
		end
	end
	return false
end

local function ensureCropFolder(fieldInstance: Instance): Folder
	local existing = fieldInstance:FindFirstChild("Crops")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Crops"
	folder.Parent = fieldInstance
	return folder
end

local function computeMatchMultipliers(plantDef, fieldType: string, month: number)
	local monthMatch = hasMonth(plantDef.plantWindowMonths, month)
	local fieldMatch = plantDef.idealFieldType == fieldType
	if monthMatch and fieldMatch then
		return MULTIPLIER_FULL_MATCH.growth, MULTIPLIER_FULL_MATCH.yield
	elseif monthMatch or fieldMatch then
		return MULTIPLIER_PARTIAL_MATCH.growth, MULTIPLIER_PARTIAL_MATCH.yield
	else
		return MULTIPLIER_NO_MATCH.growth, MULTIPLIER_NO_MATCH.yield
	end
end

local function createCropModel(plantId: string, ownerUserId: number): Model
	local model = Instance.new("Model")
	model.Name = string.format("Crop_%s", plantId)

	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(1, 1, 1)
	stem.Anchored = true
	stem.CanCollide = false
	stem.Material = Enum.Material.Grass
	stem.Color = Color3.fromRGB(61, 153, 61)
	stem.Parent = model

	model:SetAttribute("ownerUserId", ownerUserId)
	return model
end

local function getFieldType(fieldInstance: Instance): string?
	if fieldInstance:GetAttribute("FieldType") then
		return fieldInstance:GetAttribute("FieldType")
	end
	return nil
end

function FarmingService:Init(dependencies)
	playerDataService = dependencies.PlayerDataService
	timeService = dependencies.TimeService

	timeService.MonthChanged.Event:Connect(function(newMonth)
		self:UpdateGrowthForAllFields(newMonth)
	end)
end

function FarmingService:CanPlantOnField(player: Player, fieldInstance: Instance): (boolean, string)
	if not fieldInstance or not fieldInstance:IsDescendantOf(Workspace) then
		return false, "Invalid field"
	end
	local ownerUserId = fieldInstance:GetAttribute("OwnerUserId")
	if ownerUserId ~= nil and ownerUserId ~= player.UserId then
		return false, "Not your field"
	end
	if not getFieldType(fieldInstance) then
		return false, "Field type missing"
	end
	local crops = ensureCropFolder(fieldInstance)
	if #crops:GetChildren() > 0 then
		return false, "Field already occupied"
	end
	return true, "ok"
end

function FarmingService:PlantSeed(player: Player, fieldInstance: Instance, plantId: string): (boolean, string)
	local plantDef = PlantDefinitions[plantId]
	if not plantDef then
		return false, "Unknown plant"
	end

	local canPlant, reason = self:CanPlantOnField(player, fieldInstance)
	if not canPlant then
		return false, reason
	end

	local data = playerDataService:Get(player)
	if not data then
		return false, "Player data missing"
	end
	if (data.seeds[plantId] or 0) < 1 then
		return false, "No seeds available"
	end

	local currentMonth, currentYear = timeService:GetCurrentDate()
	local fieldType = getFieldType(fieldInstance) :: string
	local growthMult, yieldMult = computeMatchMultipliers(plantDef, fieldType, currentMonth)
	growthMult *= weatherEventState.growthMultiplier
	yieldMult *= weatherEventState.yieldMultiplier

	playerDataService:AdjustSeed(player, plantId, -1)

	local crop = createCropModel(plantId, player.UserId)
	local cropsFolder = ensureCropFolder(fieldInstance)
	crop.Parent = cropsFolder

	crop:SetAttribute("plantId", plantId)
	crop:SetAttribute("plantedMonth", currentMonth)
	crop:SetAttribute("plantedYear", currentYear)
	crop:SetAttribute("growthProgress", 0)
	crop:SetAttribute("growthMultiplier", growthMult)
	crop:SetAttribute("yieldMultiplier", yieldMult)
	crop:SetAttribute("baseGrowMonths", plantDef.baseGrowMonths)
	crop:SetAttribute("isHarvested", false)

	return true, string.format("Planted %s", plantDef.displayName)
end

function FarmingService:UpdateGrowthForAllFields(_newMonth: number)
	local fieldsFolder = Workspace:FindFirstChild("TycoonFields")
	if not fieldsFolder then
		return
	end

	for _, field in ipairs(fieldsFolder:GetChildren()) do
		local cropsFolder = field:FindFirstChild("Crops")
		if cropsFolder then
			for _, crop in ipairs(cropsFolder:GetChildren()) do
				if crop:IsA("Model") and not crop:GetAttribute("isHarvested") then
					local progress = crop:GetAttribute("growthProgress") or 0
					local growthMult = crop:GetAttribute("growthMultiplier") or 1
					local baseGrowMonths = crop:GetAttribute("baseGrowMonths") or 3
					local progressDelta = (1 / baseGrowMonths) * growthMult
					crop:SetAttribute("growthProgress", math.clamp(progress + progressDelta, 0, 1))
				end
			end
		end
	end
end

function FarmingService:HarvestField(player: Player, fieldInstance: Instance): (boolean, string)
	if not fieldInstance then
		return false, "Invalid field"
	end

	local cropsFolder = fieldInstance:FindFirstChild("Crops")
	if not cropsFolder then
		return false, "No crop"
	end
	local crop = cropsFolder:FindFirstChildWhichIsA("Model")
	if not crop then
		return false, "No crop"
	end

	if crop:GetAttribute("ownerUserId") ~= player.UserId then
		return false, "Not your crop"
	end

	local plantId = crop:GetAttribute("plantId")
	local plantDef = PlantDefinitions[plantId]
	if not plantDef then
		return false, "Corrupted crop"
	end

	local growthProgress = crop:GetAttribute("growthProgress") or 0
	local currentMonth = select(1, timeService:GetCurrentDate())
	local inHarvestWindow = hasMonth(plantDef.harvestWindowMonths, currentMonth)
	if growthProgress < 1 and not inHarvestWindow then
		return false, "Crop not ready"
	end

	local yieldMult = crop:GetAttribute("yieldMultiplier") or 1
	local quantity = math.max(1, math.floor(plantDef.baseYield * yieldMult))
	playerDataService:AdjustHarvest(player, plantId, quantity)

	crop:Destroy()
	return true, string.format("Harvested %d x %s", quantity, plantDef.displayName)
end

return setmetatable({}, FarmingService)
