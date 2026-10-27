-- Creates the RemoteEvents/RemoteFunctions the client listens to.
-- They live in ReplicatedStorage.Remotes so both sides can find them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function func(name: string): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {
	DataSync = event("DataSync"), -- server -> client: full data snapshot
	Gathered = event("Gathered"), -- server -> client: "you got stuff", for pop-ups
	LevelUp = event("LevelUp"), -- server -> client: new level reached
	DailyReward = event("DailyReward"), -- server -> client: login reward claimed
	GetData = func("GetData"), -- client -> server: ask for the first snapshot
}

folder.Parent = ReplicatedStorage

return Remotes
