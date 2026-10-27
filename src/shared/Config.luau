-- Game tuning lives here so you can tweak numbers without touching game logic.
-- Both the server and the client read this file.

local Config = {}

-- Every item a player can collect. Order = order shown in the inventory panel.
Config.ResourceOrder = { "Wood", "Stone", "Coconut", "Gem" }

Config.Resources = {
	Wood = { Icon = "🪵", Color = Color3.fromRGB(196, 138, 82) },
	Stone = { Icon = "🪨", Color = Color3.fromRGB(170, 175, 185) },
	Coconut = { Icon = "🥥", Color = Color3.fromRGB(140, 100, 60), Rare = true },
	Gem = { Icon = "💎", Color = Color3.fromRGB(90, 220, 255), Rare = true },
}

-- Things in the world you can gather from.
-- In Studio, name a Part or Model "Tree" or "Rock" (or give it the tag "Tree"/"Rock")
-- and it becomes gatherable automatically.
Config.Nodes = {
	Tree = {
		ActionText = "Chop",
		Resource = "Wood",
		Hits = 3, -- how many times you can gather before it disappears
		AmountPerHit = { 1, 3 }, -- random amount between these two numbers
		FinalHitBonus = 3, -- extra on the last hit, feels good to finish a tree
		XPPerHit = 4,
		HoldDuration = 0.35,
		RespawnSeconds = 20,
		RareDrop = { Resource = "Coconut", Chance = 0.15, Amount = 1 }, -- rolled on final hit
	},
	Rock = {
		ActionText = "Mine",
		Resource = "Stone",
		Hits = 4,
		AmountPerHit = { 1, 2 },
		FinalHitBonus = 3,
		XPPerHit = 5,
		HoldDuration = 0.5,
		RespawnSeconds = 30,
		RareDrop = { Resource = "Gem", Chance = 0.08, Amount = 1 },
	},
}

-- Chance that any single hit is "LUCKY" and gives double.
Config.LuckyChance = 0.1

-- XP needed to go from `level` to `level + 1`. Gets a bit harder each level.
function Config.XPToNextLevel(level: number): number
	return 20 + level * 15
end

-- Daily login reward. Streak goes up each day in a row, resets if you miss a day.
Config.DailyRewardMaxStreak = 7
function Config.DailyReward(streak: number)
	local day = math.min(streak, Config.DailyRewardMaxStreak)
	local reward = { Wood = 5 * day, Stone = 3 * day }
	if day >= Config.DailyRewardMaxStreak then
		reward.Gem = 1
	end
	return reward
end

return Config
