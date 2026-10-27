-- Loads, keeps, and saves each player's progress with DataStoreService.
--
-- To test saving in Studio: Game Settings > Security > turn on
-- "Enable Studio Access to API Services". The game must be published first.
-- Without it, the game still runs, it just won't remember anything.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

-- Change the version suffix to give everyone a fresh start.
local STORE_NAME = "IslandPlayerData_v1"
local AUTOSAVE_SECONDS = 60
local RETRIES = 3

local TEMPLATE = {
	Inventory = {},
	Level = 1,
	XP = 0,
	TotalGathered = 0,
	LastLoginDay = 0,
	LoginStreak = 0,
}
for _, name in Config.ResourceOrder do
	TEMPLATE.Inventory[name] = 0
end

local store: DataStore? = nil
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStores unavailable, progress will not save:", result)
	end
end

local PlayerData = {}

-- player -> data table
local cache: { [Player]: any } = {}
-- players whose data loaded correctly. We only save these, so a failed load
-- never overwrites someone's real save with an empty one.
local canSave: { [Player]: boolean } = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fill in any fields the save is missing (for example after you add a new resource).
local function reconcile(data, template)
	for key, default in template do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and type(data[key]) == "table" then
			reconcile(data[key], default)
		end
	end
	return data
end

local function withRetries(fn)
	local ok, result
	for attempt = 1, RETRIES do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	return false, result
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function PlayerData.Load(player: Player)
	local data
	if store then
		local ok, result = withRetries(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			data = result
			canSave[player] = true
		else
			warn("[PlayerData] Could not load", player.Name, result)
		end
	end

	if not player.Parent then
		canSave[player] = nil
		return nil -- left while loading
	end

	cache[player] = reconcile(type(data) == "table" and data or {}, TEMPLATE)
	return cache[player]
end

function PlayerData.Get(player: Player)
	return cache[player]
end

-- Waits (up to `timeout` seconds) for a player's data to finish loading.
function PlayerData.WaitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 15)
	while not cache[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return cache[player]
end

function PlayerData.Save(player: Player)
	local data = cache[player]
	if not (store and data and canSave[player]) then
		return
	end
	local ok, err = withRetries(function()
		store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[PlayerData] Could not save", player.Name, err)
	end
end

function PlayerData.Release(player: Player)
	PlayerData.Save(player)
	cache[player] = nil
	canSave[player] = nil
end

-- Autosave everyone regularly so a crash loses at most a minute.
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for _, player in Players:GetPlayers() do
			task.spawn(PlayerData.Save, player)
		end
	end
end)

-- Save everyone when the server shuts down.
game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			PlayerData.Save(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

return PlayerData
