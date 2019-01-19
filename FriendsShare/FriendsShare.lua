--[[
FriendsShare: AddOn to keep a global friends list across alts on the same server.

  name         - friend name (may or may not contain the realm name)
  index        - index of friend in list (not used locally, but is a passthrough to stock UI)  

]]

local Version = 31
local CurrentRealm                -- current realm
local ConnectedRealms = {}        -- list of realms connected to current realm
local PlayerFaction               -- current player's faction
local waitTable = {}              -- tasks to run again on delay
local waitFrame = nil             -- frame to hook for delaying a function
local flagFriendsAdded = false    -- flag whether we've added friends in sync function 
local flagFriendsSynced = false   -- flag whether friends have been synced
local flagIgnoresSynced = false   -- flag whether ignores have been synced
local updateInterval = 5          -- how many seconds to wait between runs of delayed functions

-- These store the WoW lua API functions we're overloading
local OrigAddFriend               -- C_FriendList.AddFriend
local OrigRemoveFriend            -- C_FriendList.RemoveFriend
local OrigRemoveFriendByIndex     -- C_FriendList.RemoveFriendByIndex
local OrigAddIgnore               -- C_FriendList.AddIgnore
local OrigAddOrDelIgnore          -- C_FriendList.AddOrDelIgnore
local OrigDelIgnore               -- C_FriendList.DelIgnore
local OrigDelIgnoreByIndex        -- C_FriendList.DelIgnoreByIndex
local OrigSetFriendNotes          -- C_FriendList.SetFriendNotes
local OrigSetFriendNotesByIndex   -- C_FriendList.SetFriendNotesByIndex

local function debug(msg)
	DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare debug: %s", msg))
end

