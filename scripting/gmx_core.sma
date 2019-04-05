#include <amxmodx>
#include <reapi>
#include <grip>
#include <json>

#define MAX_DATA_LENGTH 4000

#define CHECK_NATIVE_ARGS_NUM(%1,%2) \
	if (%1 < %2) { \
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", %1, %2); \
		return -1; \
	}

enum LogLevel (+=1) {
	LOG_CRITICAL = 0,
	LOG_ERROR,
	LOG_INFO,
	LOG_DEBUG
};

enum _:REQUEST {
	RequestPluginId,
	RequestFuncId,
	RequestParam,
};

new Token[65], Url[256], LogLevel:LogLvl;
new LogFile;
new GripRequestOptions:RequestOptions = Empty_GripRequestOptions;
new Array:Requests = Invalid_Array, Request[REQUEST];

public plugin_precache() {
	register_plugin("GMX Core", "0.0.4", "F@nt0M");

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

	new filePath[128];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	add(filePath, charsmax(filePath), "/gmx.json");
	new JSON:cfg = json_parse(filePath, true, true);
	if (cfg == Invalid_JSON || !json_is_object(cfg)) {
		json_free(cfg);
		set_fail_state("Coudn't open %s", filePath);
	}

	json_object_get_string(cfg, "token", Token, charsmax(Token));
	json_object_get_string(cfg, "url", Url, charsmax(Url));
	LogLvl = LogLevel:json_object_get_number(cfg, "loglevel");

	logToFile(LOG_DEBUG, "Load configuration. URL is '%s'", Url);

	json_free(cfg);

	new fwd = CreateMultiForward("GamexCfgLoaded", ET_IGNORE);
	new ret;
	ExecuteForward(fwd, ret);
	DestroyForward(fwd);

	new map[64];
	rh_get_mapname(map, charsmax(map), MNT_TRUE);
	new JSON:data = json_init_object();
	json_object_set_string(data, "map", map);
	json_object_set_number(data, "max_players", MaxClients);
	makeRequest("server/info", data);
	json_free(data);

	set_task(60.0, "TaskPing", .flags = "b");
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

public TaskPing() {
	makeRequest("server/ping");
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

	logToFile(LOG_DEBUG, "Call make request to '%s' with callback '%s'", endpoint, callback);

	return makeRequest(endpoint, data, plugin, funcId, argc >= 4 ? get_param(arg_param) : 0);
}

makeRequest(const endpoint[], JSON:data = Invalid_JSON, const pluginId = INVALID_PLUGIN_ID, const funcId = INVALID_PLUGIN_ID, const param = 0) {
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
	logToFile(LOG_DEBUG, "Make request to '%s/api/%s'. Request ID %d", Url, endpoint, id);

	new GripBody:body = getBody(data);
	grip_request(fmt("%s/api/%s", Url, endpoint), body, GripRequestTypePost, "RequestHandler", RequestOptions, id);
	if (body != Empty_GripBody) {
		grip_destroy_body(body);
	}
	return id;
}

public RequestHandler(const id) {
	if (id < 0 || id >= ArraySize(Requests)) {
		logToFile(LOG_ERROR, "Bad request id %d", id);
		return;
	}

	if (grip_get_response_state() != GripResponseStateSuccessful) {
		switch (grip_get_response_state()) {
			case GripResponseStateCancelled: {
				logToFile(LOG_INFO, "Request %d was cancaled", id);
			}
			case GripResponseStateError: {
				new err[256];
				grip_get_error_description(err, charsmax(err))
				logToFile(LOG_ERROR, "Request %d finished with error: %s", id, err);
			}
			case GripResponseStateTimeout: {
				logToFile(LOG_ERROR, "Request %d finished with timeout", id);
			}
		}
		callCallback(Request[RequestPluginId], Request[RequestFuncId], 0, Invalid_GripJSONValue, Request[RequestParam]);
		return;
	}

	if (grip_get_response_status_code() != GripHTTPStatusOk) {
		logToFile(LOG_INFO, "Request %d finished with %d status", id, grip_get_response_status_code());
		callCallback(Request[RequestPluginId], Request[RequestFuncId], 0, Invalid_GripJSONValue, Request[RequestParam]);
		return;
	}

	ArrayGetArray(Requests, id, Request, sizeof Request);
	new error[128];
	new GripJSONValue:data = grip_json_parse_response_body(error, charsmax(error))
	if (data == Invalid_GripJSONValue) {
		logToFile(LOG_INFO, "Error parse response: %s", error);
		callCallback(Request[RequestPluginId], Request[RequestFuncId], 0, Invalid_GripJSONValue, Request[RequestParam]);
		return;
	}

	callCallback(Request[RequestPluginId], Request[RequestFuncId], 1, data, Request[RequestParam]);
	grip_destroy_json_value(data);
}

GripBody:getBody(const JSON:json) {
	if (json == Invalid_JSON) {
		return Empty_GripBody;
	}
	new data[2000];
	json_serial_to_string(json, data, charsmax(data));
	logToFile(LOG_DEBUG, "Data: '%s'", data);
	return grip_body_from_string(data);
}

callCallback(const pluginId, const funcId, const status, const GripJSONValue:data, const param) {
	if (pluginId != INVALID_PLUGIN_ID && funcId != INVALID_PLUGIN_ID && callfunc_begin_i(funcId, pluginId) == 1) {
		callfunc_push_int(status);
		callfunc_push_int(_:data);
		callfunc_push_int(param);
		callfunc_end();
	}
}

logToFile(const LogLevel:level, const msg[], any:...) {
	if (level > LogLvl) {
		return;
	}

	new message[512];
	vformat(message, charsmax(message), msg, 3);

	new hour, minute, second;
	time(hour, minute, second);

	server_print("[GMX] %02d:%02d:%02d: %s", hour, minute, second, message)
	
	fprintf(LogFile, "%02d:%02d:%02d: %s^n", hour, minute, second, message);
	fflush(LogFile);
}