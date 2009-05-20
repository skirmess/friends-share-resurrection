--[[
FriendsShare: AddOn to keep a global friends list across alts on the same server.
Version 2
]]

local FriendsShare_origAddFriend
local FriendsShare_origRemoveFriend
local FriendsShare_realmName
local FriendsShare_initialized = 0
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

	FriendsShare_origRemoveFriend(friend)

	local foo = string.gfind(friend, "%d+")

	if ( foo() ) then
		local removed = GetFriendInfo(friend)
		if ( removed ) then
			friendsShareList[FriendsShare_realmName][ string.lower( removed) ] = nil
			friendsShareDeleted[FriendsShare_realmName][ string.lower( removed) ] = 1
		end
	else
		friendsShareList[FriendsShare_realmName][ string.lower(friend) ] = nil
		friendsShareDeleted[FriendsShare_realmName][ string.lower(friend) ] = 1
	end
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

	ShowFriends()

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


function FriendsShare_OnLoad()

	if ( FriendsShare_initialized == 1 ) then
		return
	end

	FriendsShare_realmName = GetCVar("realmName")
	FriendsShare_playerFaction = UnitFactionGroup("player")

	if (not FriendsShare_SyncLists()) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list not ready, will try again later."))
		return
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list synced."))
	end

	FriendsShare_initialized = 1

	SLASH_FRIENDSSHARE1 = "/friendsshare"
	SlashCmdList["FRIENDSSHARE"] = function(msg) FriendsShare_CommandHandler(msg) end

	FriendsShare_origAddFriend = AddFriend
	AddFriend = FriendsShare_AddFriend

	FriendsShare_origRemoveFriend = RemoveFriend
	RemoveFriend = FriendsShare_RemoveFriend
end


function FriendsShare_OnEvent(event)

	if (( event == "PLAYER_ENTERING_WORLD" ) or
	    ( event == "FRIENDLIST_UPDATE" )) then
		FriendsShare_OnLoad()
	end
end

