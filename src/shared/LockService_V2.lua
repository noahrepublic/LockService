--[[
    Known issues: 
    Priotity: Not necessarily needed, will make easier to implement.
    - If you unlock a locked event, the client continues to try to fire
    the event, even though the event is locked, and the client removes the keys
    from their list. (could be fixed by client handling the service correctly.)
]]
-- Services --

local Players = game:GetService("Players");
local RunService = game:GetService("RunService");

-- Variables --

local LockService = {};
LockService.__index = LockService;

if RunService:IsServer() then
	local data = {Keys = {},Locks = {},Salt = {},AmountPerPlayer = 10,StrictMode = false,StrictModeThreshold = 30,PlayerConnectedTime = {},LastNewKey = {}}
	setmetatable(LockService, {__index = data})
    setmetatable(LockService.Keys, {__mode = "k"})
    setmetatable(LockService.Locks, {__mode = "k"})
    setmetatable(LockService.Salt, {__mode = "k"})
    setmetatable(LockService.PlayerConnectedTime, {__mode = "k"})

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

        do 
            local usedKeys = {}; -- makes sure there is 0 collisions with the keys
            for i = 1, amount do
                local key = {};
                setmetatable(key, {__mode = "k"})
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
        end
		return keys;
	end

	local function assignKeys(player, keys)
        LockService.Keys[player.UserId] = nil;
		LockService.Keys[player.UserId] = keys;

		local cKeys = {};
		for _, v in pairs(keys) do
			table.insert(cKeys, v[1]);
		end
		LockService.LastNewKey[player.UserId] = workspace:GetServerTimeNow();
		script:FindFirstChild("KeysConnector"):FireClient(player, cKeys);
	end

	local function initSalt(player)
		local saltConnector = Instance.new("RemoteEvent");
		saltConnector.Name = player.UserId;
		saltConnector.Parent = script;
		saltConnector:FireClient(player, LockService.Salt[player.UserId]);
		saltConnector.OnServerEvent:Connect(function(player)
			if saltConnector == nil then player:Kick("LockService: SaltConnector is nil"); return end
			saltConnector:Destroy();
		end);
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
		LockService.Keys[player.UserId] = nil;
		LockService.Salt[player.UserId] = nil;
		LockService.PlayerConnectedTime[player.UserId] = nil;
		LockService.LastNewKey[player.UserId] = nil;
	end

    -- Lock handling --

    local function AddLock(lock)
        if lock == nil then
            return false;
        end
    	table.insert(LockService.Locks,lock);
    end


	-- key checking --

	local function checkKey(player, key)
		-- hashed keys are sent
		for i, v in pairs(LockService.Keys[player.UserId]) do
			if v[2] == key then
                LockService.Keys[player.UserId][i] = nil;
				return i;
			end
		end
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
		if checkKey(player, key) then
			callbackFunction(player, params);
		else
			if workspace:GetServerTimeNow() - LockService.LastNewKey[player.UserId] < 0.5 then
				callbackFunction(player, params);
			else
				player:Kick("Invalid key");
			end
		end
	end

	-- Class Functions --

	function LockService:LockEvent(event, callbackFunction)
		local lock = {};
        setmetatable(lock, {__mode = "k"})
        lock.name = event:GetFullName();
		lock.callbackFunction = callbackFunction;
        local isLocked = self:IsLocked(event);
        if isLocked == false then
            print("LockService | Added lock: " .. lock.name);
            local conn = event.OnServerEvent:Connect(function(player, key, params)
                lockedEvent(player, key, params, callbackFunction);
            end)
            lock.conn = conn
            AddLock(lock);
        else
            warn("LockService | Can't add lock, that lock already exists");
		end
        lock = nil
	end

    function LockService:UnlockEvent(event)
        for i = 1, #self.Locks do
            if self.Locks[i].conn == event.conn then
                self.Locks[i].conn:Disconnect()
                print("LockService | Unlocked event " .. event.Name)
                self.Locks[i] = nil
                return true
            end
        end
        return false
    end

    function LockService:IsLocked(event)
        for i = 1, #self.Locks do
            if self.Locks[i].name == event:GetFullName() then
                return true
            end
        end
        return false
    end

    function LockService:GetLocks()
        return self.Locks
    end

	-- Connections --

	Players.PlayerAdded:Connect(onConnect);
	Players.PlayerRemoving:Connect(onDisconnect);

	script:FindFirstChild("KeysConnector").OnServerEvent:Connect(function(player)
		player:Kick("You are not allowed to do that.");
	end)

elseif RunService:IsClient() then
    local var = {salt = nil,currentKeys = nil}
    setmetatable(var, {__index = LockService})
	-- Private Client Functions --

	local function getSalt()
		local saltConnector = script:WaitForChild(Players.LocalPlayer.UserId, 60);
		if saltConnector then
			local conn = saltConnector.OnClientEvent:Connect(function(s)
				LockService.salt = s;
				saltConnector:FireServer();
			end)
			conn:Disconnect();
			saltConnector:Destroy();
		else
			Players.LocalPlayer:Kick("Could not get salt"); -- not needed to kick on the server, if they are legit then it will kick, if they are exploiting then they broke themselves as the salt table is read only and kicks on server.
		end
	end

	pcall(getSalt);
	repeat
		task.wait();
	until LockService.salt ~= nil;

    setmetatable(LockService.salt, {
        __index = function(_, k)
            return LockService.salt[k]
        end,
        __newindex = function(_, k, v)
            warn("This is a read-only table") -- Only a small chance of this happening, but it is possible.
            script:FindFirstChild("KeysConnector"):FireServer()
        end
    })

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
		LockService.currentKeys = keys;
	end

	local function removeKey(key)
		for i, v in pairs(LockService.currentKeys) do
			if v == key then
				table.remove(LockService.currentKeys, i);
				return;
			end
		end
	end
	-- Class Functions --

	function LockService:GetKeys()
		return self.currentKeys;
	end

	function LockService:FireLock(event, params, key)
		local deHashedKey = deHash(key, self.salt);
		event:FireServer(deHashedKey, params);
		if key == nil then return end
		removeKey(key);
	end

	-- Connections --

	script:WaitForChild("KeysConnector").OnClientEvent:Connect(keyConnector);
end

return LockService;