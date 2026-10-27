-- All the on-screen feedback: inventory panel, level bar, pop-ups, banners, sounds.
-- The UI is built in code so it works without making anything in Studio.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local remoteFolder = ReplicatedStorage:WaitForChild("Remotes")
local Remotes = {
	DataSync = remoteFolder:WaitForChild("DataSync"),
	Gathered = remoteFolder:WaitForChild("Gathered"),
	LevelUp = remoteFolder:WaitForChild("LevelUp"),
	DailyReward = remoteFolder:WaitForChild("DailyReward"),
	GetData = remoteFolder:WaitForChild("GetData"),
}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

-- Swap these for any sound from the Creator Store (use "rbxassetid://12345").
local SOUNDS = {
	Pickup = "rbxasset://sounds/electronicpingshort.wav",
	Big = "rbxasset://sounds/electronicpingshort.wav",
}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function make(className: string, props: { [string]: any }, children: { Instance }?)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(thickness: number)
	return make("UIStroke", { Thickness = thickness, Color = Color3.new(0, 0, 0), Transparency = 0.2 })
end

local function tween(inst: Instance, seconds: number, goal, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function playSound(id: string, pitch: number?, volume: number?)
	local sound = make("Sound", {
		SoundId = id,
		PlaybackSpeed = pitch or 1,
		Volume = volume or 0.5,
		Parent = SoundService,
	})
	sound:Play()
	Debris:AddItem(sound, 3)
end

---------------------------------------------------------------------------
-- Screen layout
---------------------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = "IslandHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Inventory panel (bottom left)
local inventoryPanel = make("Frame", {
	Name = "Inventory",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(190, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(25, 40, 55),
	BackgroundTransparency = 0.25,
	Parent = gui,
}, {
	corner(12),
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local rows = {}
for i, name in Config.ResourceOrder do
	local info = Config.Resources[name]
	local row = make("Frame", {
		Name = name,
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		-- Rare items stay hidden until you find your first one.
		Visible = not info.Rare,
		Parent = inventoryPanel,
	})
	local scale = make("UIScale", { Parent = row })
	make("TextLabel", {
		Size = UDim2.new(0.65, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = info.Icon .. " " .. name,
		Parent = row,
	}, { stroke(1.5) })
	local count = make("TextLabel", {
		Position = UDim2.fromScale(0.65, 0),
		Size = UDim2.new(0.35, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = info.Color,
		Text = "0",
		Parent = row,
	}, { stroke(1.5) })
	rows[name] = { Row = row, Scale = scale, Count = count, Shown = 0 }
end

-- Level + XP bar (top middle)
local levelFrame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(320, 44),
	BackgroundTransparency = 1,
	Parent = gui,
})
local levelScale = make("UIScale", { Parent = levelFrame })
local levelLabel = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 20,
	TextColor3 = Color3.fromRGB(255, 230, 120),
	Text = "Level 1",
	Parent = levelFrame,
}, { stroke(1.5) })
local barBack = make("Frame", {
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundColor3 = Color3.fromRGB(25, 40, 55),
	BackgroundTransparency = 0.2,
	Parent = levelFrame,
}, { corner(8) })
local barFill = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(120, 220, 110),
	Parent = barBack,
}, { corner(8) })
local xpLabel = make("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 13,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
	ZIndex = 2,
	Parent = barBack,
}, { stroke(1) })

---------------------------------------------------------------------------
-- Updating from data
---------------------------------------------------------------------------

local function bounce(scale: UIScale, size: number)
	scale.Scale = size
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Count up smoothly instead of jumping, it feels more rewarding.
local function rollNumber(row, target: number)
	local from = row.Shown
	row.Shown = target
	if target == from then
		row.Count.Text = tostring(target)
		return
	end
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(function(v)
		row.Count.Text = tostring(math.floor(v + 0.5))
	end)
	tween(value, 0.4, { Value = target }).Completed:Connect(function()
		row.Count.Text = tostring(target)
		value:Destroy()
	end)
	if target > from then
		bounce(row.Scale, 1.25)
	end
end

local currentLevel = nil
local function applyData(data)
	if not data then
		return
	end
	for name, row in rows do
		local amount = data.Inventory[name] or 0
		if amount > 0 and not row.Row.Visible then
			row.Row.Visible = true
		end
		rollNumber(row, amount)
	end

	local needed = Config.XPToNextLevel(data.Level)
	levelLabel.Text = "Level " .. data.Level
	xpLabel.Text = data.XP .. " / " .. needed .. " XP"
	if currentLevel and data.Level > currentLevel then
		barFill.Size = UDim2.fromScale(0, 1) -- start the new level's bar from empty
	end
	currentLevel = data.Level
	tween(barFill, 0.3, { Size = UDim2.fromScale(math.clamp(data.XP / needed, 0, 1), 1) })
end

---------------------------------------------------------------------------
-- World pop-ups and effects
---------------------------------------------------------------------------

