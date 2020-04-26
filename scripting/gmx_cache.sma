#include <amxmodx>
#include <grip>
#include <gmx>

new BasePath[64];

public plugin_precache() {
	register_plugin("GM-X Cache", GMX_VERSION_STR, "GM-X Team");

	get_localinfo("amxx_datadir", BasePath, charsmax(BasePath));
	add(BasePath, charsmax(BasePath), "/gmx_cache");
	if (!dir_exists(BasePath)) {
		mkdir(BasePath);
	}
}

public plugin_natives() {
	register_native("GMX_CacheLoad", "NativeCacheLoad", 0);
	register_native("GMX_CacheSave", "NativeCacheSave", 0);
}

public bool:NativeCacheLoad(const plugin, const argc) {
	enum { arg_name = 1, arg_data };
	if (argc < arg_data) {
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", argc, arg_data);
		return false;
	}

	new name[64];
	get_string(arg_name, name, charsmax(name));
	new path[128];
	formatex(path, charsmax(path), "%s/%s.json", BasePath, name);
	if (!file_exists(path)) {
		return false;
	}

	new error[1];
	new GripJSONValue:data = grip_json_parse_file(path, error, charsmax(error));
	if (data == Invalid_GripJSONValue) {
		return false;
	}

	set_param_byref(arg_data, _:data);
	return true;
}

public bool:NativeCacheSave(const plugin, const argc) {
	enum { arg_name = 1, arg_data };
	if (argc < arg_data) {
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", argc, arg_data);
		return false;
	}

	new name[64];
	get_string(arg_name, name, charsmax(name));
	new path[128];
	formatex(path, charsmax(path), "%s/%s.json", BasePath, name);
	grip_json_serial_to_file(GripJSONValue:get_param(arg_data), path, false);
	return true;
}