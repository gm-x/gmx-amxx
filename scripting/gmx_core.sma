#include <amxmodx>
#include <curl>
#include <json>

#define URL "http://127.0.0.1:8000/api"
#define JWT "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzUxMiJ9.eyJzZXJ2ZXJfaWQiOjF9.02FWNinIulC8QEoJ4yqMZs5p2ytd12_JMoIk8x7JxELINfajoebFISwTLMEaneLIcmt39pJ-hFyc9oVdJcnD8A"

native JSON:GamexCfgGetKey(const key[]);
native GamexMakeRequest(const endpoint[], &JSON:data, const callback[], const param = 0);

enum _:REQUEST {
	JSON:R_DATA,
	Handle:R_SLIST,
	R_PLUGIN,
	R_FUNC,
	R_PARAM,
}

new Array:g_Requests = Invalid_Array;
new JSON:g_Cfg = Invalid_JSON;

public plugin_init() {
	register_plugin("GameX Config", "0.1", "F@nt0M");
	register_srvcmd("test", "CmdTest");
}

stock reverseString(string[]) {
	for (new i = 0, len = strlen(string) - 1; i < len; i++, len--) {
		string[i] ^= string[len];
		string[len] ^= string[i];
		string[i] ^= string[len];
	}
}

public plugin_end() {
	if (g_Requests != Invalid_Array) {
		ArrayDestroy(g_Requests);
	}

	if (g_Cfg != Invalid_JSON) {
		json_free(g_Cfg);
	}
}

public CmdTest() {
	new JSON:data = json_init_object();
	json_object_set_string(data, "steamid", "STEAM_0:1:160867035");
	json_object_set_string(data, "nick", "F@nt0M");
	GamexMakeRequest("player", data, "Test", 1);
}

public Test(&JSON:data, const param) {
	server_print("^t PARAM %d param", param);
}

public plugin_cfg() {
	new filePath[128];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	add(filePath, charsmax(filePath), "/gamex.json");
	g_Cfg = json_parse(filePath, true, true);
	if (!json_is_object(g_Cfg)) {
		set_fail_state("Coudn't open %s", filePath);
		return;
	}

	new fwd = CreateMultiForward("GamexCfgLoaded", ET_IGNORE);
	new ret;
	ExecuteForward(fwd, ret);
	DestroyForward(fwd);
}

public plugin_natives() {
	register_native("GamexCfgGetKey", "NativeGamexCfgGetKey", 0);
	register_native("GamexMakeRequest", "NativeGamexMakeRequest", 0);
}

public NativeGamexCfgGetKey(pluginId, paramNums) {
	if (paramNums != 1) {
		return _:Invalid_JSON;
	}

	new key[32];
	get_string(1, key, charsmax(key));
	return _:json_object_get_value(g_Cfg, key, false);
}

public NativeGamexMakeRequest(pluginId, paramNums) {
	if (paramNums < 3) {
		return 0;
	}

	new endpoint[128];
	get_string(1, endpoint, charsmax(endpoint));
	format(endpoint, charsmax(endpoint), "%s/%s", URL, endpoint);

	new JSON:data = JSON:get_param_byref(2);

	new callback[64];
	get_string(3, callback, charsmax(callback));

	new funcId = get_func_id(callback, pluginId);
	if (funcId == -1) {
		return 0;
	}

	new param = paramNums >= 4 ? get_param(4) : 0;
	return makeRequest(endpoint, data, pluginId, funcId, param);
}

makeRequest(const url[], &JSON:data, const pluginId, const funcId, const param) {
	new request[REQUEST];

	new CURLcode:code = CURLE_OK;

	new Handle:ch = curl_init();
	if (ch == INVALID) {
		json_free(data);
		return 0;
	}

	code = curl_setopt_string(ch, CURLOPT_URL, url)
	if (code != CURLE_OK) {
		json_free(data);
		curl_close(ch);
		return 0;
	}

	code = curl_setopt_cell(ch, CURLOPT_CONNECTTIMEOUT, 15)
	if (code != CURLE_OK) {
		json_free(data);
		curl_close(ch);
		return 0;
	}


	code = curl_setopt_cell(ch, CURLOPT_TIMEOUT, 15)
	if (code != CURLE_OK) {
		json_free(data);
		curl_close(ch);
		return 0;
	}

	code = curl_setopt_cell(ch, CURLOPT_POST, 1);
	if (code != CURLE_OK) {
		json_free(data);
		curl_close(ch);
		return 0;
	}

	code = curl_setopt_cell(ch, CURLOPT_HTTPAUTH, 1)
	if (code != CURLE_OK) {
		json_free(data);
		curl_close(ch);
		return 0;
	}


	code = curl_setopt_string(ch, CURLOPT_USERPWD, JWT)
	if (code != CURLE_OK) {
		json_free(data);
		curl_close(ch);
		return 0;
	}

	new post[2048];
	json_serial_to_string(data, post, charsmax(post), false);
	code = curl_setopt_string(ch, CURLOPT_POSTFIELDS, post);
	if (code != CURLE_OK) {
		json_free(data);
		curl_close(ch);
		return 0;
	}

	new Handle:slist = curl_create_slist();
	if (slist == INVALID) {
		json_free(data);
		curl_close(ch);
		return 0;
	}

	if (!curl_slist_append(slist, "Content-Type: application/json")) {
		curl_close(slist);
		json_free(data);
		curl_close(ch);
		return 0;
	}

	code = curl_setopt_handle(ch, CURLOPT_HTTPHEADER, slist);
	if (code != CURLE_OK) {
		curl_close(slist);
		json_free(data);
		curl_close(ch);
		return 0;
	}

	request[R_DATA] = data;
	request[R_SLIST] = slist;
	request[R_PLUGIN] = pluginId;
	request[R_FUNC] = funcId;
	request[R_PARAM] = param;

	if (g_Requests == Invalid_Array) {
		g_Requests = ArrayCreate(REQUEST);
	}
	new requestId = ArrayPushArray(g_Requests, request, sizeof request);

	curl_thread_exec(ch, "OnExecComplete", requestId);
	return 1;
}

public OnExecComplete(Handle:ch, CURLcode:code, const response[], const param) {
	curl_close(ch);
	new request[REQUEST];
	ArrayGetArray(g_Requests, param, request, sizeof request);
	curl_destroy_slist(request[R_SLIST]);
	json_free(request[R_DATA]);

	if (code != CURLE_OK) {
		callCallback(request[R_PLUGIN], request[R_FUNC], 0, Invalid_JSON, request[R_PARAM]);
	}
	new JSON:data = json_parse(response);
	if (!json_object_has_value(data, "success", JSONBoolean) || !json_object_get_bool(data, "success") || !json_object_has_value(data, "data")) {
		callCallback(request[R_PLUGIN], request[R_FUNC], 0, Invalid_JSON, request[R_PARAM]);
	}

	callCallback(request[R_PLUGIN], request[R_FUNC], 0, json_object_get_value(data, "data"), request[R_PARAM]);
	json_free(data);
}

callCallback(const pluginId, const funcId, const status, const JSON:data, const param) {
	if (callfunc_begin_i(funcId, pluginId) == 1) {
		callfunc_push_int(status);
		callfunc_push_int(_:data);
		callfunc_push_int(param);
		callfunc_end();
	}
}