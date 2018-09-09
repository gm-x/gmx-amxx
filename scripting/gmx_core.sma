#include <amxmodx>
#include <curl>
#include <json>

enum _:REQUEST {
	R_ID,
	Handle:R_SLIST,
	R_PLUGIN,
	R_FUNC,
	R_PARAM,
	R_RETRY
}

new Array:g_Requests = Invalid_Array;
new g_Token[65], g_Url[128], g_Retries;
new g_RequestsNum = 0;

public plugin_init() {
	register_plugin("GameX Config", "0.1", "F@nt0M");
}

public plugin_end() {
	if (g_Requests != Invalid_Array) {
		ArrayDestroy(g_Requests);
	}
}

public plugin_cfg() {
	new filePath[128];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	add(filePath, charsmax(filePath), "/gmx.json");
	new JSON:cfg = json_parse(filePath, true, true);
	if (cfg == Invalid_JSON || !json_is_object(cfg)) {
		json_free(cfg);
		set_fail_state("Coudn't open %s", filePath);
		return;
	}

	json_object_get_string(cfg, "token", g_Token, charsmax(g_Token));
	json_object_get_string(cfg, "url", g_Url, charsmax(g_Url));
	g_Retries = json_object_get_number(cfg, "retries");

	json_free(cfg);

	new fwd = CreateMultiForward("GamexCfgLoaded", ET_IGNORE);
	new ret;
	ExecuteForward(fwd, ret);
	DestroyForward(fwd);
}

public plugin_natives() {
	register_native("GamexMakeRequest", "NativeGamexMakeRequest", 0);
}

public NativeGamexMakeRequest(pluginId, paramNums) {
	if (paramNums < 3) {
		return 0;
	}

	new endpoint[128];
	get_string(1, endpoint, charsmax(endpoint));
	format(endpoint, charsmax(endpoint), "%s/api/%s", g_Url, endpoint);

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

#define makeRequestCheckCode() \
	if (code != CURLE_OK) { \
		clearRequest(ch, slist); \
		return 0; \
	}
makeRequest(const url[], &JSON:data, const pluginId, const funcId, const param) {
	new request[REQUEST];

	new CURLcode:code = CURLE_OK;
	new Handle:slist = INVALID;

	new Handle:ch = curl_init();
	if (ch == INVALID) {
		return 0;
	}

	code = curl_setopt_string(ch, CURLOPT_URL, url)
	makeRequestCheckCode()

	code = curl_setopt_cell(ch, CURLOPT_CONNECTTIMEOUT, 15)
	makeRequestCheckCode()

	code = curl_setopt_cell(ch, CURLOPT_TIMEOUT, 15)
	makeRequestCheckCode()

	code = curl_setopt_cell(ch, CURLOPT_POST, 1);
	makeRequestCheckCode()

	code = curl_setopt_cell(ch, CURLOPT_HTTPAUTH, 1)
	makeRequestCheckCode()

	new post[2048];
	json_serial_to_string(data, post, charsmax(post), false);
	code = curl_setopt_string(ch, CURLOPT_POSTFIELDS, post);
	makeRequestCheckCode()

	slist = curl_create_slist();
	if (slist == INVALID) {
		clearRequest(ch, slist);
		return 0;
	}

	if (!curl_slist_append(slist, "Content-Type: application/json")) {
		clearRequest(ch, slist);
		return 0;
	}

	new token[128];
	formatex(token, charsmax(token), "Authorization: Token %s", g_Token);
	if (!curl_slist_append(slist, token)) {
		clearRequest(ch, slist);
		return 0;
	}

	code = curl_setopt_handle(ch, CURLOPT_HTTPHEADER, slist);
	makeRequestCheckCode()

	request[R_ID] = g_RequestsNum;
	request[R_SLIST] = slist;
	request[R_PLUGIN] = pluginId;
	request[R_FUNC] = funcId;
	request[R_PARAM] = param;
	request[R_RETRY] = 0;

	if (g_Requests == Invalid_Array) {
		g_Requests = ArrayCreate(REQUEST);
	}
	ArrayPushArray(g_Requests, request, sizeof request);

	curl_thread_exec(ch, "OnExecComplete", g_RequestsNum);
	g_RequestsNum++;
	return 1;
}

public OnExecComplete(Handle:ch, CURLcode:code, const response[], const param) {
	new request[REQUEST];
	new requestId = getRequest(param, request);
	if (requestId == -1) {
		curl_close(ch);
		return;
	}

	new JSON:data = Invalid_JSON;
	if (code == CURLE_OK) {
		data = json_parse(response);
	}

	if (data != Invalid_JSON && json_object_has_value(data, "success", JSONBoolean) && json_object_get_bool(data, "success")) {
		callCallback(request[R_PLUGIN], request[R_FUNC], 1, data, request[R_PARAM]);
		clearRequest(ch, request[R_SLIST], requestId);
		json_free(data);
	} else if (++request[R_RETRY] >= g_Retries) {
		callCallback(request[R_PLUGIN], request[R_FUNC], 0, Invalid_JSON, request[R_PARAM]);
		clearRequest(ch, request[R_SLIST], requestId);
		if (data != Invalid_JSON) {
			json_free(data);
		}
	} else {
		ArraySetArray(g_Requests, requestId, request, sizeof request);
		curl_thread_exec(ch, "OnExecComplete", param);
		if (data != Invalid_JSON) {
			json_free(data);
		}
	}
}

getRequest(id, request[REQUEST]) {
	for (new i = 0, n = ArraySize(g_Requests); i < n; i++) {
		if (ArrayGetArray(g_Requests, i, request, sizeof request) && request[R_ID] == id) {
			return i;
		}
	}

	return -1;
}

callCallback(const pluginId, const funcId, const status, const JSON:data, const param) {
	if (callfunc_begin_i(funcId, pluginId) == 1) {
		callfunc_push_int(status);
		callfunc_push_int(_:data);
		callfunc_push_int(param);
		callfunc_end();
	}
}

clearRequest(const Handle:ch, const Handle:slist = INVALID, const requestId = -1) {
	curl_close(ch);
	if (ch != INVALID) {
		curl_destroy_slist(slist);
	}
	
	if (requestId >= 0) {
		ArrayDeleteItem(g_Requests, requestId);
	}
}