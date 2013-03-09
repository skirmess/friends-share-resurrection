--[[
FriendsShare: AddOn to keep a global friends list across alts on the same server.
]]

local Version = 20
local OrigAddFriend
local OrigRemoveFriend
local OrigAddIgnore
local OrigDelIgnore
local Realm
local PlayerFaction
local LastTry = 0
local waitTable = {}
local waitFrame = nil
local friendsAdded = 0

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

function FriendsShare_PrintableName(name)

	if ( name == nil ) then
		return
	end

	if ( string.len(name) < 2 ) then
		return string.upper(name)
	end

	return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end

function FriendsShare_CommandHandler(msg)

	if ( msg == "rebuild" ) then
		friendsShareList[Realm] = nil
		friendsShareIgnored[Realm] = nil
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
		friendsShareList[Realm][ string.lower(friend) ] = nil
		friendsShareNotes[Realm][ string.lower(friend) ] = nil
		friendsShareDeleted[Realm][ string.lower(friend) ] = 1
	else
		-- "friend" could be converted to a number and therefore
		-- cannot be a string containing the name

		local friendName = GetFriendInfo(friend)
		if ( friendName ) then
			friendsShareList[Realm][ string.lower( friendName) ] = nil
			friendsShareNotes[Realm][ string.lower( friendName ) ] = nil
			friendsShareDeleted[Realm][ string.lower( friendName) ] = 1
		end
	end

	OrigRemoveFriend(friend)
end

function FriendsShare_AddFriend(friend)

	OrigAddFriend(friend)

	if ( friend == "target" ) then
		friend = UnitName("target")
	end

	friendsShareList[Realm][string.lower(friend)] = PlayerFaction
	friendsShareDeleted[Realm][string.lower(friend)] = nil
end

function FriendsShare_DelIgnore(friend)

	-- "friend" can either be a string with the name
	-- of a friend or a number which is the friend index
	if ( tonumber( friend ) == nil ) then
		-- cannot convert to number, therefore it has to be a
		-- string containing the name
		friendsShareIgnored[Realm][ string.lower(friend) ] = nil
		friendsShareUnignored[Realm][ string.lower(friend) ] = 1
	else
		-- "friend" could be converted to a number and therefore
		-- cannot be a string containing the name

		local friendName = GetIgnoreName(friend)
		if ( friendName ) then
			friendsShareIgnored[Realm][ string.lower( friendName) ] = nil
			friendsShareUnignored[Realm][ string.lower( friendName) ] = 1
		end
	end

	OrigDelIgnore(friend)
end

function FriendsShare_AddIgnore(friend)

	OrigAddIgnore(friend)

	if ( friend == "target" ) then
		friend = UnitName("target")
	end

	friendsShareIgnored[Realm][string.lower(friend)] = PlayerFaction
	friendsShareUnignored[Realm][string.lower(friend)] = nil
end

function FriendsShare_SetFriendNotes(friendIndex, noteText)

	FriendsShare_origSetFriendNotes(friendIndex, noteText)

	local friendName
	if ( tonumber( friendIndex ) == nil ) then
		friendName = friendIndex
	else
		friendName = string.lower(GetFriendInfo(friendIndex))
	end

	if ( friendName ) then
		friendsShareNotes[Realm][string.lower(friendName)] = noteText
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: ERROR: Could not save new note to database. This note will be overwritten the next time you log in."))
	end
end

