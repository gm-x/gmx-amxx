#pragma semicolon 1

#include <amxmodx>
#include <reapi>
#include <grip>
#include <PersistentDataStorage>
#include <gmx>
#tryinclude <uac>

#define CHECK_NATIVE_ARGS_NUM(%1,%2,%3) \
	if (%1 < %2) { \
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", %1, %2); \
		return %3; \
	}

#define CHECK_NATIVE_PLAYER(%1,%2) \
    if (!is_user_connected(%1)) { \
        log_error(AMX_ERR_NATIVE, "Invalid player %d", %1); \
        return %2; \
    }

#define CHECK_NATIVE_PLAYER_LOADED(%1,%2) \
    if (Players[%1][PlayerStatus] != STATUS_LOADED) { \
        log_error(AMX_ERR_NATIVE, "Player %d not loaded", %1); \
        return %2; \
    }

#define CHECK_PLAYER_STATUS(%1,%2) (Players[%1][PlayerStatus] == %2)

enum FWD {
	FWD_Init,
	FWD_Loading,
	FWD_Loaded,
	FWD_Disconnecting,
	// FWD_Disconnected,
}

new Forwards[FWD], FReturn;

enum FUNC {
	FnOnConnected,
	FnOnAssigned,
	FnOnInfoResponse,
}

new Functions[FUNC];

enum _:REQUEST {
	RequestPluginId,
	RequestFuncId,
	RequestParam,
};

new PluginId, bool:ApiEnabled = true, LogFile;
new Token[65], Url[256], GmxLogLevel:LogLvl;
new GripRequestOptions:RequestOptions = Empty_GripRequestOptions;
new Array:Requests = Invalid_Array, Request[REQUEST];

#if defined _uac_included
new bool:UAC_IsLoaded = false;
#endif

enum {
	STATUS_NONE = 0,
	STATUS_WAITING,
	STATUS_LOADING,
	STATUS_LOADED,
};

enum _:SERVER {
	ServerID,
	ServerTime,
	ServerTimeDiff
};

enum _:PLAYER {
	PlayerStatus,
	PlayerId,
	PlayerUserId,
	PlayerSessionId,
	PlayerSteamId[32]
};

new ServerData[SERVER];
new Players[MAX_PLAYERS + 1][PLAYER];

// Begin forwards
public plugin_precache() {
	PluginId = register_plugin("GMX Core", GMX_VERSION_STR, "GM-X Team");

	new path[128];
	get_localinfo("amxx_logs", path, charsmax(path));
	add(path, charsmax(path), "/gmx");
	if (!dir_exists(path)) {
		mkdir(path);
	}

	add(path, charsmax(path), "/L%Y%m%d.log");
	format_time(path, charsmax(path), path);
	LogFile = fopen(path, "a");
	if (!LogFile) {
		set_fail_state("Could not open %s for write", path);
	}

	loadConfig();
}

public plugin_init() {
	register_concmd("gmx_reloadcfg", "CmdReloadConfig", ADMIN_RCON);
	register_clcmd("gmx_assign", "CmdAssign");

	RegisterHookChain(RH_SV_DropClient, "SV_DropClient_Post", true);

	Functions[FnOnConnected] = get_func_id("OnConnected");
	Functions[FnOnAssigned] = get_func_id("OnAssigned");
	Functions[FnOnInfoResponse] = get_func_id("OnInfoResponse");

	Forwards[FWD_Init] = CreateMultiForward("GMX_Init", ET_IGNORE);
	Forwards[FWD_Loading] = CreateMultiForward("GMX_PlayerLoading", ET_STOP, FP_CELL);
	Forwards[FWD_Loaded] = CreateMultiForward("GMX_PlayerLoaded", ET_IGNORE, FP_CELL, FP_CELL);
	Forwards[FWD_Disconnecting] = CreateMultiForward("GMX_PlayerDisconnecting", ET_STOP, FP_CELL);

	makeInfoRequest();	
}

public plugin_cfg() {
	checkAPIVersion();
}

public plugin_end() {
	if (Requests != Invalid_Array) {
		ArrayDestroy(Requests);
	}
	if (RequestOptions != Empty_GripRequestOptions) {
		grip_destroy_options(RequestOptions);
	}

	fclose(LogFile);
}

public PDS_Save() {
	for (new player = 1, data[2]; player < MaxClients; player++) {
		if (CHECK_PLAYER_STATUS(player, STATUS_LOADED)) {
			data[0] = Players[player][PlayerId];
			data[1] = Players[player][PlayerSessionId];
			PDS_SetArray(Players[player][PlayerSteamId], data, sizeof data);
		}
	}
}

public client_connect(id) {
	Players[id][PlayerStatus] = STATUS_NONE;
}

public client_putinserver(id) {
	get_user_authid(id, Players[id][PlayerSteamId], 31);
#if defined _uac_included
	if (!UAC_IsLoaded || CHECK_PLAYER_STATUS(id, STATUS_WAITING)) {
		loadPlayer(id);
	} else if (UAC_IsLoaded && CHECK_PLAYER_STATUS(id, STATUS_NONE)) {
		Players[id][PlayerStatus] = STATUS_WAITING;
	}
#else
	loadPlayer(id);
#endif
}

#if defined _uac_included
public UAC_Loaded() {
	UAC_IsLoaded = true;
}

public UAC_Checked(const id, const UAC_CheckResult:result) {
	if (result == UAC_CHECK_KICK) {
		return;
	}

	switch (Players[id][PlayerStatus]) {
		case STATUS_NONE: {
			Players[id][PlayerStatus] = STATUS_WAITING;
		}

		case STATUS_WAITING: {
			loadPlayer(id);
		}
	}
}
#endif

public SV_DropClient_Post(const id) {
	if (Players[id][PlayerStatus] != STATUS_LOADED || Players[id][PlayerId] <= 0) {
		arrayset(Players[id], 0, sizeof Players[]);
		return HC_CONTINUE;
	}

	ExecuteForward(Forwards[FWD_Disconnecting], FReturn, id);
	if (FReturn == PLUGIN_HANDLED) {
		arrayset(Players[id], 0, sizeof Players[]);
		return HC_CONTINUE;
	}

	logToFile(GmxLogDebug, "Player #%d <player: %d> <session: %d> <user: %d> disconnecting from server", get_user_userid(id), Players[id][PlayerId], Players[id][PlayerSessionId], Players[id][PlayerUserId]);

	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_number(data, "session_id", Players[id][PlayerSessionId]);
	makeRequest("player/disconnect", data);
	grip_destroy_json_value(data);
	arrayset(Players[id], 0, sizeof Players[]);
	Players[id][PlayerStatus] = STATUS_NONE;
	return HC_CONTINUE;
}

public TaskPing() {
	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_number(data, "num_players", get_playersnum());

	new GripJSONValue:sessions = grip_json_init_array();
	for (new id = 1; id <= MaxClients; id++) {
		if (CHECK_PLAYER_STATUS(id, STATUS_LOADED)) {
			grip_json_array_append_number(sessions, Players[id][PlayerSessionId]);
		}
	}
	grip_json_object_set_value(data, "sessions", sessions);

	makeRequest("server/ping", data);
	grip_destroy_json_value(sessions);
	grip_destroy_json_value(data);
}

public CmdReloadConfig(id, level) {
	if (~get_user_flags(id) & level) {
		console_print(id, "You have no access to that command");
		return PLUGIN_HANDLED;
	}
	loadConfig();
	makeInfoRequest();
	return PLUGIN_HANDLED;
}

public CmdAssign(id) {
	new token[36];
	read_args(token, charsmax(token));
	remove_quotes(token);
	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_number(data, "id", Players[id][PlayerId]);
	grip_json_object_set_string(data, "token", token);
	makeRequest("player/assign", data, PluginId, Functions[FnOnAssigned], get_user_userid(id));
	grip_destroy_json_value(data);
	return PLUGIN_HANDLED;
}
// End forwards

// Begin callbacks
public OnInfoResponse(const GmxResponseStatus:status, GripJSONValue:data) {
	if (status == GmxResponseStatusBadToken) {
		ApiEnabled = false;
		logToFile(GmxLogError, "Bad token. Change valid in gmx.json and reload config");
		return;
	}

	if (status != GmxResponseStatusOk) {
		return;
	}

	ExecuteForward(Forwards[FWD_Init], FReturn);
	set_task(60.0, "TaskPing", .flags = "b");

	if (grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	ServerData[ServerID] = grip_json_object_get_number(data, "server_id");
	ServerData[ServerTime] = grip_json_object_get_number(data, "time");
	ServerData[ServerTimeDiff] = get_systime(0) - ServerData[ServerTime];
}

public OnConnected(const GmxResponseStatus:status, GripJSONValue:data, const userid) {
	if (status != GmxResponseStatusOk) {
		return;
	}

	new id = GMX_GetPlayerByUserID(userid);
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

	logToFile(GmxLogDebug, "Player #%d <player: %d> <session: %d> <user: %d> connected to server", userid, Players[id][PlayerId], Players[id][PlayerSessionId], Players[id][PlayerUserId]);

	Players[id][PlayerStatus] = STATUS_LOADED;

	new stored[2];
	stored[0] = Players[id][PlayerId];
	stored[1] = Players[id][PlayerSessionId];
	PDS_SetArray(Players[id][PlayerSteamId], stored, sizeof stored);

	ExecuteForward(Forwards[FWD_Loaded], FReturn, id, data);
}

public OnAssigned(const GmxResponseStatus:status, GripJSONValue:data, const userid) {
	if (status != GmxResponseStatusOk) {
		return;
	}

	new id = GMX_GetPlayerByUserID(userid);
	if (id == 0) {
		return;
	}

	if (grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	Players[id][PlayerUserId] = grip_json_object_get_number(data, "user_id");
}
// End callbacks

// Begin request
makeRequest(const endpoint[], GripJSONValue:data = Invalid_GripJSONValue, const pluginId = INVALID_PLUGIN_ID, const funcId = INVALID_PLUGIN_ID, const param = 0) {
	if (RequestOptions == Empty_GripRequestOptions) {
		RequestOptions = grip_create_default_options();
		grip_options_add_header(RequestOptions, "Content-Type", "application/json");
		grip_options_add_header(RequestOptions, "User-Agent", "Grip");
		grip_options_add_header(RequestOptions, "X-Token", Token);
	}

	Request[RequestPluginId] = pluginId;
	Request[RequestFuncId] = funcId;
	Request[RequestParam] = param;

	if (Requests == Invalid_Array) {
		Requests = ArrayCreate(REQUEST);
	}
	new id = ArrayPushArray(Requests, Request, sizeof Request);

	new GripBody:body = data != Invalid_GripJSONValue ? grip_body_from_json(data) : Empty_GripBody;
	grip_request(fmt("%s/api/%s", Url, endpoint), body, GripRequestTypePost, "RequestHandler", RequestOptions, id);
	if (body != Empty_GripBody) {
		grip_destroy_body(body);
	}
	return id;
}

public RequestHandler(const id) {
	if (id < 0 || id >= ArraySize(Requests)) {
		logToFile(GmxLogError, "Bad request id %d", id);
		return;
	}

	if (grip_get_response_state() != GripResponseStateSuccessful) {
		switch (grip_get_response_state()) {
			case GripResponseStateCancelled: {
				logToFile(GmxLogError, "Request %d was cancaled", id);
				callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusCanceled, Invalid_GripJSONValue, Request[RequestParam]);
			}
			case GripResponseStateError: {
				new err[256];
				grip_get_error_description(err, charsmax(err));
				logToFile(GmxLogError, "Request %d finished with error: %s", id, err);
				callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusError, Invalid_GripJSONValue, Request[RequestParam]);
			}
			case GripResponseStateTimeout: {
				logToFile(GmxLogError, "Request %d finished with timeout", id);
				callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusTimeout, Invalid_GripJSONValue, Request[RequestParam]);
			}
		}
		return;
	}

	new GripHTTPStatus:code = GripHTTPStatus:grip_get_response_status_code();
	if (code != GripHTTPStatusOk) {
		logToFile(GmxLogError, "Request %d finished with %d status", id, code);
		switch (code) {
			case GripHTTPStatusForbidden: {
				callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusBadToken, Invalid_GripJSONValue, Request[RequestParam]);
			}

			case GripHTTPStatusNotFound: {
				callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusNotFound, Invalid_GripJSONValue, Request[RequestParam]);
			}

			case GripHTTPStatusInternalServerError: {
				callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusServerError, Invalid_GripJSONValue, Request[RequestParam]);
			}

			default: {
				callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusUnknownError, Invalid_GripJSONValue, Request[RequestParam]);
			}
		}
		
		return;
	}

	ArrayGetArray(Requests, id, Request, sizeof Request);
	new error[128];
	new GripJSONValue:data = grip_json_parse_response_body(error, charsmax(error));
	if (data == Invalid_GripJSONValue) {
		logToFile(GmxLogInfo, "Error parse response: %s", error);
		callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusBadResponse, Invalid_GripJSONValue, Request[RequestParam]);
		return;
	}

	callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusOk, data, Request[RequestParam]);
	grip_destroy_json_value(data);
}
// Endrequest

