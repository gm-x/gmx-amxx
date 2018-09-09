enum {
	GMX_REQ_STATUS_ERROR = 0,
	GMX_REQ_STATUS_OK = 1
}

native GamexMakeRequest(const endpoint[], &JSON:data, const callback[], const param = 0);

stock GMXGetUserByUserID(const userid) {
	for (new id = 1; id <= MaxClients; id++) {
		if ((is_user_connected(id) || is_user_connecting(id)) || get_user_userid(id) == userid) {
			return id;
		}
	}

	return 0;
}