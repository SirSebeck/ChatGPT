--!strict
local RunService = game:GetService("RunService")

local TimeService = {}
TimeService.__index = TimeService

TimeService.MonthChanged = Instance.new("BindableEvent")
TimeService.MonthProgressChanged = Instance.new("BindableEvent")

local MONTH_SECONDS = 20 * 60
local SLEEP_COST = 15
local SLEEP_COOLDOWN_SECONDS = 20

local state = {
	currentMonth = 3,
	currentYear = 2026,
	monthElapsed = 0,
	monthProgress = 1,
	lastSleepTimeByUserId = {} :: {[number]: number},
}

local economyService = nil

function TimeService:BindEconomyService(service)
	economyService = service
end

function TimeService:GetCurrentDate()
	return state.currentMonth, state.currentYear
end

function TimeService:GetMonthProgress(): number
	return state.monthProgress
end

local function advanceMonth()
	state.currentMonth += 1
	if state.currentMonth > 12 then
		state.currentMonth = 1
		state.currentYear += 1
	end
	state.monthElapsed = 0
	state.monthProgress = 1
	TimeService.MonthChanged:Fire(state.currentMonth, state.currentYear)
	TimeService.MonthProgressChanged:Fire(state.monthProgress)
end

function TimeService:RequestSleepNextMonth(player: Player): (boolean, string)
	local now = os.clock()
	local userId = player.UserId
	local lastSleep = state.lastSleepTimeByUserId[userId] or 0
	if now - lastSleep < SLEEP_COOLDOWN_SECONDS then
		return false, "Sleep is on cooldown"
	end

	if economyService then
		local ok = economyService:SpendMoney(player, SLEEP_COST)
		if not ok then
			return false, "Not enough money for sleep"
		end
	end

	state.lastSleepTimeByUserId[userId] = now
	advanceMonth()
	return true, "Slept to next month"
end

function TimeService:Init()
	RunService.Heartbeat:Connect(function(dt)
		state.monthElapsed += dt
		state.monthProgress = math.clamp(1 - (state.monthElapsed / MONTH_SECONDS), 0, 1)
		TimeService.MonthProgressChanged:Fire(state.monthProgress)

		if state.monthElapsed >= MONTH_SECONDS then
			advanceMonth()
		end
	end)
end

return setmetatable({}, TimeService)
