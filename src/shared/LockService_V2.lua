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

    local function getKeyIndex(tbl, key)
        for i = 1, #tbl do
            if tbl[i] == key then
                return i;
            end
        end
        return false;
    end

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
    
        local usedKeys = {}; -- makes sure there is 0 collisions with the keys
        for i = 1, amount do
            local key = {};
            local rndKey = math.random(100, 10000);
            if getKeyIndex(usedKeys, rndKey) == false then
                table.insert(usedKeys, rndKey);
                key[2] = rndKey;
                -- hash it
                local hashedKey = rndKey * k1
                hashedKey += k2
                hashedKey -= k3
                local chance = math.random(0, 1)
                if chance == 1 then
                    -- when client checks, check the last #k2 digits = k2
                    hashedKey = tostring(hashedKey) .. tostring(k2) -- put the k2 at the end
                    hashedKey = tonumber(hashedKey)
                end
                key[1] = hashedKey;
                table.insert(keys, key);
            else
                -- very rare to happen
                continue
            end 
        end
        return keys;
    end

    local function onConnect(player)
        local time = os.time();
        LockService.Salt[player.UserId] = {#Players:GetPlayers() + math.random(0, 10000), #Players:GetPlayers() - game.PlaceVersion, time / (math.random(time/2, time))};
        LockService.Keys[player.UserId] = {};
    end

    -- key checking --

    local function checkKey(player, key)
        -- hashed keys are sent
        for i, v in pairs(LockService.Keys[player.UserId]) do
            if v[1] == key then
                return v;
            end
        end
        -- check if key is in the valid keys
        -- if so remove, and return true
        -- else kick and return false
        return false
    end

    local function lockedEvent(player, key, params)
        -- do i use rawKey or hashed? hashed is better?
        local keyIndex = checkKey(player, key);
        if keyIndex then
            -- remove from the valid keys
        else
            player:Kick("Invalid key");
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
elseif RunService:IsClient() then
    -- Client Functions --

    local function deHash(key, salt)
        local k1 = salt[1];
        local k2 = salt[2];
        local k3 = salt[3];
        local digitsToCheck = tostring(k2)
        local amount = tostring(key):len()
        local digits = string.sub(tostring(key), amount - digitsToCheck:len() + 1, amount)
        if tonumber(digits) == tonumber(digitsToCheck) then
            key = tostring(key):sub(1, #tostring(key) - 2)
        else
            return false;
        end
        key += k3;
        key -= k2
        key /= k1;
        return key;
    end
end

return LockService;
