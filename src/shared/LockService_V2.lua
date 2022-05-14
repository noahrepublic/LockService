-- Services --

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local RunService = game:GetService("RunService");
local HttpService = game:GetService("HttpService");

-- Variables --

local LockService = {};
LockService.__index = LockService;

if RunService:IsServer() then
    LockService.Keys = {
        -- ["player_indentifier"] = {
        --     key,
        --}
    };
    LockService.Locks = {};
    LockService.Salt = {};

    -- Private Functions --

    local function genKeys(player, amount)
        --[[
            layout of keys:
            {
                [1] = {"hashedKey", "deHashedKey"}
            }
        ]]
        local keys = {};
        -- layers
        local k1 = LockService.Salt[player.UserId][1];
        local k2 = LockService.Salt[player.UserId][2];
        local k3 = LockService.Salt[player.UserId][3]; 
        
        local key = {};
        local usedKeys = {}; -- makes sure there is 0 collisions with the keys
        local rndKey = math.random(100, 10000);
    end

    local function onConnect(player)
        local time = os.time();
        LockService.Salt[player.UserId] = {#Players:GetPlayers() + math.random(0, 10000), #Players:GetPlayers() - game.PlaceVersion, time / (math.random(time/2, time))};
        LockService.Keys[player.UserId] = {};
    end

    -- key checking --

    local function checkKey(player, key)
        -- dehash key

        -- check if key is in the valid keys
        -- if so remove, and return true
        -- else kick and return false
        return true
    end

    local function getKeyIndex(player, key)
        local keys = LockService.Keys[player.UserId];
        for i = 1, #keys do
            if keys[i] == key then
                return i;
            end
        end
        return false;
    end

    local function lockedEvent(player, key, params)
        local rawKey
        if checkKey(player, key) then
            -- remove from the valid keys
            local keyIndex = getKeyIndex(player, key);
        end
    end

    -- Class Functions --

    function LockService:LockEvent(event, callbackFunction)
        local lock = {};
        lock.event = event;
        lock.callbackFunction = callbackFunction;
        table.insert(self.Locks, lock); -- TODO: ADD NAMING FOR EASIER SORTING
        -- connect the event
        event:Connect(lockedEvent);
    end

    -- Connections --

    Players.PlayerAdded:Connect(onConnect);
end

return LockService;