local function waitOnUpdate(self, elapsed)
  self.timeSinceUpdate = self.timeSinceUpdate - elapsed
  if ( self.timeSinceUpdate > 0 ) then
    return
  end

	local count = #waitTable
	local i = 1
	while ( i <= count )
	do
		local waitRecord = tremove(waitTable,i)
		local delay = tremove(waitRecord,1)
		local func = tremove(waitRecord,1)
		local params = tremove(waitRecord,1)
		if ( delay > elapsed ) then  -- we need to delay still
			tinsert(waitTable, i, {delay - elapsed, func, params})
			i = i + 1
		else
			count = count - 1
			func(unpack(params))      -- execute the delayed function
		end
	end
	if ( #waitTable == 0 ) then
		waitFrame:SetScript("onUpdate", nil)
	end
end

local function wait(delay, func, ...)
  -- arguments: [number] delay (in seconds)
  --            [string] func - function to call after wait
  --            ... - addition arguments to be passed to func() when it's called
  -- returns:   true if the wait was successfully added to the table, false on error
	if ( type(delay) ~= "number" or type(func) ~= "function" ) then
		return false
	end
	if ( waitFrame == nil ) then
		waitFrame = CreateFrame("Frame", "WaitFrame", UIParent)
	end
  waitFrame.timeSinceUpdate = updateInterval
	waitFrame:SetScript("onUpdate", waitOnUpdate)
	tinsert(waitTable, {delay, func, {...}})
	return true
end

function FriendsShare_TitleCase(name)
  -- capitalize first character of names & realms
	if ( name == nil ) then
		return
	end
	name = name:gsub("^%l", string.upper)
	local dash = string.find(name, "-")
	if ( dash == nil ) then
		return name
	end
	local character = string.sub(name, 1, dash - 1)
	local realm = string.sub(name, dash + 1) 
	return character .. "-" ..  realm:gsub("^%l", string.upper)
end

function FriendsShare_GetFQCharName(name)
  -- returns fully qualified character name (adds current realm to local characters)
	if ( name == nil ) then
		return
	end
	if ( string.match(name, "-") == nil ) then
		name = name .. "-" .. CurrentRealm
	end
	return name
end

function FriendsShare_StripLocalRealm(name)
	-- Removes the -RealmName for local characters. This is mandatory for WoW API calls.
	if ( name == nil ) then
		return
	end
	local p = string.find(name, "-")
	if ( p ~= nil ) then
		local r = string.sub(name, p+1)
		if ( string.lower(r) == string.lower(CurrentRealm) ) then
			return string.sub(name, 1, p-1)
		end
	end
	return name
end

function FriendsShare_IsOnConnectedRealm(name)
	if ( name == nil ) then
		return
	end
	local p = string.find(name, "-")
	if ( p == nil ) then
		return
	end
	local r = string.sub(name, p+1)
	local i = 1
	while ( ConnectedRealms[i] ~= nil ) do
		if ( string.lower(ConnectedRealms[i]) == r ) then
			return true
		end
		i = i + 1
	end
	return false
end

function FriendsShare_CommandHandler(msg)
	if ( msg == "rebuild" ) then
		local name
		for name, _ in pairs(FriendsShareFriends2) do
			if ( FriendsShare_IsOnConnectedRealm(name) ) then
				FriendsShareFriends2[name] = nil
			end
		end
		for name, _ in pairs(FriendsShareIgnored2) do
			if ( FriendsShareIgnored2[name] == "ignore" ) then
			  if ( FriendsShare_IsOnConnectedRealm(name) ) then
	  			FriendsShareIgnored2[name] = nil
        end
			end
		end
		for name, _ in pairs(FriendsShareNotes2) do
			if ( FriendsShare_IsOnConnectedRealm(name) ) then
				FriendsShareNotes2[name] = nil
			end
		end
		flagFriendsSynced = false
		flagIgnoresSynced = false
		FriendsShare_SyncLists()
		DEFAULT_CHAT_FRAME:AddMessage("FriendsShare Resurrection: Realmwide friendslist rebuilt.")
	else
		DEFAULT_CHAT_FRAME:AddMessage("FriendsShare Resurrection: Type '/friendsshare rebuild' if you want to rebuild the realmwide friendslist")
	end
end


------------------------------------------------------------------------------
-- Overloaded functions start here

function FriendsShare_AddFriend(name, notes)
  -- arguments: [string] name
  --            [string] notes (optional)
	name = FriendsShare_StripLocalRealm(name)
	OrigAddFriend(name, notes)
	if ( name == "target" ) then
		name = UnitName("target")
	end
	name = FriendsShare_GetFQCharName(name)
	FriendsShareFriends2[string.lower(name)] = PlayerFaction
  if ( notes ) then
    FriendsShareNotes2[string.lower(name)] = notes
  end
end

function FriendsShare_AddIgnore(name)
  -- arguments: [string] name
  -- returns:   [bool] true if successful, false otherwise    
	name = FriendsShare_StripLocalRealm(name)
	local added = OrigAddIgnore(name)
  if ( added ) then
    if ( name == "target" ) then
      name = UnitName("target")
    end
    name = FriendsShare_GetFQCharName(name)
    FriendsShareIgnored2[string.lower(name)] = "ignore"
  end
  return added
end

function FriendsShare_AddOrDelIgnore(name)
  -- arguments: [string] name
 	name = FriendsShare_GetFQCharName(name)
  if ( C_FriendList.IsIgnored(name) ) then
	  if ( FriendsShareIgnored2[string.lower(name)] == "ignore" ) then
	    FriendsShareIgnored2[string.lower(name)] = "delete"
    end
  else
	  FriendsShareIgnored2[string.lower(name)] = "ignore"
  end  
	name = FriendsShare_StripLocalRealm(name)
  OrigAddOrDelIgnore(name)
end

function FriendsShare_DelIgnore(name)
  -- arguments: [string] name
  -- returns:   [bool] true if successful, false otherwise
	name = FriendsShare_StripLocalRealm(name)
	local removed = OrigDelIgnore(name)
	if ( removed ) then
    -- only record the deletion if it was successful
    name = FriendsShare_GetFQCharName(name)
	  FriendsShareIgnored2[string.lower(name)] = "delete"
  end
  return removed
end

function FriendsShare_DelIgnoreByIndex(index)
  -- arguments: [number] index
	name = C_FriendList.GetIgnoreName(index)
	if ( name ) then
		name = FriendsShare_GetFQCharName(name)
		FriendsShareIgnored2[string.lower(name)] = "delete"
	end
	OrigDelIgnoreByIndex(index)
end

function FriendsShare_RemoveFriend(name)
  -- arguments: [string] name
  -- returns:   true if successful, false otherwise 
	name = FriendsShare_StripLocalRealm(name)
	local removed = OrigRemoveFriend(name) 
	if ( removed ) then
    name = FriendsShare_GetFQCharName(name)
	  FriendsShareFriends2[string.lower(name)] = "delete"
  	FriendsShareNotes2[string.lower(name)] = nil
  end
  return removed     
end

function FriendsShare_RemoveFriendByIndex(index)
  -- arguments: [number] index
	local name = C_FriendList.GetFriendInfo(index)
	if ( name ) then
		name = FriendsShare_GetFQCharName(name)
		FriendsShareFriends2[string.lower(name)] = "delete"
		FriendsShareNotes2[string.lower(name)] = nil
	end
	OrigRemoveFriendByIndex(index)
end

function FriendsShare_SetFriendNotes(name, notes)
  -- arguments: [string] name
  --            [string] notes
  -- returns:   [bool] true if successful, false otherwise
	name = FriendsShare_GetFQCharName(name)
	FriendsShareNotes2[string.lower(name)] = notes
	name = FriendsShare_StripLocalRealm(name)
	local found = OrigSetFriendNotes(name, notes)
  return found
end

function FriendsShare_SetFriendNotesByIndex(index, notes)
  -- arguments: [number] index
  --            [string] notes
	local name = FriendsShare_GetFQCharName(string.lower(C_FriendList.GetFriendInfoByIndex(index)))
	if ( name ) then
    name = FriendsShare_GetFQCharName(name)
		FriendsShareNotes2[string.lower(name)] = notes
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: ERROR: Could not save new note to database. This note will be overwritten the next time you log in."))
	end
	OrigSetFriendNotesByIndex(index, notes)
end

--
------------------------------------------------------------------------------

function FriendsShare_SyncFriendsLists()
  -- returns: [bool] true if successful, false if not
	local index, name, faction, notes, serverFriends, serverNotes
	serverFriends = { }
	serverNotes = { }
	-- load friend list from server
	local numFriends = C_FriendList.GetNumFriends()
	for index = 1, numFriends, 1 do
		info = C_FriendList.GetFriendInfoByIndex(index)
		if ( info.name ) then
			name = FriendsShare_GetFQCharName(info.name)
			serverFriends[string.lower(name)] = 1
			serverNotes[string.lower(name)] = info.notes
			-- debug(string.format("friend: %s", string.lower(currentFriend)))
		else
			-- friend list not loaded from server; we will try again later.
			return false
		end
	end

	for name, _ in pairs(serverFriends) do
		if ( FriendsShareFriends2[name] == "delete" ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing %s from friends list.", FriendsShare_TitleCase(name)))
			C_FriendList.RemoveFriend(name)
		else
			FriendsShareFriends2[name] = PlayerFaction
			if ( FriendsShareNotes2[name] ~= nil ) then     -- we have a note in the FSR database
				if ( FriendsShareNotes2[name] == "" ) then    -- note in FSR database is empty
					if ( serverNotes[name] ~= nil ) then        -- but, note on server has a value, so we'll remove it 
						DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing note for %s.", FriendsShare_TitleCase(name)))
						OrigSetFriendNotes(FriendsShare_StripLocalRealm(name), "")
					end
				else
					if ( serverNotes[name] == nil or FriendsShareNotes2[name] ~= serverNotes[name] ) then  -- update server note with one stored in FSR database
						DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Setting note \"%s\" for %s.", FriendsShareNotes2[name], FriendsShare_TitleCase(name)))
						OrigSetFriendNotes(FriendsShare_StripLocalRealm(name), FriendsShareNotes2[name])
					end
				end
			elseif ( serverNotes[name] ~= nil ) then          
				FriendsShareNotes2[name] = serverNotes[name]  -- store the server note to the database
			end
		end
	end

  for name, faction in pairs(FriendsShareFriends2) do
    if ( FriendsShare_IsOnConnectedRealm(name) ) then
      if ( faction == PlayerFaction and serverFriends[name] == nil and not (name == string.lower(UnitName("player") .. "-" .. CurrentRealm))) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Adding %s to friends list.", FriendsShare_TitleCase(name)))
        OrigAddFriend(name, FriendsShareNotes2[name])
      end
    end
  end
	return true
