--[[ TODO:
    - Remove the adding of k2 at the end. It's not needed.


]]

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
    LockService.AmountPerPlayer = 10;

    if not script:FindFirstChild("KeysConnector") then
        local connectorRemote = Instance.new("RemoteEvent");
        connectorRemote.Name = "KeysConnector";
        connectorRemote.Parent = script;
    end

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
                key[1] = hashedKey;
                table.insert(keys, key);
            else
                -- very rare to happen
                continue
            end 
        end
        return keys;
    end

    local function assignKeys(player, keys)
        LockService.Keys[player.UserId] = keys;
        script:FindFirstChild("KeysConnector"):FireClient(player, LockService.Keys[player.UserId]);
    end

    local function initSalt(player)
        local saltConnector = Instance.new("RemoteEvent");
        saltConnector.Name = player.UserId;
        saltConnector.Parent = script;
        saltConnector:FireClient(player, LockService.Salt[player.UserId]);
        local conn = saltConnector.OnServerEvent:Connect(function(player)
            local event = script:FindFirstChild(player.UserId);
            if event then
                event:Destroy();
            end
        end);
        conn:Disconnect();
    end

    local function onConnect(player)
        local time = os.time();
        LockService.Salt[player.UserId] = {#Players:GetPlayers() + math.random(0, 10000), #Players:GetPlayers() - game.PlaceVersion, time / (math.random(time/2, time))};
        initSalt(player);
        LockService.Keys[player.UserId] = {};
        local keys = genKeys(player, LockService.AmountPerPlayer);
        assignKeys(player, keys);
    end

    local function onDisconnect(player)
        LockService.Keys[player.UserId] = {};
        LockService.Salt[player.UserId] = {};
    end

    -- key checking --

    local function checkKey(player, key)
        -- hashed keys are sent
        for i, v in pairs(LockService.Keys[player.UserId]) do
            if v[2] == key then
                return i;
            end
        end
        -- check if key is in the valid keys
        -- if so remove, and return true
        -- else kick and return false
        return false
    end

    local function lockedEvent(player, key, params, callbackFunction)
        -- raw key is sent
        if key == nil and #LockService[player.UserId] == 0 then
            callbackFunction(params);
            -- TODO: ASSIGN MORE KEYS
            local newKeys = genKeys(player, LockService.AmountPerPlayer);
            assignKeys(player, newKeys);
        elseif key == nil and #LockService[player.UserId] > 0 then
            player:Kick("You are not allowed to do that.");
        end
        local keyIndex = checkKey(player, key);
        if keyIndex then
            -- remove from the valid keys
            table.remove(LockService.Keys[player.UserId], keyIndex);
            print("Key removed" .. #LockService.Keys[player.UserId]);
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
        event.OnServerEvent:Connect(function(player, key, params)
            lockedEvent(player, key, params, callbackFunction);
        end)
    end

    -- Connections --

    Players.PlayerAdded:Connect(onConnect);
    Players.PlayerRemoving:Connect(onDisconnect);

elseif RunService:IsClient() then
    local salt = nil;
    local currentKeys = {};
    -- Private Client Functions --

    local function getSalt()
        local saltConnector = script:FindFirstChild(Players.LocalPlayer.UserId);
        if saltConnector then
            local conn = saltConnector.OnClientEvent:Connect(function(s)
                salt = s;
            end)
            conn:Disconnect();
            saltConnector:FireServer();
        end
    end

    pcall(getSalt);
    repeat
        task.wait();
    until salt ~= nil;
    print(salt)

    local function deHash(key, salt)
        local k1 = salt[1];
        local k2 = salt[2];
        local k3 = salt[3];
        key += k3;
        key -= k2
        key /= k1;
        return key;
    end

    local function keyConnector(keys)
        currentKeys = keys;
    end
    -- Class Functions --

    function LockService:FireLock(event, params, key)
        local deHashedKey = deHash(key, salt);
        event:FireServer(deHashedKey, params);
    end
    
    -- Connections --

    script:WaitForChild("KeysConnector").OnClientEvent:Connect(keyConnector);
end

return LockService;