// Begin functions
loadConfig() {
	new filePath[128];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	add(filePath, charsmax(filePath), "/gmx.json");
	if (!file_exists(filePath)) {
		set_fail_state("Coudn't open %s", filePath);
	}

	new error[128];
	new GripJSONValue:cfg = grip_json_parse_file(filePath, error, charsmax(error));
	if (cfg == Invalid_GripJSONValue) {
		set_fail_state("Coudn't open %s. Error %s", filePath, error);
	}

	if (grip_json_get_type(cfg) != GripJSONObject) {
		grip_destroy_json_value(cfg);
		set_fail_state("Coudn't open %s. Bad format", filePath);
	}

	grip_json_object_get_string(cfg, "token", Token, charsmax(Token));
	grip_json_object_get_string(cfg, "url", Url, charsmax(Url));
	LogLvl = GmxLogLevel:grip_json_object_get_number(cfg, "loglevel");
	grip_destroy_json_value(cfg);

	logToFile(GmxLogInfo, "Load configuration. URL is '%s'", Url);

	new fwd = CreateMultiForward("GMX_CfgLoaded", ET_IGNORE);
	new ret;
	ExecuteForward(fwd, ret);
	DestroyForward(fwd);
}

makeInfoRequest() {
	new map[64];
	get_mapname(map, charsmax(map));
	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_string(data, "map", map);
	grip_json_object_set_number(data, "max_players", MaxClients);
	makeRequest("server/info", data, PluginId, Functions[FnOnInfoResponse]);
	grip_destroy_json_value(data);
}

