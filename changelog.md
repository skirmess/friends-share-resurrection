# Unreleased - 2019-01-07 

This release is a major refactoring and updating of the addon by Fulzamoth & Tubiakou.

## Changed

* Most of the old lua API functions for working with friends were deprecated in 8.1.0, and will be removed in the next expansion. 
    * **AddFriend** - use **C_FriendList.AddFriend** instead
    * **AddIgnore** - use **C_FriendList.AddIgnore** instead
    * **AddOrDelIgnore** - use **C_FriendList.AddOrDelIgnore** instead
    * **GetIgnoreName** - use **C_FriendList.GetIgnoreName** instead

    The following four functions previously took a name or index to identify the friend being modified. As of 8.1.0 they have each been split into separate functions with a _...ByIndex_ function for use with indexes.
    
    * **DelIgnore** - use **C_FriendList.DelIgnore** or **C_FriendList.DelIgnoreByIndex** instead
    * **RemoveFriend** - has been split into two functions: **C_FriendList.RemoveFriend** or **C_FriendList.RemoveFriendByIndex.** The correct function must be called to remove a friend by name or index. 
    * **SetFriendNotes** - use **C_FriendList.SetFriendNotes** or **C_FriendList.SetFriendNotesByIndex** instead
    * **GetFriendInfo** - use **C_FriendList.GetFriendInfo** or **C_FriendList.GetFriendInfoByIndex** instead

* Fixed a problem that prevented the addon from working on non-connected realms.
* The ignore list was incorrectly syncing all ignores rather than just those for the connected realms. We've updated it to match the logic used for the friends list.
* Variable names were standardized to better match the API use. *name* is the character name, and may or may not have include the realm. *index* is used only with the ...ByIndex API functions.
* Some function names have been renamed to make it clearer what they're doing.

## Added

* Toggling the ignore status of a friend on your friends list was not captured by the addon. We've added an overload of **C_FriendList.AddOrDelIgnore** to trap it.
* Some API functions return a value that the UI expects. These are passed through now.
* Added an update interval setting to avoid looping through the wait table on each screen update.

