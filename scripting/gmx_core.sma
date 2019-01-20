#include <amxmodx>
#include <json>
#include <grip>

enum _:REQUEST {
	RequestPluginId,
	RequestFuncId,
	RequestParam,
}

new Token[65], Url[256];
new GripRequestOptions:RequestOptions = Empty_GripRequestOptions;
new Array:Requests = Invalid_Array, Request[REQUEST];

public plugin_init() {
	register_plugin("GMX Core", "0.0.3", "F@nt0M");
}

public plugin_end() {
	if (Requests != Invalid_Array) {
		ArrayDestroy(Requests);
	}
	if (RequestOptions != Empty_GripRequestOptions) {
		grip_destroy_options(RequestOptions);
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

	json_object_get_string(cfg, "token", Token, charsmax(Token));
	json_object_get_string(cfg, "url", Url, charsmax(Url));

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

	new JSON:data = JSON:get_param_byref(2);
	new callback[64];
	get_string(3, callback, charsmax(callback));
	new funcId = get_func_id(callback, pluginId);
	if (funcId == -1) {
		return -1;
	}

	return makeRequest(endpoint, data, pluginId, funcId, paramNums >= 4 ? get_param(4) : 0);
}

makeRequest(const endpoint[], JSON:data, const pluginId, const funcId, const param) {
	if (RequestOptions == Empty_GripRequestOptions) {
		RequestOptions = grip_create_default_options();
		grip_options_add_header(RequestOptions, "Content-Type", "application/json");
		grip_options_add_header(RequestOptions, "User-Agent", "Grip");
		grip_options_add_header(RequestOptions, "Authorization", fmt("Token %s", Token));
	}

	Request[RequestPluginId] = pluginId;
	Request[RequestFuncId] = funcId;
	Request[RequestParam] = param;

	if (Requests == Invalid_Array) {
		Requests = ArrayCreate(REQUEST);
	}
	new id = ArrayPushArray(Requests, Request, sizeof Request);

	new GripBody:body = getBody(data);
	grip_request(fmt("%s/api/%s", Url, endpoint), body, GripRequestTypePost, "RequestHandler", RequestOptions, id);
	grip_destroy_body(body);
	return id;
}

public RequestHandler(const id) {
	if (grip_get_response_state() != GripResponseStateSuccessful) {
		return;
	}

	if (id < 0 || id >= ArraySize(Requests)) {
		return;
	}

	ArrayGetArray(Requests, id, Request, sizeof Request);

	new JSON:data = Invalid_JSON;

	new body[2000];
	grip_get_response_body_string(body, charsmax(body));
	data = json_parse(body);

	// TODO: Add retry
	if (data != Invalid_JSON && json_object_has_value(data, "success", JSONBoolean) && json_object_get_bool(data, "success")) {
		callCallback(Request[RequestPluginId], Request[RequestFuncId], 1, data, Request[RequestParam]);
		json_free(data);
	}
}

GripBody:getBody(const JSON:json) {
	new data[2000];
	json_serial_to_string(json, data, charsmax(data));
	return grip_body_from_string(data);
}

callCallback(const pluginId, const funcId, const status, const JSON:data, const param) {
	if (callfunc_begin_i(funcId, pluginId) == 1) {
		callfunc_push_int(status);
		callfunc_push_int(_:data);
		callfunc_push_int(param);
		callfunc_end();
	}
}