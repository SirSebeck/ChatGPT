--!strict
-- Creates a minimal HUD tree at runtime if missing (prototype convenience).

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("MainHUD") then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "MainHUD"
gui.ResetOnSpawn = false
gui.Parent = playerGui

gui.IgnoreGuiInset = false
gui.DisplayOrder = 10

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.new(0, 360, 0, 240)
root.Position = UDim2.new(0, 18, 0, 18)
root.BackgroundColor3 = Color3.fromRGB(63, 96, 58)
root.Parent = gui

local function mkLabel(name: string, pos: UDim2, text: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = UDim2.new(0, 340, 0, 24)
	l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.GothamBold
	l.TextSize = 16
	l.Text = text
	l.Parent = root
	return l
end

local monthText = mkLabel("MonthText", UDim2.new(0, 10, 0, 8), "Mär 2026")
local moneyText = mkLabel("MoneyText", UDim2.new(0, 10, 0, 34), "€ 0")
local toastText = mkLabel("ToastText", UDim2.new(0, 10, 0, 60), "")
toastText.TextTransparency = 0.35

local progressBar = Instance.new("Frame")
progressBar.Name = "ProgressBarFrame"
progressBar.Size = UDim2.new(0, 340, 0, 20)
progressBar.Position = UDim2.new(0, 10, 0, 88)
progressBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
progressBar.Parent = root

local fill = Instance.new("Frame")
fill.Name = "FillFrame"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Color3.fromRGB(112, 227, 126)
fill.Parent = progressBar

local function mkButton(name: string, text: string, y: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(0, 160, 0, 28)
	b.Position = UDim2.new(0, 10, 0, y)
	b.Text = text
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
	b.Parent = root
	return b
end

mkButton("SleepButton", "Sleep to next Month", 120)
mkButton("OpenSeedShopButton", "Open Seed Shop", 154)
mkButton("OpenSellShopButton", "Open Sell Shop", 188)

local function mkShop(name: string, xOffset: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(0, 170, 0, 200)
	frame.Position = UDim2.new(0, xOffset, 0, 16)
	frame.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
	frame.Visible = false
	frame.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.Text = name
	title.Parent = frame

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.new(1, 0, 1, -24)
	list.Position = UDim2.new(0, 0, 0, 24)
	list.BackgroundTransparency = 1
	list.Parent = frame

	return frame
end

mkShop("SeedShopFrame", 186)
mkShop("SellShopFrame", 186)

-- Expose expected direct children for MainHUD.client.lua by cloning refs to gui root.
for _, name in ipairs({
	"MonthText", "MoneyText", "ToastText", "ProgressBarFrame", "SleepButton", "OpenSeedShopButton", "OpenSellShopButton", "SeedShopFrame", "SellShopFrame",
}) do
	local obj = root:FindFirstChild(name)
	if obj then
		obj.Parent = gui
	end
end

monthText.Parent = gui
moneyText.Parent = gui
toastText.Parent = gui
