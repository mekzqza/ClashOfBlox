-- !stict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	STATUS_POINT = "Attachment",
}

export type ProgresiveData = {
	Endtime: number,
	Cuurentime: number,

	StatusBar: BillboardGui,
	FillBar: Frame,
	TimeCountDown: TextLabel,
}

local BuilderHutController = {}
BuilderHutController.__index = BuilderHutController
function BuilderHutController.new()
	local self = setmetatable({}, BuilderHutController)
	self._BuildingController = nil
	self._BuilderStatusTemplate = nil

	self._BuilderStatusStore = {} :: { [Model]: ProgresiveData }

	return self
end

function BuilderHutController:SetDependencies(locator)
	self._BuildingController = locator:Get("BuildingController")
end

function BuilderHutController:RegisterBuildingProgressBar(model: Model, endTime: number, currenTtime: number)
	local statusPart = model:FindFirstChild(CONFIG.STATUS_POINT, true)
	if not statusPart then
		warn(`[BuilderHutController] Cannot find {CONFIG.STATUS_POINT} in building model ${model.Name}`)
		return
	end

	local statusGui = self._BuilderStatusTemplate:Clone()
	statusGui.Parent = statusPart

	local MainFrame = statusGui:FindFirstChild("MainFrame") :: Frame
	local ProgressiveBar = MainFrame:FindFirstChild("ProgressiveBar") :: Frame
	local TimeCountDown = MainFrame:FindFirstChild("TimeCountDown") :: TextLabel
	local Fill = ProgressiveBar:FindFirstChild("Fill", true) :: Frame
	local Counter = TimeCountDown:FindFirstChild("Counter", true) :: TextLabel

	self._BuilderStatusStore[model] = {
		Endtime = endTime,
		Cuurentime = currenTtime,
		StatusBar = statusGui,

		FillBar = Fill,
		TimeCountDown = Counter,
	}
end

function BuilderHutController:UpdateBuildingProgressBar(model: Model)
	local data = self._BuilderStatusStore[model]
	if not data then
		warn(`[BuilderHutController] No progress bar registered for building model ${model.Name}`)
		return
	end

	local currentTime = os.time()
	local remainingTime = math.max(0, data.Endtime - currentTime)
	local totalTime = math.max(1, data.Endtime - data.Cuurentime)
	local fillAmount = 1 - (remainingTime / totalTime)

	data.FillBar.Size = UDim2.new(fillAmount, 0, 1, 0)
	data.TimeCountDown.Text = tostring(remainingTime) .. "s"
end

function BuilderHutController:BuildingComplated(model: Model)
	if self._BuilderStatusStore[model] then
		self._BuilderStatusStore[model].StatusBar:Destroy()
		self._BuilderStatusStore[model] = nil
	end
end

function BuilderHutController:Init()
	local Assets = ReplicatedStorage:WaitForChild("Assets")

	self._BuilderStatusTemplate = Assets:WaitForChild("UI"):WaitForChild("BuilderStatus")
	if not self._BuilderStatusTemplate then
		warn("[BuilderHutController] Cannot find BuilderStatus template in ReplicatedStorage.Assets.UI")
		return
	end
end

function BuilderHutController:Start() end

return BuilderHutController.new()
