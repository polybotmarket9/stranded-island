-- Turns every Tree and Rock in the world into something you can gather from.
--
-- How to add more in Studio: name a Part or Model "Tree" or "Rock", or add the
-- tag "Tree"/"Rock" to it (Properties > Tags). It picks them up automatically,
-- even ones added while the game is running.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(script.Parent.Progression)
local Remotes = require(script.Parent.Remotes)

local Gathering = {}

local setUp: { [Instance]: boolean } = {}
local random = Random.new()

local function partsOf(node: Instance): { BasePart }
	if node:IsA("BasePart") then
		return { node }
	end
	local parts = {}
	for _, d in node:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

local function mainPart(node: Instance): BasePart?
	if node:IsA("BasePart") then
		return node
	elseif node:IsA("Model") then
		return node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Hide a node when it's used up, and bring it back later.
local function setVisible(parts: { BasePart }, original, visible: boolean)
	for _, part in parts do
		if visible then
			part.CanCollide = original[part].CanCollide
			TweenService:Create(part, TweenInfo.new(0.4), { Transparency = original[part].Transparency }):Play()
		else
			part.CanCollide = false
			part.Transparency = 1
		end
	end
end

-- Little "wobble" so every hit feels like it did something.
local wobbling: { [Instance]: boolean } = {}
local function wobble(node: Instance, part: BasePart)
	if not part.Anchored or wobbling[node] then
		return
	end
	wobbling[node] = true
	local tilt = CFrame.Angles(math.rad(random:NextNumber(-5, 5)), 0, math.rad(random:NextNumber(-5, 5)))
	if node:IsA("Model") then
		local start = node:GetPivot()
		node:PivotTo(start * tilt)
		task.delay(0.08, function()
			node:PivotTo(start)
			wobbling[node] = nil
		end)
	else
		local start = part.CFrame
		part.CFrame = start * tilt
		task.delay(0.08, function()
			part.CFrame = start
			wobbling[node] = nil
		end)
	end
end

function Gathering.SetupNode(node: Instance, kind: string)
	local cfg = Config.Nodes[kind]
	local part = mainPart(node)
	if not cfg or not part or setUp[node] then
		return
	end
	setUp[node] = true

	local parts = partsOf(node)
	local original = {}
	for _, p in parts do
		original[p] = { Transparency = p.Transparency, CanCollide = p.CanCollide }
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = cfg.ActionText
	prompt.ObjectText = kind
	prompt.HoldDuration = cfg.HoldDuration
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local hitsLeft = cfg.Hits
	local lastHit: { [Player]: number } = {}

	prompt.Triggered:Connect(function(player)
		if hitsLeft <= 0 then
			return
		end
		-- Small per-player cooldown so nobody can spam it.
		local now = os.clock()
		if lastHit[player] and now - lastHit[player] < 0.2 then
			return
		end
		lastHit[player] = now

		hitsLeft -= 1
		local isFinal = hitsLeft <= 0

		local amount = random:NextInteger(cfg.AmountPerHit[1], cfg.AmountPerHit[2])
		local lucky = random:NextNumber() < Config.LuckyChance
		if lucky then
			amount *= 2
		end
		if isFinal then
			amount += cfg.FinalHitBonus
		end

		local items = { [cfg.Resource] = amount }
		local rare = nil
		if isFinal and cfg.RareDrop and random:NextNumber() < cfg.RareDrop.Chance then
			rare = cfg.RareDrop.Resource
			items[rare] = (items[rare] or 0) + cfg.RareDrop.Amount
		end

		Progression.GiveItems(player, items)
		Progression.GiveXP(player, cfg.XPPerHit * (isFinal and 2 or 1))
		Progression.Sync(player)

		Remotes.Gathered:FireClient(player, {
			Items = items,
			Position = part.Position,
			Lucky = lucky,
			Rare = rare,
			Final = isFinal,
			Color = part.Color,
		})

		if isFinal then
			prompt.Enabled = false
			setVisible(parts, original, false)
			task.delay(cfg.RespawnSeconds, function()
				hitsLeft = cfg.Hits
				setVisible(parts, original, true)
				prompt.Enabled = true
			end)
		else
			wobble(node, part)
		end
	end)
end

-- If the map has no trees or rocks yet, drop a few near spawn so the
-- game is playable on an empty Baseplate. Delete this once you build your island.
local function groundY(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return result and result.Position.Y or 0
end

local function spawnDemoNodes()
	local folder = Instance.new("Folder")
	folder.Name = "DemoNodes"

	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local x, z = math.cos(angle) * 28, math.sin(angle) * 28
		local y = groundY(x, z)

		local tree = Instance.new("Model")
		tree.Name = "Tree"
		local trunk = Instance.new("Part")
		trunk.Name = "Trunk"
		trunk.Anchored = true
		trunk.Size = Vector3.new(2, 12, 2)
		trunk.Position = Vector3.new(x, y + 6, z)
		trunk.Color = Color3.fromRGB(120, 80, 45)
		trunk.Material = Enum.Material.Wood
		trunk.Parent = tree
		local leaves = Instance.new("Part")
		leaves.Name = "Leaves"
		leaves.Anchored = true
		leaves.Shape = Enum.PartType.Ball
		leaves.Size = Vector3.new(9, 9, 9)
		leaves.Position = Vector3.new(x, y + 13, z)
		leaves.Color = Color3.fromRGB(70, 170, 70)
		leaves.Material = Enum.Material.Grass
		leaves.Parent = tree
		tree.PrimaryPart = trunk
		tree.Parent = folder
	end

	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + 0.4
		local x, z = math.cos(angle) * 16, math.sin(angle) * 16
		local rock = Instance.new("Part")
		rock.Name = "Rock"
		rock.Anchored = true
		rock.Size = Vector3.new(5, 4, 5)
		rock.Position = Vector3.new(x, groundY(x, z) + 2, z)
		rock.Orientation = Vector3.new(0, random:NextNumber(0, 90), 10)
		rock.Color = Color3.fromRGB(130, 130, 140)
		rock.Material = Enum.Material.Slate
		rock.Parent = folder
	end

	folder.Parent = workspace
end

local function tryAdd(instance: Instance)
	if Config.Nodes[instance.Name] and (instance:IsA("Model") or instance:IsA("BasePart")) then
		-- Skip parts that are inside another node (e.g. a tree's leaves).
		local parent = instance.Parent
		while parent and parent ~= workspace do
			if Config.Nodes[parent.Name] then
				return
			end
			parent = parent.Parent
		end
		Gathering.SetupNode(instance, instance.Name)
	end
end

function Gathering.Start()
	for kind in Config.Nodes do
		for _, tagged in CollectionService:GetTagged(kind) do
			Gathering.SetupNode(tagged, kind)
		end
		CollectionService:GetInstanceAddedSignal(kind):Connect(function(tagged)
			Gathering.SetupNode(tagged, kind)
		end)
	end

	for _, d in workspace:GetDescendants() do
		tryAdd(d)
	end
	workspace.DescendantAdded:Connect(tryAdd)

	if next(setUp) == nil then
		spawnDemoNodes()
	end
end

return Gathering
