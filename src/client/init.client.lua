
-- Services --

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");

-- Variables --

--[[local LockService = require(ReplicatedStorage:FindFirstChild("Common"):FindFirstChild("LockService"));
local event = ReplicatedStorage:WaitForChild("RemoteEvent");

ReplicatedStorage:WaitForChild("Common"):WaitForChild("LockService"):FindFirstChild("Salt");


while task.wait(1) do
    LockService.KeyRemote(event, "test");
end
]]