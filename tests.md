# Testing

The following should be checked when the addon is updated. After each individual test logout and check that *WTF/Account/.../SavedVariables/FriendsShare.lua* properly reflects the expected state. After logging in, wait 30 seconds to see that the updates are applied. For tests with notes and additional 60 seconds wait will be necessary for them to be synced.

The tests should be repeated for both of the following scenarios:

* While logged onto a realm that is not connected, test with a local realm friend.
* While logged onto a connected realm, test with a friend on another realm.
    
## Adding Friends
1. Add friend via Friends List pane
2. Add via `/friend` slash command

## Removing Friends
1. Remove friend via Friends List pane
2. Remove friend via `/removefriend` slash command

## Ignoring
1. Add ignore via Ignote list pane
2. Add ignore via `/ignore` slash command

## Removing Ignore
1. Remove ignore by selecting character in ignore list and clicking *Remove Player*
2. Remove by using `/unignore` slash command

## Ignoring a Friend
The right-click context menu on a friend in the Friends UI calls a toggle API function that needs to be tested separately:
1. Toggle on an ignore via right-clicking on a friend in the friends list UI
2. Toggle off an ignore via right-click on an ignored friend in friends list UI

## Adding a Note
1. Add a note to a friend by right-clicking, selecting *Set Note*, and adding note text.
2. Edit the note via the same menu, and clear the note text.

## Rebuild
1. Run `/friendsshare rebuild`.