local function floatingText(position: Vector3, text: string, color: Color3, size: number, delay: number)
	task.delay(delay, function()
		local anchor = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Transparency = 1,
			Size = Vector3.one * 0.2,
			Position = position,
			Parent = workspace,
		})
		local billboard = make("BillboardGui", {
			Size = UDim2.fromOffset(220, 50),
			StudsOffset = Vector3.new(0, 2, 0),
			AlwaysOnTop = true,
			Adornee = anchor,
			Parent = anchor,
		})
		local label = make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = size,
			TextColor3 = color,
			Text = text,
			Parent = billboard,
		}, { stroke(2) })
		local scale = make("UIScale", { Scale = 0.3, Parent = label })

		tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(billboard, 1.1, { StudsOffset = Vector3.new(0, 6, 0) })
		task.delay(0.6, function()
			tween(label, 0.5, { TextTransparency = 1 })
			local s = label:FindFirstChildOfClass("UIStroke")
			if s then
				tween(s, 0.5, { Transparency = 1 })
			end
		end)
		Debris:AddItem(anchor, 1.3)
	end)
end

local function burst(position: Vector3, color: Color3, count: number)
	for _ = 1, count do
		local chip = make("Part", {
			Size = Vector3.one * math.random(3, 6) / 10,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Position = position + Vector3.new(0, 2, 0),
			Parent = workspace,
		})
		chip.AssemblyLinearVelocity =
			Vector3.new(math.random(-14, 14), math.random(14, 26), math.random(-14, 14))
		chip.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), 0)
		tween(chip, 0.8, { Size = Vector3.zero, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(chip, 0.9)
	end
end

---------------------------------------------------------------------------
-- Center banners (level up, rare find, daily reward), one at a time
---------------------------------------------------------------------------

local bannerQueue = {}
local bannerBusy = false

local function showNextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local b = table.remove(bannerQueue, 1)

	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(600, 90),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 48,
		TextColor3 = b.Color,
		Text = b.Title,
		Parent = gui,
	}, { stroke(3) })
	local sub = make("TextLabel", {
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		Text = b.Subtitle or "",
		Parent = label,
	}, { stroke(2) })
	local scale = make("UIScale", { Scale = 0.2, Parent = label })

	playSound(SOUNDS.Big, 0.7, 0.8)
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(1.8)
	tween(label, 0.4, { TextTransparency = 1 })
	tween(sub, 0.4, { TextTransparency = 1 })
	for _, s in { label:FindFirstChildOfClass("UIStroke"), sub:FindFirstChildOfClass("UIStroke") } do
		tween(s, 0.4, { Transparency = 1 })
	end
	task.wait(0.45)
	label:Destroy()

	bannerBusy = false
	showNextBanner()
end

local function banner(title: string, subtitle: string?, color: Color3)
	table.insert(bannerQueue, { Title = title, Subtitle = subtitle, Color = color })
	task.spawn(showNextBanner)
end

---------------------------------------------------------------------------
-- Listen to the server
---------------------------------------------------------------------------

-- Gathering quickly in a row raises the pickup sound's pitch (a "combo").
local combo = 0
local lastGather = 0

Remotes.Gathered.OnClientEvent:Connect(function(info)
	local now = os.clock()
	combo = (now - lastGather < 2.5) and math.min(combo + 1, 10) or 0
	lastGather = now
	playSound(SOUNDS.Pickup, 1 + combo * 0.06, 0.45)

	burst(info.Position, info.Color, info.Final and 14 or 6)

	local line = 0
	for _, name in Config.ResourceOrder do
		local amount = info.Items[name]
		if amount then
			local res = Config.Resources[name]
			floatingText(info.Position, "+" .. amount .. " " .. res.Icon .. " " .. name, res.Color, 30, line * 0.15)
			line += 1
		end
	end
	if info.Lucky then
		floatingText(info.Position + Vector3.new(0, 2, 0), "LUCKY x2!", Color3.fromRGB(255, 215, 60), 36, 0.1)
	end
	if info.Rare then
		local res = Config.Resources[info.Rare]
		banner("RARE FIND!", res.Icon .. " " .. info.Rare, res.Color)
	end
end)

Remotes.LevelUp.OnClientEvent:Connect(function(level)
	bounce(levelScale, 1.4)
	banner("LEVEL UP!", "You reached level " .. level, Color3.fromRGB(255, 230, 120))
end)

Remotes.DailyReward.OnClientEvent:Connect(function(streak, reward)
	local parts = {}
	for _, name in Config.ResourceOrder do
		if reward[name] then
			table.insert(parts, "+" .. reward[name] .. " " .. Config.Resources[name].Icon)
		end
	end
	banner(
		"DAY " .. streak .. " STREAK!",
		table.concat(parts, "  ") .. "  (come back tomorrow for more)",
		Color3.fromRGB(255, 160, 80)
	)
end)

Remotes.DataSync.OnClientEvent:Connect(applyData)
applyData(Remotes.GetData:InvokeServer())
