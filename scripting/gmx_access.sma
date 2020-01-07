#pragma semicolon 1

#include <amxmodx>
#include <grip>
#include <gmx>
#include <gmx_cache>
#include <gmx_access>

const MAX_KEY_LENGTH = 32;

new Array:Keys, Array:Access, Count;

public plugin_init() {
	register_plugin("GMX Access", GMX_VERSION_STR, "GM-X Team");

	Keys = ArrayCreate(MAX_KEY_LENGTH, 0);
	Access = ArrayCreate(32, 0);
}

public plugin_end() {
	ArrayDestroy(Keys);
	ArrayDestroy(Access);
}

public plugin_natives() {
	register_native("GMX_AccessGetPointer", "NativeGetPointer", 0);
	register_native("GMX_AccessGetKey", "NativeGetKey", 0);
	register_native("GMX_PlayerHasAccess", "NativeHasAccess", 0);
	register_native("GMX_PlayerHasPAccess", "NativeHasPAccess", 0);
}

public GMX_Init() {
	new GripJSONValue:data;
	if (GMX_CacheLoad("access", data)) {
		parseList(data);
		grip_destroy_json_value(data);
	} else {
		GMX_MakeRequest("server/access", Invalid_GripJSONValue, "OnList");
	}
}

public GMX_PlayerLoading(const id) {
	for (new i = 0; i < Count; i++) {
		ArraySetCell(Access, i, 0, id - 1);
	}
}

public GMX_PlayerLoaded(const id, GripJSONValue:data) {
	new GripJSONValue:access = grip_json_object_get_value(data, "access");
	if (access == Invalid_GripJSONValue) {
		return;
	}
	
	for (new i = 0, n = grip_json_array_get_count(access), key[MAX_KEY_LENGTH], index; i < n; i++) {
		grip_json_array_get_string(access, i, key, charsmax(key));
		index = ArrayFindString(Keys, key);
		if (index >= 0) {
			ArraySetCell(Access, i, 1, id - 1);
		}
		
	}
	grip_destroy_json_value(access);
}

public OnList(const GmxResponseStatus:status, const GripJSONValue:data) {
	if (status != GmxResponseStatusOk) {
		return;
	}

	if (grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	new GripJSONValue:tmp;
	tmp = grip_json_object_get_value(data, "list");
	parseList(tmp);
	GMX_CacheSave("access", tmp);
	grip_destroy_json_value(tmp);
}

public GMX_PlayerAccess:NativeGetPointer(const plugin, const argc) {
	enum { arg_key = 1 };
	if (argc < arg_key) {
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", argc, arg_key);
		return GMX_InvalidPlayerAccess;
	}

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));
	return GMX_PlayerAccess:ArrayFindString(Keys, key);
}

public NativeGetKey(const plugin, const argc) {
	enum { arg_pointer = 1, arg_key, arg_length };
	if (argc < arg_length) {
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", argc, arg_length);
		return 0;
	}

	new pointer = get_param(arg_pointer);
	if (!(0 <= pointer < Count)) {
		log_error(AMX_ERR_NATIVE, "Invalid pointer %d", pointer);
		return 0;
	}

	new key[MAX_KEY_LENGTH];
	ArrayGetString(Keys, pointer, key, charsmax(key));
	return set_string(arg_key, key, get_param(arg_length));
}

public bool:NativeHasAccess(const plugin, const argc) {
	enum { arg_player = 1, arg_key };
	if (argc < arg_key) {
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", argc, arg_key);
		return false;
	}

	new player = get_param(arg_player);
	if (!is_user_connected(player)) {
        log_error(AMX_ERR_NATIVE, "Invalid player %d", player);
        return false;
    }

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));
	new pointer = ArrayFindString(Keys, key);
	if (pointer == -1) {
		return false;
	}

	return bool:ArrayGetCell(Access, pointer, player - 1);
}

public bool:NativeHasPAccess(const plugin, const argc) {
	enum { arg_player = 1, arg_pointer };
	if (argc < arg_pointer) {
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", argc, arg_pointer);
		return false;
	}

	new player = get_param(arg_player);
	if (!is_user_connected(player)) {
        log_error(AMX_ERR_NATIVE, "Invalid player %d", player);
        return false;
    }

	new pointer = get_param(arg_pointer);
	if (!(0 <= pointer < Count)) {
		log_error(AMX_ERR_NATIVE, "Invalid pointer %d", pointer);
		return false;
	}

	return bool:ArrayGetCell(Access, pointer, player - 1);
}

parseList(const GripJSONValue:data) {
	for (new i = 0, n = grip_json_array_get_count(data), GripJSONValue:tmp, key[MAX_KEY_LENGTH]; i < n; i++) {
		tmp = grip_json_array_get_value(data, i);
		if (grip_json_get_type(tmp) == GripJSONObject) {
			grip_json_object_get_string(tmp, "key", key, charsmax(key));
			ArrayPushString(Keys, key);
			ArrayPushCell(Access, 0);
		}
		grip_destroy_json_value(tmp);
	}

	Count = ArraySize(Keys);

	new fwd = CreateMultiForward("GMX_AccessInit", ET_IGNORE);
	new ret;
	ExecuteForward(fwd, ret);
	DestroyForward(fwd);
}

/*

public bool:NativeHasAccess(const plugin, const argc) {
	enum { arg_player = 1, arg_key };

	if (argc < arg_key) {
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", argc, arg_key);
		return false;
	}

	new player = get_param(arg_player);
	if (!is_user_connected(player) || !GMX_PlayerIsLoaded(player)) {
        log_error(AMX_ERR_NATIVE, "Invalid player %d", player);
        return false;
    }

	if (PlayersAccess[player] == Invalid_Array) {
		return false;
	}

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));
	return bool:(ArrayFindString(PlayersAccess[player], key) != -1);
}
*/