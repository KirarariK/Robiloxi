--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = {}

local function root(): Folder
	local f = ReplicatedStorage:FindFirstChild("StealASnake")
	assert(f and f:IsA("Folder"), "StealASnake missing")
	return f
end

function Network.folder(): Folder
	local r = root()
	local rem = r:FindFirstChild("Remotes")
	if rem and rem:IsA("Folder") then
		return rem
	end
	rem = Instance.new("Folder")
	rem.Name = "Remotes"
	rem.Parent = r
	return rem
end

function Network.event(name: string): RemoteEvent
	local folder = Network.folder()
	local e = folder:FindFirstChild(name)
	if e and e:IsA("RemoteEvent") then
		return e
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

function Network.func(name: string): RemoteFunction
	local folder = Network.folder()
	local e = folder:FindFirstChild(name)
	if e and e:IsA("RemoteFunction") then
		return e
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = folder
	return created
end

function Network.setupServer()
	local names = {
		"DataUpdate",
		"Alert",
		"CarryState",
		"RequestDrop",
		"RequestSteal",
		"RequestCollect",
		"RequestTreadmillUpgrade",
		"RequestSell",
		"RequestPickupVivarium",
		"RequestFusion",
		"RequestRebirth",
		"VFX",
		"OpenUI",
		"GuardianAggro",
		"ShopBuy",
		"ClaimDaily",
		"ClaimGift",
		"ShopFeed",
	}
	for _, n in names do
		Network.event(n)
	end
	Network.func("GetData")
	Network.func("RedeemCode")
end

return Network