loadPlayer(id) {
	if (!canBeLoaded(id)) {
		return;
	}

	arrayset(Players[id], 0, sizeof Players[]);
	ExecuteForward(Forwards[FWD_Loading], FReturn, id);
	if (FReturn == PLUGIN_HANDLED) {
		return;
	}

	Players[id][PlayerStatus] = STATUS_LOADING;

	new steamid[24], nick[32], ip[32];
	get_user_authid(id, steamid, charsmax(steamid));
	get_user_name(id, nick, charsmax(nick));
	get_user_ip(id, ip, charsmax(ip), 1);

	new emulator = 0;
	if (has_reunion()) {
		emulator = _:REU_GetAuthtype(id);
	}

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
		stored[0] = 0;
		stored[1] = 0;
		grip_json_object_set_null(data, "id");
		grip_json_object_set_null(data, "session_id");
	}

	new userid = get_user_userid(id);

	logToFile(GmxLogDebug, "Player #%d <emu: %d> <steamid: %s> <ip: %s> <nick: %s> <id: %d> <session %d> connecting to server", userid, emulator, steamid, ip, nick, stored[0], stored[1]);
	makeRequest("player/connect", data, PluginId, Functions[FnOnConnected], userid);
	grip_destroy_json_value(data);
}

bool:canBeLoaded(const id) {
	return bool:(Players[id][PlayerStatus] != STATUS_LOADING && Players[id][PlayerStatus] != STATUS_LOADING && !is_user_bot(id) && !is_user_hltv(id));
}

