
-- Services --

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");

-- Variables --

local LockService = require(ReplicatedStorage:FindFirstChild("Common"):FindFirstChild("LockService_V2"));
local event = ReplicatedStorage:WaitForChild("RemoteEvent");


local keys = LockService:GetKeys();
LockService:FireLock(event, "Hello World", keys[1]);