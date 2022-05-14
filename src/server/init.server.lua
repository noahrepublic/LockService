
-- Services --

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");

-- Variables --

local LockService = require(ReplicatedStorage:FindFirstChild("Common"):FindFirstChild("LockService_V2"));

local event = ReplicatedStorage:WaitForChild("RemoteEvent");

local function doSomething(player, params)
    print(player, params);
end


LockService:LockEvent(event, doSomething);