callCallback(const pluginId, const funcId, const GmxResponseStatus:status, const GripJSONValue:data, const param) {
	if (pluginId != INVALID_PLUGIN_ID && funcId != INVALID_PLUGIN_ID && callfunc_begin_i(funcId, pluginId) == 1) {
		callfunc_push_int(_:status);
		callfunc_push_int(_:data);
		callfunc_push_int(param);
		callfunc_end();
	}
}

logToFile(const GmxLogLevel:level, const msg[], any:...) {
	if (level > LogLvl) {
		return;
	}

	new message[512];
	vformat(message, charsmax(message), msg, 3);

	new hour, minute, second;
	time(hour, minute, second);

	server_print("[GMX] %02d:%02d:%02d: %s", hour, minute, second, message);
	fprintf(LogFile, "%02d:%02d:%02d: %s^n", hour, minute, second, message);
	fflush(LogFile);
}
// End functions

// Begin natives
public plugin_natives() {
	register_native("GMX_MakeRequest", "NativeMakeRequest", 0);
	register_native("GMX_Log", "NativeLog", 0);
	register_native("GMX_GetServerID", "NativeGetServerID", 0);
	register_native("GMX_GetServerTime", "NativeGetServerTime", 0);
	register_native("GMX_GetServerTimeDiff", "NativeGetServerTimeDiff", 0);
	register_native("GMX_PlayerIsLoaded", "NativeIsLoaded", 0);
	register_native("GMX_PlayerGetPlayerId", "NativeGetPlayerId", 0);
	register_native("GMX_PlayerGetUserId", "NativeGetUserId", 0);
	register_native("GMX_PlayerGetSessionId", "NativeGetSessionId", 0);
}

