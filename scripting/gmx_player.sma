#include <amxmodx>
#include <reapi>
#include <json>
// #include <PersistentDataStorage>
#include "includes/gmx.inc"

enum FWD {
	FWD_Loadeding,
	FWD_Loadeded,
	FWD_Disconnecting,
	FWD_Disconnected,
}

new g_Forwards[FWD];
new g_Return;

enum {
	STATUS_NONE = 0,
	STATUS_LOADING,
	STATUS_LOADED,
};

enum _:PLAYER {
	PlayerStatus,
	PlayerId,
	PlayerUserId,
	PlayerSessionId,
};
new Players[MAX_PLAYERS + 1][PLAYER];

public plugin_init() {
	register_plugin("GMX Player", "0.0.2", "F@nt0M");

	RegisterHookChain(RH_SV_DropClient, "SV_DropClient_Post", true);

	g_Forwards[FWD_Loadeding] = CreateMultiForward("GMX_PlayerLoading", ET_STOP, FP_CELL);
	g_Forwards[FWD_Loadeded] = CreateMultiForward("GMX_PlayerLoaded", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_Forwards[FWD_Disconnecting] = CreateMultiForward("GMX_PlayerDisconnecting", ET_IGNORE, FP_CELL);
	g_Forwards[FWD_Disconnected] = CreateMultiForward("GMX_PlayerDisconnected", ET_IGNORE, FP_CELL);

	register_clcmd("gmx_assign", "CmdAssing");
}

public plugin_end() {
	DestroyForward(g_Forwards[FWD_Loadeding]);
	DestroyForward(g_Forwards[FWD_Loadeded]);
	DestroyForward(g_Forwards[FWD_Disconnecting]);
}

public UAC_Checked(const id) {
	if (is_user_bot(id) || is_user_hltv(id)) {
		return;
	}

	arrayset(Players[id], 0, sizeof Players[]);
	ExecuteForward(g_Forwards[FWD_Loadeding], g_Return, id);
	if (g_Return == PLUGIN_HANDLED) {
		return;
	}

	Players[id][PlayerStatus] = STATUS_LOADING;

	new steamid[24], nick[32], ip[32];
	get_user_authid(id, steamid, charsmax(steamid));
	get_user_name(id, nick, charsmax(nick));
	get_user_ip(id, ip, charsmax(ip), 1);

	new emulator = has_reunion()
		? REU_GetProtocol(id)
		: 0;

	new JSON:data = json_init_object();
	json_object_set_null(data, "id");
	json_object_set_number(data, "emulator", emulator);
	json_object_set_string(data, "steamid", steamid);
	json_object_set_string(data, "nick", nick);
	json_object_set_string(data, "ip", ip);
	
	GamexMakeRequest("player/connect", data, "OnConnected", get_user_userid(id));
	json_free(data);
}

public SV_DropClient_Post(const id) {
	if (Players[id][PlayerStatus] != STATUS_LOADED || Players[id][PlayerId] <= 0) {
		arrayset(Players[id], 0, sizeof Players[]);
		return HC_CONTINUE;
	}

	Players[id][PlayerStatus] = STATUS_NONE;
	ExecuteForward(g_Forwards[FWD_Disconnecting], g_Return, id);
	if (g_Return == PLUGIN_HANDLED) {
		arrayset(Players[id], 0, sizeof Players[]);
		return HC_CONTINUE;
	}

	new JSON:data = json_init_object();
	json_object_set_number(data, "id", Players[id][PlayerId]);
	GamexMakeRequest("player/disconnect", data, "OnDisconnected", get_user_userid(id));
	json_free(data);
	arrayset(Players[id], 0, sizeof Players[]);
	return HC_CONTINUE;
}

public CmdAssing(id) {
	new token[36];
	read_args(token, charsmax(token));
	remove_quotes(token);
	new JSON:data = json_init_object();
	json_object_set_number(data, "id", Players[id][PlayerId]);
	json_object_set_string(data, "token", token);
	GamexMakeRequest("player/assign", data, "OnAssigned", get_user_userid(id));
	json_free(data);
}

public OnConnected(const status, JSON:data, const userid) {
	if (status != GMX_REQ_STATUS_OK) {
		server_print("Error load player #%d", userid);
		return;
	}

	new id = getUserByUserID(userid);
	if (id == 0) {
		server_print("User #%d not found", userid);
		return;
	}

	if (!json_is_object(data)) {
		server_print("Bad response");
		return;
	}


	Players[id][PlayerId] = json_object_has_value(data, "player_id", JSONNumber)
		? json_object_get_number(data, "player_id")
		: 0;

	Players[id][PlayerSessionId] = json_object_has_value(data, "session_id", JSONNumber)
		? json_object_get_number(data, "session_id")
		: 0;

	Players[id][PlayerUserId] = json_object_has_value(data, "user_id", JSONNumber)
		? json_object_get_number(data, "user_id")
		: 0;

	// if (json_object_has_value(data, "user", JSONObject)) {
	// 	new JSON:tmp = json_object_get_value(data, "user");
	// 	Players[id][PlayerUserId] = json_object_has_value(tmp, "id", JSONNumber)
	// 		? json_object_get_number(tmp, "id")
	// 		: 0;
	// 	json_free(tmp);
	// }

	Players[id][PlayerStatus] = STATUS_LOADED;
	ExecuteForward(g_Forwards[FWD_Loadeded], g_Return, id, Players[id][PlayerId], data);
}

public OnDisconnected(const status, JSON:data, const userid) {
	if (status != GMX_REQ_STATUS_OK) {
		server_print("Error saving player #%d", userid);
		return;
	}

	new id = getUserByUserID(userid);
	if (id == 0) {
		server_print("User #%d not found", userid);
		return;
	}
	ExecuteForward(g_Forwards[FWD_Loadeded], g_Return, FWD_Disconnected, id, Players[id][PlayerId], data);
}

public OnAssigned(const status, JSON:data, const userid) {
	if (status != GMX_REQ_STATUS_OK) {
		server_print("Error assign player #%d", userid);
		return;
	}

	new id = getUserByUserID(userid);
	if (id == 0) {
		server_print("User #%d not found", userid);
		return;
	}

	if (!json_is_object(data)) {
		server_print("Bad response");
		return;
	}

	Players[id][PlayerUserId] = json_object_has_value(data, "user_id", JSONNumber)
		? json_object_get_number(data, "user_id")
		: 0;
}

// public PDS_Save() {
// 	for (new id = 1, key[32], data[2]; id <= MaxClients; id++) {
// 		if (Players[id][PlayerStatus] == STATUS_LOADED && Players[id][PlayerId] > 0) {
// 			formatex(key, charsmax(key), "gmx_pl_%d", get_user_userid(id));
// 			data[0] = Players[id][PlayerId];
// 			data[1] = Players[id][PlayerUserId];
// 			PDS_SetArray(key, data, sizeof data);
// 		}
// 	}
	
// }

stock getUserByUserID(const userid) {
	for (new id = 1; id <= MaxClients; id++) {
		if ((is_user_connected(id) || is_user_connecting(id)) && get_user_userid(id) == userid) {
			return id;
		}
	}

	return 0;
}