end

function FriendsShare_SyncIgnoreList()
  -- returns: [bool] true if successful, false if not
	local index, name, serverIgnores
	serverIgnores = { }
	-- load ignore list from server
	local numIgnores = C_FriendList.GetNumIgnores()
	for index = 1, numIgnores, 1 do
		name = C_FriendList.GetIgnoreName(index)
		if ( name and name ~= UNKNOWN ) then
			name = FriendsShare_GetFQCharName(name)
			serverIgnores[string.lower(name)] = 1
		else
			-- ignore list not loaded from server. we will try again later.
			return false 
		end
	end

	for name, _ in pairs(serverIgnores) do
		if ( FriendsShareIgnored2[name] and FriendsShareIgnored2[name] == "delete" ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing %s from ignore list.", FriendsShare_TitleCase(name)))
      OrigDelIgnore(name)
		else
			FriendsShareIgnored2[name] = "ignore"
		end
	end

	for name, value in pairs(FriendsShareIgnored2) do
		if ( FriendsShare_IsOnConnectedRealm(name) ) then
	  	if ( value == "ignore" and serverIgnores[name] == nil and not (name == string.lower(UnitName("player") .. "-" .. CurrentRealm))) then
		  	DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Adding %s to ignore list.", FriendsShare_TitleCase(name)))
		  	OrigAddIgnore(name)
		  end
    end
	end
	return true
end

function FriendsShare_RemoveUnknownEntriesFromIgnoreList()
	local name, index
	for index = C_FriendList.GetNumIgnores(), 1, -1 do
		name = GetIgnoreName(index)
		if ( name and name == UNKNOWN ) then
			OrigDelIgnoreByIndex(index)
		end
	end
end

function FriendsShare_SyncLists()
	local retval = true
	-- initialize FriendsShareFriends2
	if ( FriendsShareFriends2 == nil ) then
		FriendsShareFriends2 = { }
	end
	-- initialize FriendsShareNotes2
	if ( FriendsShareNotes2 == nil ) then
		FriendsShareNotes2 = { }
	end
	-- initialize FriendsShareIgnored2
	if ( FriendsShareIgnored2 == nil ) then
		FriendsShareIgnored2 = { }
	end
	local reportFLSuccess = 0
	local reportILSuccess = 0
	if ( flagFriendsSynced == false ) then
		if ( FriendsShare_SyncFriendsLists() ) then
			flagFriendsSynced = true
			reportFLSuccess = 1
    else
	  	-- not ready
      return false
    end
	end
	if ( flagIgnoresSynced == false ) then
		if ( FriendsShare_SyncIgnoreList() ) then
			flagIgnoresSynced = true
			reportILSuccess = 1
    else
			retval = false
		end
	end
	if ( ( reportFLSuccess == 1 ) and ( reportILSuccess == 1 ) ) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends and ignore list synchronized."))
	elseif ( reportFLSuccess == 1 ) then 
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list synchronized."))
	elseif ( reportILSuccess == 1 ) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: ignore list synchronized."))
	end
	return retval
end

local function PlanSync(delay)
	if ( FriendsShare_SyncLists() ) then
		-- successfully synced
		return
	end
	if ( delay >= 240 ) then
		if ( flagFriendsSynced == false ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list not ready, giving up."))
			return
		end
		-- remove unknown entries from ignore list
		debug("Removing UNKNOWNs from Ignore list")
		FriendsShare_RemoveUnknownEntriesFromIgnoreList()
		delay = 30
		return
	end
	delay = 2 * delay
	local notReadyList = "friends"
	if ( flagFriendsSynced == true ) then
		notReadyList = "ignore"
	end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: %s list not ready, will try again in %i seconds.", notReadyList, delay))
	C_FriendList.ShowFriends()
	wait(delay, PlanSync, delay)
end

local function EventHandler(self, event, ...)
	if ( event == "PLAYER_LOGIN" ) then
		self:UnregisterEvent("PLAYER_LOGIN")

		-- Realms like "Die Arguswacht" must be called "DieArguswacht" in the friends list.
		CurrentRealm = string.gsub(GetRealmName(), "%s", "")
		PlayerFaction = UnitFactionGroup("player")

		SLASH_FRIENDSSHARE1 = "/friendsshare"
		SlashCmdList["FRIENDSSHARE"] = function(msg) FriendsShare_CommandHandler(msg) end

    -- 
    -- These are functions that were deprecated in 8.1.0, and will be removed in the next expansion.
    --
    -- Use C_FriendList.AddFriend instead
    OrigAddFriend = C_FriendList.AddFriend
		C_FriendList.AddFriend = FriendsShare_AddFriend

		-- Use C_FriendList.RemoveFriend or C_FriendList.RemoveFriendByIndex instead
		OrigRemoveFriend = C_FriendList.RemoveFriend
		C_FriendList.RemoveFriend = FriendsShare_RemoveFriend
		OrigRemoveFriendByIndex = C_FriendList.RemoveFriendByIndex
    C_FriendList.RemoveFriendByIndex = FriendsShare_RemoveFriendByIndex

    -- Use C_FriendList.AddIgnore instead
		OrigAddIgnore = C_FriendList.AddIgnore
		C_FriendList.AddIgnore = FriendsShare_AddIgnore

    -- Use C_FriendList.AddOrDelIgnore instead
    -- Fulz: this overload is needed to capture the context menu toggle in the friends list
    OrigAddOrDelIgnore = C_FriendList.AddOrDelIgnore
    C_FriendList.AddOrDelIgnore = FriendsShare_AddOrDelIgnore

    -- Use C_FriendList.DelIgnore or C_FriendList.DelIgnoreByIndex instead
		OrigDelIgnore = C_FriendList.DelIgnore
		C_FriendList.DelIgnore = FriendsShare_DelIgnore
		OrigDelIgnoreByIndex = C_FriendList.DelIgnoreByIndex
		C_FriendList.DelIgnoreByIndex = FriendsShare_DelIgnoreByIndex

    -- Use C_FriendList.SetFriendNotes or C_FriendList.SetFriendNotesByIndex instead
		OrigSetFriendNotes = C_FriendList.SetFriendNotes
		C_FriendList.SetFriendNotes = FriendsShare_SetFriendNotes
		OrigSetFriendNotesByIndex = C_FriendList.SetFriendNotesByIndex
		C_FriendList.SetFriendNotesByIndex = FriendsShare_SetFriendNotesByIndex

		ConnectedRealms = GetAutoCompleteRealms()  -- Fulz: this will always return a table, even if it's empty, so we
		if ( ConnectedRealms[1] == nil ) then      --       check first value in returned table instead
			-- debug("FriendsShare Resurrection: Your realm is not conected.")
			ConnectedRealms = { CurrentRealm }
		else
			local i = 1
			while ( ConnectedRealms[i] ~= nil ) do
				-- debug(string.format("FriendsShare Resurrection: Realm in connected realm pool: %s.", ConnectedRealms[i] ))
				i = i + 1
			end
		end

		wait(10, PlanSync, 30)

		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection %i loaded.", Version ))

		-- debug(string.format("FriendsShare Resurrection: Your realm is %s.", CurrentRealm ))
		-- debug(string.format("FriendsShare Resurrection: Your faction is %s.", PlayerFaction ))
	end
end

-- main
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", EventHandler)

