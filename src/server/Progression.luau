-- Everything that changes a player's progress goes through here:
-- giving items, giving XP, levelling up, and the daily login reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local Progression = {}

function Progression.Sync(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	Remotes.DataSync:FireClient(player, data)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = data.Level
	end
end

function Progression.CreateLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats" -- this exact name shows values on the player list
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = leaderstats
	leaderstats.Parent = player
end

-- items = { Wood = 3, Gem = 1 }
function Progression.GiveItems(player: Player, items: { [string]: number })
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	for name, amount in items do
		data.Inventory[name] = (data.Inventory[name] or 0) + amount
		data.TotalGathered += amount
	end
end

function Progression.GiveXP(player: Player, amount: number)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	data.XP += amount
	local levelsGained = 0
	while data.XP >= Config.XPToNextLevel(data.Level) do
		data.XP -= Config.XPToNextLevel(data.Level)
		data.Level += 1
		levelsGained += 1
	end
	if levelsGained > 0 then
		Remotes.LevelUp:FireClient(player, data.Level)
	end
end

local function currentDay(): number
	return math.floor(os.time() / 86400) -- days since 1970, in UTC
end

-- Call once when a player joins, after their data loads.
function Progression.CheckDailyReward(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local today = currentDay()
	if data.LastLoginDay == today then
		return -- already claimed today
	end

	if data.LastLoginDay == today - 1 then
		data.LoginStreak += 1
	else
		data.LoginStreak = 1
	end
	data.LastLoginDay = today

	local reward = Config.DailyReward(data.LoginStreak)
	Progression.GiveItems(player, reward)
	Remotes.DailyReward:FireClient(player, data.LoginStreak, reward)
end

return Progression
