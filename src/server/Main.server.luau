-- Server entry point. Wires the modules together when the game starts.

local Players = game:GetService("Players")

local Gathering = require(script.Parent.Gathering)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)
local Remotes = require(script.Parent.Remotes)

-- The client asks for its data once when it starts.
Remotes.GetData.OnServerInvoke = function(player)
	return PlayerData.WaitFor(player)
end

local function onPlayerAdded(player: Player)
	Progression.CreateLeaderstats(player)
	local data = PlayerData.Load(player)
	if not data then
		return
	end
	Progression.Sync(player)
	-- Give the client a moment to build its UI so the reward banner is seen.
	task.delay(3, function()
		if player.Parent then
			Progression.CheckDailyReward(player)
			Progression.Sync(player)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(PlayerData.Release)

Gathering.Start()
