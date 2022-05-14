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
    LockService.StrictMode = false;
    LockService.StrictModeThreshold = 30;

    LockService.PlayerConnectedTime = {};

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
        local cKeys = {};
        for _, v in pairs(keys) do
            table.remove(v, 2);
        end
        script:FindFirstChild("KeysConnector"):FireClient(player, cKeys);
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
        if LockService.StrictMode == false then
            LockService.PlayerConnectedTime[player.UserId] = game.Workspace:GetServerTimeNow();
        end
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
        if key == nil and #LockService.Keys[player.UserId] == 0 then
            callbackFunction(player, params);
            local newKeys = genKeys(player, LockService.AmountPerPlayer);
            assignKeys(player, newKeys);
        elseif key == nil and #LockService.Keys[player.UserId] > 0 then
            if LockService.StrictMode == false then
                local timeC = game.Workspace:GetServerTimeNow();
                if timeC - LockService.PlayerConnectedTime[player.UserId] < LockService.StrictModeThreshold then
                    callbackFunction(player, params);
                end
            else
                player:Kick("You are not allowed to do that.");
            end
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
        print("GetSalt fired.")
        local saltConnector = script:WaitForChild(Players.LocalPlayer.UserId, 60);
        if saltConnector then
            local conn = saltConnector.OnClientEvent:Connect(function(s)
                salt = s;
            end)
            conn:Disconnect();
            saltConnector:FireServer();
        else
            Players.LocalPlayer:Kick("Could not get salt");
        end
    end

    pcall(getSalt);
    repeat
        task.wait();
        print("Waiting for salt...");
    until salt ~= nil;
    print(salt)

    local function deHash(key, salt)
        local k1 = salt[1];
        local k2 = salt[2];
        local k3 = salt[3];
        if key == nil then return nil end
        key += k3;
        key -= k2
        key /= k1;
        return key;
    end

    local function keyConnector(keys)
        currentKeys = keys;
    end

    local function removeKey(key)
        for i, v in pairs(currentKeys) do
            if v[2] == key then
                table.remove(currentKeys, i);
                return;
            end
        end
    end
    -- Class Functions --

    function LockService:GetKeys()
        return currentKeys;
    end

    function LockService:FireLock(event, params, key)
        local deHashedKey = deHash(key, salt);
        event:FireServer(deHashedKey, params);
        print("FIRE")
        if key == nil then return end
        removeKey(key);
        print(#currentKeys)
    end
    
    -- Connections --

    script:WaitForChild("KeysConnector").OnClientEvent:Connect(keyConnector);
end

return LockService;
