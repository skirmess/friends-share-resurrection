--[[
FriendsShare: AddOn to keep a global friends list across alts on the same server.
]]

local FriendsShare_Version = 3
local FriendsShare_origAddFriend
local FriendsShare_origRemoveFriend
local FriendsShare_realmName
local FriendsShare_playerFaction


function FriendsShare_CommandHandler(msg)

	if ( msg == "rebuild" ) then
		friendsShareList[FriendsShare_realmName] = nil
		FriendsShare_SyncLists()
		DEFAULT_CHAT_FRAME:AddMessage("Realmwide friendslist rebuilt.")
	else
		DEFAULT_CHAT_FRAME:AddMessage("Type '/friendsshare rebuild' if you want to rebuild the realmwide friendslist")
	end
end


function FriendsShare_RemoveFriend(friend)

	-- "friend" can either be a string with the name
	-- of a friend or a number which is the friend index
	if ( tonumber( friend ) == nil ) then
		-- cannot convert to number, therefore it has to be a
		-- string containing the name
		friendsShareList[FriendsShare_realmName][ string.lower(friend) ] = nil
		friendsShareDeleted[FriendsShare_realmName][ string.lower(friend) ] = 1
	else
		-- "friend" could be converted to a number and therefore
		-- cannot be a string containing the name

		local friendName = GetFriendInfo(friend)
		if ( friendName ) then
			friendsShareList[FriendsShare_realmName][ string.lower( friendName) ] = nil
			friendsShareDeleted[FriendsShare_realmName][ string.lower( friendName) ] = 1
		end
	end

	FriendsShare_origRemoveFriend(friend)
end


function FriendsShare_AddFriend(friend)

	FriendsShare_origAddFriend(friend)

	friendsShareList[FriendsShare_realmName][string.lower(friend)] = FriendsShare_playerFaction
	friendsShareDeleted[FriendsShare_realmName][string.lower(friend)] = nil
end


function FriendsShare_SyncLists()

	local iItem, currentFriend, localFriends

	if ( friendsShareList == nil ) then
		friendsShareList = { }
	end

	if ( friendsShareList[FriendsShare_realmName] == nil) then
		friendsShareList[FriendsShare_realmName] = { }
	end

	if ( friendsShareDeleted == nil ) then
		friendsShareDeleted = { }
	end

	if ( friendsShareDeleted[FriendsShare_realmName] == nil) then
		friendsShareDeleted[FriendsShare_realmName] = { }
	end

	localFriends = { }

	local numFriends = GetNumFriends()


	for iItem = 1, numFriends, 1 do
		currentFriend = GetFriendInfo(iItem)

		if ( currentFriend ) then
			localFriends[string.lower(currentFriend)] = 1
		else
			-- friend list not loaded from server. we will try again later.
			return false
		end
	end

	for index,value in pairs(localFriends) do
		if ( friendsShareDeleted[FriendsShare_realmName][index] ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing \"%s\" from friends list.", index))
			RemoveFriend(index)
		else
			friendsShareList[FriendsShare_realmName][index] = FriendsShare_playerFaction
		end
	end

	for index,value in pairs(friendsShareList[FriendsShare_realmName]) do
		if ( value == FriendsShare_playerFaction and localFriends[index] == nil ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Adding \"%s\" to friends list.", index))
			AddFriend(index)
		end
	end

	return true
end


function FriendsShare_OnEvent(event)

	if ( event == "PLAYER_ENTERING_WORLD" ) then
		this:UnregisterEvent("PLAYER_ENTERING_WORLD");
		
		FriendsShare_realmName = GetCVar("realmName")
		FriendsShare_playerFaction = UnitFactionGroup("player")

		SLASH_FRIENDSSHARE1 = "/friendsshare"
		SlashCmdList["FRIENDSSHARE"] = function(msg) FriendsShare_CommandHandler(msg) end

		FriendsShare_origAddFriend = AddFriend
		AddFriend = FriendsShare_AddFriend

		FriendsShare_origRemoveFriend = RemoveFriend
		RemoveFriend = FriendsShare_RemoveFriend

		-- call ShowFriends() to trigger an FRIENDLIST_UPDATE event
		-- after the friends list is loaded

		this:RegisterEvent("FRIENDLIST_UPDATE");
		ShowFriends()
		
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection %i loaded.", FriendsShare_Version ))
	end

	if ( event == "FRIENDLIST_UPDATE" ) then
	
		if (not FriendsShare_SyncLists()) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list not ready, will try again later."))

			-- call ShowFriends() to trigger a new FRIENDLIST_UPDATE event
			ShowFriends()
		else
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list synced."))

			-- The list is updated, unregister from the event.
			-- We sync only once per run.
			this:UnregisterEvent("FRIENDLIST_UPDATE");
		end
	end
end


