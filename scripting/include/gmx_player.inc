#if defined _gmx_player_included
	#endinput
#endif

#define _gmx_player_included

#include <grip>

forward GMX_PlayerLoading(const id);

forward GMX_PlayerLoaded(const id, GripJSONValue:data);

forward GMX_PlayerDisconnecting(const id);

native bool:GMX_PlayerIsLoaded(const id);

native GMX_PlayerGetPlayerId(const id);

native GMX_PlayerGetUserId(const id);

native GMX_PlayerGetSessionId(const id);

stock GMX_GetPlayerBPlayerID(const playerid) {
	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_connected(id) && GMX_PlayerIsLoaded(id) && GMX_PlayerGetPlayerId(id) == playerid) {
			return id;
		}
	}

	return 0;
}
