#include <amxmodx>
#include <grip>
#include <gmx>

#define GMX_VERSION \
    fmt( \
        "%d.%d.%d",    \
         GMX_MAJOR_VERSION, \
         GMX_MINOR_VERSION, \
         GMX_MAINTENANCE_VERSION \
    )


enum _:REQUEST {
	RequestPluginId,
	RequestFuncId,
	RequestParam,
};

new PluginId, bool:ApiEnabled = true, LogFile;
new Token[GMX_MAX_API_TOKEN_LENGTH], Url[GMX_MAX_URL_LENGTH], GmxLogLevel:LogLvl;
new GripRequestOptions:RequestOptions = Empty_GripRequestOptions;
new Array:Requests = Invalid_Array, Request[REQUEST];

public plugin_precache() {
	PluginId = register_plugin("GMX Core", GMX_VERSION, "GM-X Team");

	new path[GMX_MAX_PATH_LENGTH];
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
	makeInfoRequest();
}

public plugin_cfg() {
	CheckCoreVersion();
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

public CmdReloadConfig(id, level) {
	if (~get_user_flags(id) & level) {
		console_print(id, "You have no access to that command");
		return PLUGIN_HANDLED;
	}

	loadConfig();
	makeInfoRequest();

	return PLUGIN_HANDLED;
}

public OnInfoResponse(const GmxResponseStatus:status) {
	switch (status) {
		case GmxResponseStatusOk: {
			set_task(60.0, "TaskPing", .flags = "b");
		}

		case GmxResponseStatusBadToken: {
			ApiEnabled = false;
			logToFile(GmxLogError, "Bad token. Change valid in gmx.json and reload config");
		}
	}
}

public TaskPing() {
	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_number(data, "num_players", get_playersnum());
	makeRequest("server/ping", data);
	grip_destroy_json_value(data);
}

loadConfig() {
	new filePath[GMX_MAX_PATH_LENGTH];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	add(filePath, charsmax(filePath), "/gmx.json");

	new error[GMX_MAX_ERROR_MSG_LENGTH];
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
	new GripJSONValue:data = grip_json_init_object();

	grip_json_object_set_string(data, "map", MapName);
	grip_json_object_set_number(data, "max_players", MaxClients);
	makeRequest("server/info", data, PluginId, get_func_id("OnInfoResponse"));
	grip_destroy_json_value(data);
}

public plugin_natives() {
	register_native("GMX_MakeRequest", "NativeMakeRequest", 0);
	register_native("GMX_Log", "NativeLog", 0);
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

	new message[GMX_MAX_LOG_MSG_LENGTH];
	vdformat(message, charsmax(message), arg_fmt, arg_params);
	logToFile(GmxLogLevel:get_param(arg_level), message);
	return 1;
}

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
				new err[GMX_MAX_ERROR_MSG_LENGTH];
				grip_get_error_description(err, charsmax(err))
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

	new error[GMX_MAX_ERROR_MSG_LENGTH];
	new GripJSONValue:data = grip_json_parse_response_body(error, charsmax(error));

	if (data == Invalid_GripJSONValue) {
		logToFile(GmxLogInfo, "Error parse response: %s", error);
		callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusBadResponse, Invalid_GripJSONValue, Request[RequestParam]);
		return;
	}

	callCallback(Request[RequestPluginId], Request[RequestFuncId], GmxResponseStatusOk, data, Request[RequestParam]);
	grip_destroy_json_value(data);
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

	new message[GMX_MAX_LOG_MSG_LENGTH];
	vformat(message, charsmax(message), msg, 3);

	new hour, minute, second;
	time(hour, minute, second);

	server_print("[GMX] %02d:%02d:%02d: %s", hour, minute, second, message)
	
	fprintf(LogFile, "%02d:%02d:%02d: %s^n", hour, minute, second, message);
	fflush(LogFile);
}

CheckCoreVersion() {
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
