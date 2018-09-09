#include <amxmodx>
#include <reapi>
#include <curl>
#include <json>
#include "includes/gmx.inc"

enum FWD {
	FWD_Loadeding,
	FWD_Loadeded,
}

new g_Forwards[FWD];
new g_Return;


enum _:PLAYER {
	PL_ID,
	PL_USER_ID
}
new g_Players[MAX_PLAYERS + 1][PLAYER];

public plugin_init() {
	register_plugin("GMX Player", "0.0.2", "F@nt0M");
	g_Forwards[FWD_Loadeding] = CreateMultiForward("GMX_PlayerLoading", ET_STOP, FP_CELL);
	g_Forwards[FWD_Loadeded] = CreateMultiForward("GMX_PlayerLoaded", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
}

public plugin_end() {
	DestroyForward(g_Forwards[FWD_Loadeding]);
	DestroyForward(g_Forwards[FWD_Loadeded]);
}

public client_authorized(id) {
	arrayset(g_Players[id], 0, sizeof g_Players[]);
	ExecuteForward(g_Forwards[FWD_Loadeding], g_Return, id);
	if (g_Return == PLUGIN_HANDLED) {
		return PLUGIN_CONTINUE;
	}

	new steamid[24], nick[32], ip[32];
	get_user_authid(id, steamid, charsmax(steamid));
	get_user_name(id, nick, charsmax(nick));
	get_user_ip(id, ip, charsmax(ip), 1);

	new emulator = has_reunion()
		? REU_GetProtocol(id)
		: 0;

	new JSON:data = json_init_object();
	json_object_set_number(data, "emulator", emulator);
	json_object_set_string(data, "steamid", steamid);
	json_object_set_string(data, "nick", nick);
	json_object_set_string(data, "ip", ip);
	GamexMakeRequest("player/connect", data, "OnAuthorized", get_user_userid(id));
	json_free(data);
	return PLUGIN_CONTINUE;
}

public OnAuthorized(const status, JSON:data, const userid) {
	if (status != GMX_REQ_STATUS_OK) {
		server_print("Error load player #%d", userid);
		return;
	}

	new id = GMXGetUserByUserID(userid);
	if (id == 0) {
		server_print("User #%d not found", userid);
		return;
	}

	if (!json_is_object(data) || !json_object_has_value(data, "player", JSONObject)) {
		server_print("Bad response");
		return;
	}

	new JSON:tmp;
	if (json_object_has_value(data, "player", JSONObject)) {
		tmp = json_object_get_value(data, "player");
		g_Players[id][PL_ID] = json_object_has_value(data, "id", JSONNumber)
			? json_object_get_number(tmp, "id")
			: 0;
		json_free(tmp);
	}
	if (json_object_has_value(data, "user", JSONObject)) {
		tmp = json_object_get_value(data, "user");
		g_Players[id][PL_USER_ID] = json_object_has_value(data, "id", JSONNumber)
			? json_object_get_number(tmp, "id")
			: 0;
		json_free(tmp);
	}

	ExecuteForward(g_Forwards[FWD_Loadeded], g_Return, id, g_Players[id][PL_ID], data);
}