public NativeMakeRequest(plugin, argc) {
	CHECK_NATIVE_ARGS_NUM(argc, 3, -1)

	if (!ApiEnabled) {
		log_error(AMX_ERR_NATIVE, "API is not enabled. Please check log files");
		return -1;
	}

	enum { arg_endpoint = 1, arg_data, arg_callback, arg_param };

	new endpoint[128];
	get_string(arg_endpoint, endpoint, charsmax(endpoint));

	new GripJSONValue:data = GripJSONValue:get_param(arg_data);
	new callback[64], funcId;
	get_string(arg_callback, callback, charsmax(callback));
	if (callback[0] != EOS) {
		funcId = get_func_id(callback, plugin);
		if (funcId == -1) {
			log_error(AMX_ERR_NATIVE, "Could not find function %s", callback);
			return -1;
		}
	} else {
		funcId = INVALID_PLUGIN_ID;
	}

	return makeRequest(endpoint, data, plugin, funcId, argc >= 4 ? get_param(arg_param) : 0);
}

public NativeLog(plugin, argc) {
	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	enum { arg_level = 1, arg_fmt, arg_params };

	new message[512];
	vdformat(message, charsmax(message), arg_fmt, arg_params);
	logToFile(GmxLogLevel:get_param(arg_level), message);
	return 1;
}

public NativeGetServerID() {
	return ServerData[ServerID];
}

public NativeGetServerTime() {
	return ServerData[ServerTime];
}

public NativeGetServerTimeDiff() {
	return ServerData[ServerTimeDiff];
}

public NativeIsLoaded(plugin, argc) {
	enum { arg_player = 1 };

	CHECK_NATIVE_ARGS_NUM(argc, 1, false)

	new player = get_param(arg_player);
	if (player <= 0 || player > MaxClients) {
		return false;
	}
	return bool:CHECK_PLAYER_STATUS(player, STATUS_LOADED);
}

public NativeGetPlayerId(plugin, argc) {
	enum { arg_player = 1 };

	CHECK_NATIVE_ARGS_NUM(argc, 1, 0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0)
	CHECK_NATIVE_PLAYER_LOADED(player, 0)

	return Players[player][PlayerId];
}

public NativeGetUserId(plugin, argc) {
	enum { arg_player = 1 };

	CHECK_NATIVE_ARGS_NUM(argc, 1, 0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0)
	CHECK_NATIVE_PLAYER_LOADED(player, 0)

	return Players[player][PlayerUserId];
}

public NativeGetSessionId(plugin, argc) {
	enum { arg_player = 1 };

	CHECK_NATIVE_ARGS_NUM(argc, 1, 0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0)
	CHECK_NATIVE_PLAYER_LOADED(player, 0)

	return Players[player][PlayerSessionId];
}
// End natives

checkAPIVersion() {
	for(new i, n = get_pluginsnum(), status[2], func; i < n; i++) {
		if(i == PluginId) {
			continue;
		}

		get_plugin(i, .status = status, .len5 = charsmax(status));

		//status debug || status running
		if(status[0] != 'd' && status[0] != 'r') {
			continue;
		}
	
		func = get_func_id("__gmx_version_check", i);

		if(func == -1) {
			continue;
		}

		if(callfunc_begin_i(func, i) == 1) {
			callfunc_push_int(GMX_MAJOR_VERSION);
			callfunc_push_int(GMX_MINOR_VERSION);
			callfunc_end();
		}
	}
}
