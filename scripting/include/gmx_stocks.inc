#if defined _gmx_stocks_included
	#endinput
#endif

#define _gmx_stocks_included

stock GMX_GetPlayerByUserID(const userid) {
	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_connected(id) && get_user_userid(id) == userid) {
			return id;
		}
	}

	return 0;
}

stock GMX_GetPlayerByPlayerID(const playerid) {
	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_connected(id) && GMX_PlayerIsLoaded(id) && GMX_PlayerGetPlayerId(id) == playerid) {
			return id;
		}
	}

	return 0;
}

stock GMX_GetTime() {
	return get_systime(0)  + GMX_GetServerTimeDiff();
}
