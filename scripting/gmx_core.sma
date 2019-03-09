#include <amxmodx>
#include <json>
#include <grip>

#define MAX_DATA_LENGTH 6000

#define CHECK_NATIVE_ARGS_NUM(%1,%2) \
	if (%1 < %2) { \
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", %1, %2); \
		return 0; \
	}

enum _:REQUEST {
	RequestPluginId,
	RequestFuncId,
	RequestParam,
}

new Token[65], Url[256];
new GripRequestOptions:RequestOptions = Empty_GripRequestOptions;
new Array:Requests = Invalid_Array, Request[REQUEST];

public plugin_precache() {
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

public plugin_init() {
	register_plugin("GMX Core", "0.0.4", "F@nt0M");
}

public plugin_end() {
	if (Requests != Invalid_Array) {
		ArrayDestroy(Requests);
	}
	if (RequestOptions != Empty_GripRequestOptions) {
		grip_destroy_options(RequestOptions);
	}
}

public plugin_natives() {
	register_native("GamexMakeRequest", "NativeGamexMakeRequest", 0);
}

public NativeGamexMakeRequest(plugin, argc) {
	CHECK_NATIVE_ARGS_NUM(argc, 3)

	enum { arg_endpoint = 1, arg_data, arg_callback, arg_param };

	new endpoint[128];
	get_string(arg_endpoint, endpoint, charsmax(endpoint));

	new JSON:data = JSON:get_param(arg_data);
	new callback[64];
	get_string(arg_callback, callback, charsmax(callback));
	new funcId = get_func_id(callback, plugin);
	if (funcId == -1) {
		return -1;
	}

	return makeRequest(endpoint, data, plugin, funcId, argc >= 4 ? get_param(arg_param) : 0);
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
	if (body != Empty_GripBody) {
		grip_destroy_body(body);
	}
	return id;
}

public RequestHandler(const id) {
	if (id < 0 || id >= ArraySize(Requests)) {
		log_amx("Bad request id %d", id);
		return;
	}

	if (grip_get_response_state() != GripResponseStateSuccessful) {
		log_amx("Request state is %d", grip_get_response_state());
		callCallback(Request[RequestPluginId], Request[RequestFuncId], 0, Invalid_JSON, Request[RequestParam]);
		return;
	}

	if (grip_get_response_status_code() != GripHTTPStatusOk) {
		log_amx("Request status code is %d", grip_get_response_status_code());
		callCallback(Request[RequestPluginId], Request[RequestFuncId], 0, Invalid_JSON, Request[RequestParam]);
		return;
	}

	ArrayGetArray(Requests, id, Request, sizeof Request);
	new body[MAX_DATA_LENGTH];
	grip_get_response_body_string(body, charsmax(body));
	new JSON:data = json_parse(body);

	callCallback(Request[RequestPluginId], Request[RequestFuncId], data != Invalid_JSON ? 1 : 0, data, Request[RequestParam]);
	if (data != Invalid_JSON) {
		json_free(data);
	}
}

GripBody:getBody(const JSON:json) {
	if (json == Invalid_JSON) {
		return Empty_GripBody;
	}
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