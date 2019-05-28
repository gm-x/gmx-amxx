#if defined _gmx_player_included
	#endinput
#endif

#define _gmx_player_included

#include <grip>

forward GMX_PlayerLoading(const id);

forward GMX_PlayerLoaded(const id, GripJSONValue:data);

forward GMX_PlayerDisconnecting(const id);

native GMX_PlayerGetPlayerId(const id);

native GMX_PlayerGetUserId(const id);

native GMX_PlayerGetSessionId(const id);