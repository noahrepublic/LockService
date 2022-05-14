
--[[ TODO:
5. Send a table of valid keys to the client, Ex: 100 keys, only 25% of them are valid.
6. The client will determine whether the key is valid or not by comparing the last 4 digits of the key with the index.
7. Once the client finds a valid key, with set instructions it will send to the server for whatever it needs, it will also encrypt the all parameters it is sending.
8. The server will decrypt the parameters and check if the key is valid.
9. After the client notices it needs more keys, it will request the server for some more. The server will set a certain index for each sets of keys, if the server ever gets
a repeated key or repeated index it will kick the user.
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
    LockService.UsedKeys = {}; -- Same format as Keys
    LockService.Locks = {};
    LockService.Salt = {};
    
    -- Private Functions --
    
    local function generateKeys(player, amount)
        local keys = {};
        local hashedKeys = {};
        for i = 1, amount do
            local key = HttpService:GenerateGUID(false);
            local key = string.gsub(key, "-", "");
            local hashedKey = {};
			for i = #key, 1, -1 do
				local character = string.sub(key, #key - i + 1, #key - i + 1); -- if #key is 10, and i = 7, then it is 4
                if #key - i + 1 > #key then
                    character = string.sub(key, #key, #key);
                end
				if tonumber(character) then
                    hashedKey[i] = character;
                    
					local g = (LockService.Salt[player.UserId] * #key - i); -- pow math
					print("G: " ..tostring(g) .. " Salt: " .. tostring(LockService.Salt[player.UserId]) .. "KEY-I: " .. #key -i)
                    if #key - i == 0 then
                        hashedKey[i] = character;
                    else
                        hashedKey[i] = character * g;
                    end -- if #key is 10, and i = 7, then it is 3
                    --local num = string.byte(character) * g;
					

				else
					hashedKey[i] = character
                end 
            end
            table.insert(keys, key);
            table.insert(hashedKeys, hashedKey);
        end
        return hashedKeys, keys;
    end
    
    local function findIndex(tbl, target)
        for i = 1, #tbl do
            if tbl[i] == target then
                return i;
            end
        end
        return false
    end
    
    local function assignKeys(player, keys)
        LockService.Keys[player.UserId] = keys;
    end
    
    
    local function initKeyConnector()
        if not script:FindFirstChild("KeysConnector") then
            local connectorRemote = Instance.new("RemoteEvent");
            connectorRemote.Name = "KeysConnector";
            connectorRemote.Parent = script;
        end
    end

    local function keyConnector(player, keys)
        local event = script:WaitForChild("KeysConnector");
        event:FireClient(player, keys);
        print("Sent over keys to " .. player.Name);
    end

    local function initSaltMaker()
        if not script:FindFirstChild("Salt") then
            local salt = Instance.new("RemoteEvent");
            salt.Name = "Salt";
            salt.Parent = script;
        end
    end

    local function saltConnector(player, salt)
        script["Salt"]:FireClient(player, salt);
        print("Salt sent to " .. player.Name);
    end
    
    local function onConnect(player)
        if LockService.Keys[player.UserId] then
            return;
        end
        initKeyConnector();
        initSaltMaker();
        LockService.Salt[player.UserId] = #Players:GetPlayers() + 1;
        saltConnector(player, LockService.Salt[player.UserId]);
        local hashedKeys, keys = generateKeys(player, 10);
        LockService.UsedKeys[player.UserId] = {};
        assignKeys(player, keys);
        keyConnector(player, hashedKeys);
    end
    
    local function OnDisconnect(player)
        local index = findIndex(LockService.Keys, player.UserId);
        if index then
            table.remove(LockService.Keys, index);
        end
    end
    
    local function getKeys(player)
        return LockService.Keys[player.UserId];
    end
    
    local function ValidateKey(player, input_key)
        local keys = getKeys(player);
        for i = 1, #keys do
            if keys[i] == input_key then
                return true;
            end
        end
        return false;
    end
    
    
    -- Class Functions --
    
    
    LockService.LockEvent = function(event, callbackFunction)
        event.OnServerEvent:Connect(function(player, key, params)
            -- Validate key --
            if (ValidateKey(player,key)) then
                -- Callback --
                local index = findIndex(LockService.Keys[player.UserId], key);
                if index then
                    table.remove(LockService.Keys[player.UserId], index);
                    print("Removed, " .. #getKeys(player) .. " keys left");
                end
                table.insert(LockService.UsedKeys[player.UserId], key);
                if (#getKeys(player) <= 1) then
                    local hashedKeys, keys = generateKeys(10);
                    assignKeys(player, keys);
                    keyConnector(player, hashedKeys);
                end
                callbackFunction(player, params);
            end
        end);
    end;
    
    -- Connections --
    Players.PlayerAdded:Connect(onConnect);
    Players.PlayerRemoving:Connect(OnDisconnect);
else
    -- Client functions --
    -- Variables --
    
    local event = script:WaitForChild("KeysConnector");
    local saltConnector = script:WaitForChild("Salt");

    local currentKeys = {};
    local salt = 0;
    -- Private Functions --

    

    local function onSalt(Csalt)
		salt = Csalt;
		print(salt)
        script:FindFirstChild("Salt"):Destroy();
    end

    -- Class Functions --

    LockService.DeHash = function(key)
		local decrypt = "";
		repeat
			task.wait()
			print("Waiting on salt...")
		until salt ~= 0
        repeat
            task.wait()
            print("Waiting on keys...")
        until currentKeys ~= {}
        for i = #key, 1, -1 do
            local character = key[i];
            if tonumber(character) then
                print(character)
				local g = (salt / #key - i); -- 10, i = 7, g = 3 -- math.pow
				print("G: " ..tostring(g) .. " Salt: " .. tostring(salt) .. " KEY-I: " .. #key -i)
                g = character / g;
                print(g)
                if #key - 1 == 0 then
                    decrypt = decrypt .. tostring(character);
                else
                    decrypt = decrypt .. tostring(g);
                end
            elseif character ~= nil then
                decrypt = decrypt .. character;
            end
        end
        return decrypt;
    end

    LockService.KeyRemote = function(event, params)
        repeat
            task.wait()
            print("Waiting on keys...")
        until #currentKeys > 0
        local key = LockService.DeHash(currentKeys[1]);
        event:FireServer(key,params); -- TODO ADD ALGORITHM FOR ENCRYPTION FOR A WORKING KEY
        table.remove(currentKeys, 1);
    end

    local function onKeys(keys)
        currentKeys = keys;
        LockService.DeHash(currentKeys[1]);
    end
    -- Connections --

    saltConnector.OnClientEvent:Connect(onSalt);
    event.OnClientEvent:Connect(onKeys);
end


return LockService;