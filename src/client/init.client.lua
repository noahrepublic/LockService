
-- Services --

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");

-- Variables --

local LockService = require(ReplicatedStorage:FindFirstChild("Common"):FindFirstChild("LockService_V2"));
local event = ReplicatedStorage:WaitForChild("RemoteEvent");

while task.wait(10) do
    print("FiredLockEvent")
    local keys = LockService:GetKeys();
    print(keys)
    LockService:FireLock(event, "Hello World", keys[1]);
end