function FriendsShare_SyncLists()

	local iItem, currentFriend, localFriends, note, trash, localNotes, localIgnores

	-- initialize friendsShareList
	if ( friendsShareList == nil ) then
		friendsShareList = { }
	end

	if ( friendsShareList[Realm] == nil) then
		friendsShareList[Realm] = { }
	end

	-- initialize friendsShareDeleted
	if ( friendsShareDeleted == nil ) then
		friendsShareDeleted = { }
	end

	if ( friendsShareDeleted[Realm] == nil) then
		friendsShareDeleted[Realm] = { }
	end

	-- initialize friendsShareNotes
	if ( friendsShareNotes == nil ) then
		friendsShareNotes = { }
	end

	if ( friendsShareNotes[Realm] == nil) then
		friendsShareNotes[Realm] = { }
	end

	-- initialize friendsShareIgnored
	if ( friendsShareIgnored == nil ) then
		friendsShareIgnored = { }
	end

	if ( friendsShareIgnored[Realm] == nil ) then
		friendsShareIgnored[Realm] = { }
	end

	-- initialize friendsShareUnignored
	if ( friendsShareUnignored == nil ) then
		friendsShareUnignored = { }
	end

	if ( friendsShareUnignored[Realm] == nil ) then
		friendsShareUnignored[Realm] = { }
	end

	localFriends = { }
	localNotes = { }
	localIgnores = { }
	local retval = true

	--- load friend list from server
	local numFriends = GetNumFriends()
	for iItem = 1, numFriends, 1 do
		currentFriend, trash, trash, trash, trash, trash, note = GetFriendInfo(iItem)

		if ( currentFriend ) then
			localFriends[string.lower(currentFriend)] = 1
			localNotes[string.lower(currentFriend)] = note
		else
			-- friend list not loaded from server. we will try again later.
			return false
		end
	end

	--- load ignore list from server
	local numIgnores = GetNumIgnores()
	for iItem = 1, numIgnores, 1 do
		currentFriend = GetIgnoreName(iItem)

		if ( currentFriend and currentFriend ~= "Unknown") then
			localIgnores[string.lower(currentFriend)] = 1
		else
			-- ignore list not loaded from server. we will try again later.
			return false
		end
	end

	local index, value
	for index,value in pairs(localFriends) do
		if ( friendsShareDeleted[Realm][index] ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing %s from friends list.", FriendsShare_PrintableName(index)))
			RemoveFriend(index)
		else
			friendsShareList[Realm][index] = PlayerFaction

			if ( friendsShareNotes[Realm][index] ~= nil ) then
				if ( friendsShareNotes[Realm][index] == "" ) then
					if ( localNotes[index] ~= nil ) then
						DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removeing note for %s.", FriendsShare_PrintableName(index)))
						FriendsShare_origSetFriendNotes(index, "")
					end
				else
					if (localNotes[index] == nil or friendsShareNotes[Realm][index] ~= localNotes[index]) then
						DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Setting note \"%s\" for %s.", friendsShareNotes[Realm][index], FriendsShare_PrintableName(index)))
						FriendsShare_origSetFriendNotes(index, friendsShareNotes[Realm][index])
					end
				end
			elseif (localNotes[index] ~= nil) then
				-- save to database
				friendsShareNotes[Realm][index] = localNotes[index]
			end
		end
	end

	if ( friendsAdded == 0 ) then
		for index,value in pairs(friendsShareList[Realm]) do
			if ( value == PlayerFaction and localFriends[index] == nil and not (index == string.lower(UnitName("player")))) then
				DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Adding %s to friends list.", FriendsShare_PrintableName(index)))
				AddFriend(index)

				if (friendsShareNotes[Realm][index] ~= nil) then
					-- We cannot set the notes now because adding a new user takes
					-- some time. We return false which triggers another update.

					retval = false
				end
			end
		end

		-- only add friends once to prevent the eternal AddFriend() spam from removed friends.
		friendsAdded = 1
	end

	for index,value in pairs(localIgnores) do
		if ( friendsShareUnignored[Realm][index] ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing %s from ignore list.", FriendsShare_PrintableName(index)))
			DelIgnore(index)
		else
			friendsShareIgnored[Realm][index] = PlayerFaction
		end
	end

	for index,value in pairs(friendsShareIgnored[Realm]) do
		if ( localIgnores[index] == nil and not (index == string.lower(UnitName("player")))) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Adding %s to ignore list.", FriendsShare_PrintableName(index)))
			AddIgnore(index)
		end
	end

	return retval
end

local function PlanSync(delay)

	delay = math.min(2 * delay, 60)

	if ( not FriendsShare_SyncLists() ) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list not ready, will try again in %i seconds.", delay))

		ShowFriends()

		wait(delay, PlanSync, delay)
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list synced."))
	end
end

local function EventHandler(self, event, ...)

	if ( event == "PLAYER_ENTERING_WORLD" ) then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")

		Realm = GetCVar("realmName")
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

		wait(20, PlanSync, 1)

		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection %i loaded.", Version ))
	end
end

-- main
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", EventHandler)

