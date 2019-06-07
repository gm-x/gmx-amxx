#if defined _gmx_stocks_included
	#endinput
#endif

#define _gmx_stocks_included

stock GMX_GetPlayerByUserID(const userid) {
	for (new id = 1; id <= MaxClients; id++) {
		if ((is_user_connected(id) || is_user_connecting(id)) && get_user_userid(id) == userid) {
			return id;
		}
	}

	return 0;
}
