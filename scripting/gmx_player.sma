#include <amxmodx>
#include <reapi>
#include <grip>
#include <PersistentDataStorage>
#include <gmx>
#include <uac>

new bool:UAC_IsLoaded = false;

enum FWD {
	FWD_Loadeding,
	FWD_Loadeded,
	FWD_Disconnecting,
	FWD_Disconnected,
}

new Forwards[FWD];
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
	PlayerSteamId[32]
};
new Players[MAX_PLAYERS + 1][PLAYER];

public plugin_init() {
	register_plugin("GMX Player", "0.0.2", "F@nt0M");

	RegisterHookChain(RH_SV_DropClient, "SV_DropClient_Post", true);

	Forwards[FWD_Loadeding] = CreateMultiForward("GMX_PlayerLoading", ET_STOP, FP_CELL);
	Forwards[FWD_Loadeded] = CreateMultiForward("GMX_PlayerLoaded", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	Forwards[FWD_Disconnecting] = CreateMultiForward("GMX_PlayerDisconnecting", ET_STOP, FP_CELL);
	Forwards[FWD_Disconnected] = CreateMultiForward("GMX_PlayerDisconnected", ET_IGNORE, FP_CELL);

	register_clcmd("gmx_assign", "CmdAssing");
}

public plugin_end() {
	DestroyForward(Forwards[FWD_Loadeding]);
	DestroyForward(Forwards[FWD_Loadeded]);
	DestroyForward(Forwards[FWD_Disconnecting]);
}

public PDS_Save() {
	for (new i = 1, data[2]; i < MaxClients; i++) {
		if (Players[i][PlayerStatus] == STATUS_LOADED) {
			data[0] = Players[i][PlayerId];
			data[1] = Players[i][PlayerSessionId];
			PDS_SetArray(Players[i][PlayerSteamId], data, sizeof data);
		}
	}
}

public client_connect(id) {
	Players[id][PlayerStatus] = STATUS_NONE;
}

public client_putinserver(id) {
	if (!UAC_IsLoaded && !is_user_bot(id) && !is_user_hltv(id)) {
		loadPlayer(id);
	}
	get_user_authid(id, Players[id][PlayerSteamId], 31);
}

public UAC_Loaded() {
	UAC_IsLoaded = true;
}

public UAC_Checked(const id, const UAC_CheckResult:result) {
	if (result != UAC_CHECK_KICK && !is_user_bot(id) && !is_user_hltv(id) && Players[id][PlayerStatus] != STATUS_LOADED) {
		loadPlayer(id);
	}
}

loadPlayer(id) {
	arrayset(Players[id], 0, sizeof Players[]);
	ExecuteForward(Forwards[FWD_Loadeding], g_Return, id);
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

	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_number(data, "emulator", emulator);
	grip_json_object_set_string(data, "steamid", steamid);
	grip_json_object_set_string(data, "nick", nick);
	grip_json_object_set_string(data, "ip", ip);

	new stored[2];
	if (PDS_GetArray(steamid, stored, sizeof stored)) {
		grip_json_object_set_number(data, "id", stored[0]);
		grip_json_object_set_number(data, "session_id", stored[1]);
	} else {
		grip_json_object_set_null(data, "id");
		grip_json_object_set_null(data, "session_id");
	}

	GamexMakeRequest("player/connect", data, "OnConnected", get_user_userid(id));
	grip_destroy_json_value(data);
}

public SV_DropClient_Post(const id) {
	if (Players[id][PlayerStatus] != STATUS_LOADED || Players[id][PlayerId] <= 0) {
		arrayset(Players[id], 0, sizeof Players[]);
		return HC_CONTINUE;
	}

	Players[id][PlayerStatus] = STATUS_NONE;
	ExecuteForward(Forwards[FWD_Disconnecting], g_Return, id);
	if (g_Return == PLUGIN_HANDLED) {
		arrayset(Players[id], 0, sizeof Players[]);
		return HC_CONTINUE;
	}

	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_number(data, "session_id", Players[id][PlayerSessionId]);
	GamexMakeRequest("player/disconnect", data, "", get_user_userid(id));
	grip_destroy_json_value(data);
	arrayset(Players[id], 0, sizeof Players[]);
	return HC_CONTINUE;
}

public CmdAssing(id) {
	new token[36];
	read_args(token, charsmax(token));
	remove_quotes(token);
	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_number(data, "id", Players[id][PlayerId]);
	grip_json_object_set_string(data, "token", token);
	GamexMakeRequest("player/assign", data, "OnAssigned", get_user_userid(id));
	grip_destroy_json_value(data);
}

public OnConnected(const status, GripJSONValue:data, const userid) {
	if (status != GMX_REQ_STATUS_OK) {
		return;
	}

	new id = getUserByUserID(userid);
	if (id == 0) {
		return;
	}

	if (grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	Players[id][PlayerId] = grip_json_object_get_number(data, "player_id");
	Players[id][PlayerSessionId] = grip_json_object_get_number(data, "session_id");
	new GripJSONValue:userIdVal = grip_json_object_get_value(data, "user_id");
	Players[id][PlayerUserId] = grip_json_get_type(userIdVal) != GripJSONNull ? grip_json_get_number(userIdVal) : 0;

	// if (json_object_has_value(data, "user", JSONObject)) {
	// 	new JSON:tmp = json_object_get_value(data, "user");
	// 	Players[id][PlayerUserId] = json_object_has_value(tmp, "id", JSONNumber)
	// 		? json_object_get_number(tmp, "id")
	// 		: 0;
	// 	json_free(tmp);
	// }

	Players[id][PlayerStatus] = STATUS_LOADED;

	new stored[2];
	stored[0] = Players[id][PlayerId];
	stored[1] = Players[id][PlayerSessionId];
	PDS_SetArray(Players[id][PlayerSteamId], stored, sizeof stored);

	ExecuteForward(Forwards[FWD_Loadeded], g_Return, id, Players[id][PlayerId], data);
}

public OnAssigned(const status, GripJSONValue:data, const userid) {
	if (status != GMX_REQ_STATUS_OK) {
		return;
	}

	new id = getUserByUserID(userid);
	if (id == 0) {
		return;
	}

	if (grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	Players[id][PlayerUserId] = grip_json_object_get_number(data, "user_id");
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