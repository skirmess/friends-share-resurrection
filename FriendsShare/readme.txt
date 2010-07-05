
FriendsShare Resurrection is an AddOn that lets you keep the same
friends list across characters, on a per server basis.

If you add or remove someone from your friends list and relog to an
alt, that person will be added/removed from the alts friends list as
well. Also, any entries on that alts list which isn't in the global
list, will be added to the other characters whenever you log them in.

Basically, you never have to manually rebuild your friends list when
creating alts, or worry about keeping them current on all your alts.

This all works seamlessly without any user intervention.

As an additional plus, if Blizzard decides to clean out the friends
list, this Addon will automatically rebuild your friend list. This
clean out happens sometimes during server maintenance. :-)

Known issue: If you try to add someone to your friends list and the
server won't let you do it (say, if a Horde char tries to add an
Alliance char to the list, or you misspell the name), that entry will
still end up on the global list, and so you'll get the error message
you got trying to add it, every time you log on. So, if this happens
to you, do '/friendsshare rebuild' and the global list will be rebuilt
from that char's list, and all invalid entries discarded.

This Addon was written originally by Oystein, all credit belongs to
him.


*** Changelog

Version 15
 * #5 - Fixed a case where the character name was not correctly converted to lower case before writing to the database.
 * Updated TOC for WoW 3.3.5
 * Discontinued XML file.
 * Removed FriendsShare_ prefix on local variables

Version 14
 * Updated TOC for WoW 3.2
 * Added link to project main page at
   http://code.google.com/p/friends-share-resurrection/

Version 13
 * Does no longer remove empty notes on every login.
 * Player names in the console output are now correctly capitalized.

Version 12
 * Sync ignore list
 * Updated TOC for WoW 3.1.0

Version 11
 * Sync notes

Version 10
 * Updated TOC for WoW 3.0.2

Version 9
 * No longer tries to add itself to the friend list.

Version 8
 * Updated TOC for WoW 2.3.0

Version 7
 * Switched back to PLAYER_ENTERING_WORLD in the hope that this
   solves the crash problems.

Version 6
 * Use the ADDON_LOADED event instead of PLAYER_ENTERING_WORLD to see
   when we are ready to go. This event seams more appropriate.
 * Do not try to sync the friend list if it failed within the last
   5 seconds. This should hopefully save the sync failed SPAM loop.

Version 5
 * Updated TOC for WoW 2.0.3

Version 4
 * There was a problem when you target a player and add him to the
   friendlist.

Version 3
 * Way better event handling (resolves the race condition during
   login which could crash the WoW client).
   Inspired by "Friend & Ignore Share v1.3, thanks Vimrasha.
 * Fixed the "gfind" Lua 5.1 syntax change problem.

Version 2 (based on 1.1 from Oystein)

 * Catch the case where the friend list is not yet loaded from the
   server. Try again later if the list was not ready the first time.
 * Mention which chars were added or removed from the friend list.
 * Delete first, then add new friends.
 * Lua 5.1 syntax change (had to use pairs())
 * added suffix FriendsShare_ to global variables
 * removed myAddOns code
