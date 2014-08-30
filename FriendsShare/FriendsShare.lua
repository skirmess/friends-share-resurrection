--[[
FriendsShare: AddOn to keep a global friends list across alts on the same server.
]]

local Version = 25
local OrigAddFriend
local OrigRemoveFriend
local OrigAddIgnore
local OrigDelIgnore
local Realm
local ConnectedRealms = {}
local PlayerFaction
local waitTable = {}
local waitFrame = nil
local friendsAdded = 0
local friendsListSynchronized = 0
local ignoreListSynchronozed = 0

local function debug (msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function waitOnUpdate (self, elapse)

	local count = #waitTable
	local i = 1
	while ( i <= count )
	do
		local waitRecord = tremove(waitTable,i)
		local d = tremove(waitRecord,1)
		local f = tremove(waitRecord,1)
		local p = tremove(waitRecord,1)

		if ( d > elapse ) then
			tinsert(waitTable, i, {d-elapse, f, p})
			i = i + 1
		else
			count = count - 1
			f(unpack(p))
		end
	end

	if ( #waitTable == 0 ) then
		waitFrame:SetScript("onUpdate", nil)
	end
end

local function wait(delay, func, ...)

	if ( type(delay) ~= "number" or type(func) ~= "function" ) then
		return false
	end

	if ( waitFrame == nil ) then
		waitFrame = CreateFrame("Frame", "WaitFrame", UIParent)
	end

	waitFrame:SetScript("onUpdate", waitOnUpdate)

	tinsert(waitTable, {delay, func, {...}})

	return true
end

function FriendsShare_PrintableName2(name)

	if ( name == nil ) then
		return
	end

	if ( string.len(name) < 2 ) then
		return string.upper(name)
	end

	return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end

function FriendsShare_PrintableName(name)

	if ( name == nil ) then
		return
	end

	local p = string.find(name, "-")
	if ( p == nil ) then
		return FriendsShare_PrintableName2(name)
	end

	local c = string.sub(name, 1, p-1)
	local r = string.sub(name, p+1)

	return FriendsShare_PrintableName2(c) .. "-" .. FriendsShare_PrintableName2(r)
end

function FriendsShare_FullQualifiedCharacterName(name)

	if ( name == nil ) then
		return
	end

	if ( string.match(name, "-") == nil ) then
		name = name .. "-" .. Realm
	end

	return name
end

function FriendsShare_ShortNameForLocalCharacters(name)

	if ( name == nil ) then
		return
	end

	local p = string.find(name, "-")
	if ( p ~= nil ) then
		local r = string.sub(name, p+1)
		if ( string.lower(r) == string.lower(Realm) ) then
			return string.sub(name, 1, p-1)
		end
	end

	return name
end

function FriendsShare_IsFriendFromMyCollectedRealmPool(name)

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
		if (string.lower(ConnectedRealms[i]) == r) then
			return true
		end
		i = i + 1
	end

	return false
end

function FriendsShare_CommandHandler(msg)

	if ( msg == "rebuild" ) then

		local index, value

		for index,value in pairs(FriendsShareFriends2) do
			if (FriendsShare_IsFriendFromMyCollectedRealmPool(index)) then
				FriendsShareFriends2[index] = nil
			end
		end

		for index,value in pairs(FriendsShareIgnored2) do
			if ( FriendsShareIgnored2[index] == "ignore" ) then
				FriendsShareIgnored2[index] = nil
			end
		end

		for index,value in pairs(FriendsShareNotes2) do
			if (FriendsShare_IsFriendFromMyCollectedRealmPool(index)) then
				FriendsShareNotes2[index] = nil
			end
		end
		
		friendsListSynchronized = 0
		ignoreListSynchronozed = 0
		FriendsShare_SyncLists()
		DEFAULT_CHAT_FRAME:AddMessage("FriendsShare Resurrection: Realmwide friendslist rebuilt.")
	else
		DEFAULT_CHAT_FRAME:AddMessage("FriendsShare Resurrection: Type '/friendsshare rebuild' if you want to rebuild the realmwide friendslist")
	end
end

function FriendsShare_RemoveFriend(friend)

	-- "friend" can either be a string with the name
	-- of a friend or a number which is the friend index
	if ( tonumber( friend ) == nil ) then
		-- cannot convert to number, therefore it has to be a
		-- string containing the name
		local friendName = FriendsShare_FullQualifiedCharacterName(friend)
		FriendsShareFriends2[ string.lower(friendName) ] = "delete"
		FriendsShareNotes2[ string.lower(friendName) ] = nil

		-- The WoW API requires a name without a dash for local characters
		friend = FriendsShare_ShortNameForLocalCharacters(friend)
	else
		-- "friend" could be converted to a number and therefore
		-- cannot be a string containing the name
		local friendName = GetFriendInfo(friend)
		if ( friendName ) then
			friendName = FriendsShare_FullQualifiedCharacterName(friendName)
			FriendsShareFriends2[ string.lower( friendName) ] = "delete"
			FriendsShareNotes2[ string.lower( friendName ) ] = nil
		end
	end

	OrigRemoveFriend(friend)
end

function FriendsShare_AddFriend(friend)

	-- The WoW API requires a name without a dash for local characters
	friend = FriendsShare_ShortNameForLocalCharacters(friend)

	OrigAddFriend(friend)

	if ( friend == "target" ) then
		friend = UnitName("target")
	end

	friend = FriendsShare_FullQualifiedCharacterName(friend)

	FriendsShareFriends2[string.lower(friend)] = PlayerFaction
end

function FriendsShare_DelIgnore(friend)

	-- "friend" can either be a string with the name
	-- of a friend or a number which is the friend index
	if ( tonumber( friend ) == nil ) then
		-- cannot convert to number, therefore it has to be a
		-- string containing the name
		local friendName = FriendsShare_FullQualifiedCharacterName(friend)
		FriendsShareIgnored2[ string.lower(friendName) ] = "delete"

		-- The WoW API requires a name without a dash for local characters
		friend = FriendsShare_ShortNameForLocalCharacters(friend)
	else
		-- "friend" could be converted to a number and therefore
		-- cannot be a string containing the name
		local friendName = GetIgnoreName(friend)
		if ( friendName ) then
			friendName = FriendsShare_FullQualifiedCharacterName(friendName)
			FriendsShareIgnored2[ string.lower( friendName) ] = "delete"
		end
	end

	OrigDelIgnore(friend)
end

function FriendsShare_AddIgnore(friend)

	-- The WoW API requires a name without a dash for local characters
	friend = FriendsShare_ShortNameForLocalCharacters(friend)

	OrigAddIgnore(friend)

	if ( friend == "target" ) then
		friend = UnitName("target")
	end

	friend = FriendsShare_FullQualifiedCharacterName(friend)

	FriendsShareIgnored2[string.lower(friend)] = "ignore"
end

function FriendsShare_SetFriendNotes(friendIndex, noteText)

	local friendName
	if ( tonumber( friendIndex ) == nil ) then
		-- cannot convert to number, therefore it has to be a
		-- string containing the name
		friendName = FriendsShare_FullQualifiedCharacterName(friendIndex)

		-- The WoW API requires a name without a dash for local characters
		friendIndex = FriendsShare_ShortNameForLocalCharacters(friendIndex)
	else
		-- "friend" could be converted to a number and therefore
		-- cannot be a string containing the name
		friendName = FriendsShare_FullQualifiedCharacterName(string.lower(GetFriendInfo(friendIndex)))
	end

	FriendsShare_origSetFriendNotes(friendIndex, noteText)

	if ( friendName ) then
		FriendsShareNotes2[string.lower(friendName)] = noteText
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: ERROR: Could not save new note to database. This note will be overwritten the next time you log in."))
	end
end

function FriendsShare_SyncFriendsLists()

	local iItem, currentFriend, note, trash, localFriends, localNotes
	local retval = 0 -- 0 = ok; -1 = not ready; -2 = delay for notes

	localFriends = { }
	localNotes = { }

	-- load friend list from server
	local numFriends = GetNumFriends()
	for iItem = 1, numFriends, 1 do
		currentFriend, trash, trash, trash, trash, trash, note = GetFriendInfo(iItem)

		if ( currentFriend ) then
			currentFriend = FriendsShare_FullQualifiedCharacterName(currentFriend)

			localFriends[string.lower(currentFriend)] = 1
			localNotes[string.lower(currentFriend)] = note

			-- debug(string.format("friend: %s", string.lower(currentFriend)))
		else
			-- friend list not loaded from server. we will try again later.
			return -1
		end
	end

	local index, value
	for index,value in pairs(localFriends) do
		if ( FriendsShareFriends2[index] == "delete" ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing %s from friends list.", FriendsShare_PrintableName(index)))
			RemoveFriend(index)
		else
			FriendsShareFriends2[index] = PlayerFaction

			if ( FriendsShareNotes2[index] ~= nil ) then
				if ( FriendsShareNotes2[index] == "" ) then
					if ( localNotes[index] ~= nil ) then
						DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removeing note for %s.", FriendsShare_PrintableName(index)))
						FriendsShare_origSetFriendNotes(FriendsShare_ShortNameForLocalCharacters(index), "")
					end
				else
					if (localNotes[index] == nil or FriendsShareNotes2[index] ~= localNotes[index]) then
						DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Setting note \"%s\" for %s.", FriendsShareNotes2[index], FriendsShare_PrintableName(index)))
						FriendsShare_origSetFriendNotes(FriendsShare_ShortNameForLocalCharacters(index), FriendsShareNotes2[index])
					end
				end
			elseif (localNotes[index] ~= nil) then
				-- save to database
				FriendsShareNotes2[index] = localNotes[index]
			end
		end
	end

	if ( friendsAdded == 0 ) then
		for index,value in pairs(FriendsShareFriends2) do
			if (FriendsShare_IsFriendFromMyCollectedRealmPool(index)) then
				if ( value == PlayerFaction and localFriends[index] == nil and not (index == string.lower(UnitName("player") .. "-" .. Realm))) then
					DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Adding %s to friends list.", FriendsShare_PrintableName(index)))
					AddFriend(index)

					if (FriendsShareNotes2[index] ~= nil) then
						-- We cannot set the notes now because adding a new user takes
						-- some time. We return false which triggers another update.

						retval = -2
					end
				end
			end
		end

		-- only add friends once to prevent the eternal AddFriend() spam from removed friends.
		friendsAdded = 1
	end

	return retval
end

function FriendsShare_SyncIgnoreList()

	local iItem, currentFriend, localIgnores
	local retval = 0 -- 0 = ok; -1 = not ready

	localIgnores = { }

	-- load ignore list from server
	local numIgnores = GetNumIgnores()
	for iItem = 1, numIgnores, 1 do
		currentFriend = GetIgnoreName(iItem)

		if ( currentFriend and currentFriend ~= UNKNOWN ) then
			currentFriend = FriendsShare_FullQualifiedCharacterName(currentFriend)
			localIgnores[string.lower(currentFriend)] = 1
		else
			-- ignore list not loaded from server. we will try again later.
			return -1
		end
	end

	local index, value

	for index,value in pairs(localIgnores) do
		if ( FriendsShareIgnored2[index] and FriendsShareIgnored2[index] == "delete" ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing %s from ignore list.", FriendsShare_PrintableName(index)))
			DelIgnore(index)
		else
			FriendsShareIgnored2[index] = "ignore"
		end
	end

	for index,value in pairs(FriendsShareIgnored2) do
		if ( value == "ignore" and localIgnores[index] == nil and not (index == string.lower(UnitName("player") .. "-" .. Realm))) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Adding %s to ignore list.", FriendsShare_PrintableName(index)))
			AddIgnore(index)
		end
	end

	return retval
end

function FriendsShare_RemoveUnknownEntriesFromIgnoreList()

	local currentIgnore, currentName

	for currentIgnore = GetNumIgnores(), 1, -1
	do
		currentName = GetIgnoreName(currentIgnore)

		if ( currentName and currentName == UNKNOWN ) then
			DelIgnore(currentIgnore)
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

	if ( friendsListSynchronized == 0 ) then
		local sfl = FriendsShare_SyncFriendsLists()

		if ( sfl == -1 ) then
			-- not ready
			return false
		end

		if ( sfl == -2 ) then
			retval = false
		end

		if ( sfl == 0 ) then
			friendsListSynchronized = 1
			reportFLSuccess = 1
		end
	end

	if ( ignoreListSynchronozed == 0 ) then
		local sil = FriendsShare_SyncIgnoreList()

		if ( sil == -1 ) then
			-- not ready
			retval = false
		end

		if ( sil == 0 ) then
			ignoreListSynchronozed = 1
			reportILSuccess = 1
		end
	end

	if (( reportFLSuccess == 1 ) and ( reportILSuccess == 1 )) then
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
		if ( friendsListSynchronized ~= 1 ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list not ready, giving up."))

			return
		end

		-- remove unknown entries from ignore list
		FriendsShare_RemoveUnknownEntriesFromIgnoreList()
		delay = 30

		return
	end

	-- delay = math.min(2 * delay, 60)
	delay = 2 * delay

	local notReadyList = "friends"
	if ( friendsListSynchronized == 1 ) then
		notReadyList = "ignore"
	end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: %s list not ready, will try again in %i seconds.", notReadyList, delay))

	ShowFriends()

	wait(delay, PlanSync, delay)
end

local function EventHandler(self, event, ...)

	if ( event == "PLAYER_ENTERING_WORLD" ) then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")

		-- Realms like "Die Arguswacht" must be called "DieArguswacht" in the friends list.
		Realm = string.gsub(GetRealmName(), "%s", "")
		PlayerFaction = UnitFactionGroup("player")

		SLASH_FRIENDSSHARE1 = "/friendsshare"
		SlashCmdList["FRIENDSSHARE"] = function(msg) FriendsShare_CommandHandler(msg) end

		OrigAddFriend = AddFriend
		AddFriend = FriendsShare_AddFriend

		OrigRemoveFriend = RemoveFriend
		RemoveFriend = FriendsShare_RemoveFriend

		OrigAddIgnore = AddIgnore
		AddIgnore = FriendsShare_AddIgnore

		OrigDelIgnore = DelIgnore
		DelIgnore = FriendsShare_DelIgnore

		FriendsShare_origSetFriendNotes = SetFriendNotes
		SetFriendNotes = FriendsShare_SetFriendNotes

		ConnectedRealms = GetAutoCompleteRealms()
		if ( ConnectedRealms == nil ) then
			-- debug("FriendsShare Resurrection: Your realm is not conected.")
			ConnectedRealms = { Realm }
		else
			local i = 1
			while ( ConnectedRealms[i] ~= nil ) do
				-- debug(string.format("FriendsShare Resurrection: Realm in connected realm pool: %s.", ConnectedRealms[i] ))
				i = i + 1
			end
		end

		wait(30, PlanSync, 30)

		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection %i loaded.", Version ))

		-- debug(string.format("FriendsShare Resurrection: Your realm is %s.", Realm ))
		-- debug(string.format("FriendsShare Resurrection: Your faction is %s.", PlayerFaction ))
	end
end

-- main
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", EventHandler)

