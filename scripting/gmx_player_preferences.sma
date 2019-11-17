#pragma semicolon 1

#include <amxmodx>
#include <gmx>
#include <grip>

#define CHECK_NATIVE_ARGS_NUM(%1,%2,%3) \
	if (%1 < %2) { \
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", %1, %2); \
		return %3; \
	}

#define CHECK_NATIVE_PLAYER(%1,%2) \
    if (!is_user_connected(%1) || !GMX_PlayerIsLoaded(%1)) { \
        log_error(AMX_ERR_NATIVE, "Invalid player %d", %1); \
        return %2; \
    }
    
const MAX_KEY_LENGTH = 32;
const MAX_VALUE_STRING_LENGTH = 32;

enum FWD {
	FWD_PlayerLoading,
	FWD_PlayerLoaded,
	FWD_PlayerKeyChanged,
}

new Forwards[FWD], FwdReturn;

new Trie:PlayersPreferences[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin("GMX Player Preferences", GMX_VERSION_STR, "GM-X Team");

	arrayset(PlayersPreferences, Invalid_Trie, sizeof PlayersPreferences);
	
	Forwards[FWD_PlayerLoading] = CreateMultiForward("GMX_PP_PlayerLoading", ET_IGNORE, FP_CELL);
	Forwards[FWD_PlayerLoaded] = CreateMultiForward("GMX_PP_PlayerLoaded", ET_IGNORE, FP_CELL);
	Forwards[FWD_PlayerKeyChanged] = CreateMultiForward("APS_PlayerKeyChanged", ET_IGNORE, FP_CELL, FP_STRING);
}

public plugin_end() {
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (PlayersPreferences[i] != Invalid_Trie) {
			TrieDestroy(PlayersPreferences[i]);
		}
	}
	
	DestroyForward(Forwards[FWD_PlayerLoading]);
	DestroyForward(Forwards[FWD_PlayerLoaded]);
	DestroyForward(Forwards[FWD_PlayerKeyChanged]);
}

public GMX_PlayerLoading(const id) {
	ExecuteForward(Forwards[FWD_PlayerLoading], FwdReturn, id);
}

public GMX_PlayerLoaded(const id, GripJSONValue:data) {
	if (PlayersPreferences[id] == Invalid_Trie) {
		PlayersPreferences[id] = TrieCreate();
	} else {
		TrieClear(PlayersPreferences[id]);
	}
	
	new GripJSONValue:preferences = grip_json_object_get_value(data, "preferences");
	if (preferences == Invalid_GripJSONValue) {
		return;
	}
	
	for (new i = 0, n = grip_json_object_get_count(preferences), GripJSONValue:element, key[MAX_KEY_LENGTH], value[MAX_VALUE_STRING_LENGTH]; i < n; i++) {
		grip_json_object_get_name(preferences, i, key, charsmax(key));
		element = grip_json_object_get_value_at(preferences, i);
		switch (grip_json_get_type(element)) {
			case GripJSONString: {
				grip_json_get_string(element, value, charsmax(value));
				TrieSetString(PlayersPreferences[id], key, value);
			}
			case GripJSONNumber: {
				TrieSetCell(PlayersPreferences[id], key, grip_json_get_number(element));
			}
			case GripJSONBoolean: {
				TrieSetCell(PlayersPreferences[id], key, grip_json_get_bool(element) ? 1 : 0);
			}
		}
		grip_destroy_json_value(element);
	}
	grip_destroy_json_value(preferences);
	
	ExecuteForward(Forwards[FWD_PlayerLoaded], FwdReturn, id);
}

public plugin_natives() {
	register_native("GMX_PP_HasKey", "NativeHasKey", 0);
	register_native("GMX_PP_GetString", "NativeGetString", 0);
	register_native("GMX_PP_SetString", "NativeSetString", 0);
	register_native("GMX_PP_GetNumber", "NativeGetNumber", 0);
	register_native("GMX_PP_SetNumber", "NativeSetNumber", 0);
	register_native("GMX_PP_GetBool", "NativeGetBool", 0);
	register_native("GMX_PP_SetBool", "NativeSetBool", 0);
	register_native("GMX_PP_GetFloat", "NativeGetFloat", 0);
	register_native("GMX_PP_SetFloat", "NativeSetFloat", 0);
}

public bool:NativeHasKey(plugin, argc) {
	enum { arg_player = 1, arg_key };

	CHECK_NATIVE_ARGS_NUM(argc, 2, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	return TrieKeyExists(PlayersPreferences[player], key);
}

public NativeGetString(plugin, argc) {
	enum { arg_player = 1, arg_key, arg_dest, arg_length, arg_default };

	CHECK_NATIVE_ARGS_NUM(argc, 4, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	new key[MAX_KEY_LENGTH], value[MAX_VALUE_STRING_LENGTH];
	get_string(arg_key, key, charsmax(key));
	if (TrieKeyExists(PlayersPreferences[player], key)) {
		TrieGetString(PlayersPreferences[player], key, value, charsmax(value));
	} else if (argc >= arg_default) {
		get_string(arg_default, value, charsmax(value));
	}
	return set_string(arg_dest, value, get_param(arg_length));
}

public NativeSetString(plugin, argc) {
	enum { arg_player = 1, arg_key, arg_value };

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0)

	new key[MAX_KEY_LENGTH], value[MAX_VALUE_STRING_LENGTH];
	get_string(arg_key, key, charsmax(key));
	get_string(arg_value, value, charsmax(value));
	TrieSetString(PlayersPreferences[player], key, value);

	return setValue(player, key, grip_json_init_string(value));
}

public NativeGetNumber(plugin, argc) {
	enum { arg_player = 1, arg_key, arg_default };

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));
	if (!TrieKeyExists(PlayersPreferences[player], key)) {
		return argc >= arg_default ? get_param(arg_default) : 0;
	}

	new value;
	TrieGetCell(PlayersPreferences[player], key, value);
	return value;
}

public NativeSetNumber(plugin, argc) {
	enum { arg_player = 1, arg_key, arg_value };

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new value = get_param(arg_value);
	TrieSetCell(PlayersPreferences[player], key, value);

	return setValue(player, key, grip_json_init_number(value));
}

public bool:NativeGetBool(plugin, argc) {
	enum { arg_player = 1, arg_key, arg_default };

	CHECK_NATIVE_ARGS_NUM(argc, 2, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));
	if (!TrieKeyExists(PlayersPreferences[player], key)) {
		if (argc >= arg_default) {
			return bool:get_param(arg_default);
		}
		return false;
	}

	new value;
	TrieGetCell(PlayersPreferences[player], key, value);
	return value ? true : false;
}

public NativeSetBool(plugin, argc) {
	enum { arg_player = 1, arg_key, arg_value };

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new bool:value = bool:get_param(arg_value);
	TrieSetCell(PlayersPreferences[player], key, value ? 1 : 0);

	return setValue(player, key, grip_json_init_bool(value));
}

public Float:NativeGetFloat(plugin, argc) {
	enum { arg_player = 1, arg_key, arg_default };

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0.0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0.0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));
	if (!TrieKeyExists(PlayersPreferences[player], key)) {
		return (argc >= arg_default) ? get_param_f(arg_default) : 0.0;
	}

	new value;
	TrieGetCell(PlayersPreferences[player], key, value);
	return Float:value;
}

public NativeSetFloat(plugin, argc) {
	enum { arg_player = 1, arg_key, arg_value };

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new Float:value = get_param_f(arg_value);
	TrieSetCell(PlayersPreferences[player], key, value);

	return setValue(player, key, grip_json_init_number(cell:value));
}

setValue(const player, const key[], const GripJSONValue:value) {
	if (!GMX_PlayerIsLoaded(player)) {
		ExecuteForward(Forwards[FWD_PlayerKeyChanged], FwdReturn, player, key);
		return 0;
	}

	new GripJSONValue:request = grip_json_init_object();
	grip_json_object_set_number(request, "player_id", GMX_PlayerGetPlayerId(player));

	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_value(data, key, value);
	grip_json_object_set_value(request, "data", data);

	GMX_MakeRequest("player/preferences", request);

	grip_destroy_json_value(value);
	grip_destroy_json_value(data);
	grip_destroy_json_value(request);

	ExecuteForward(Forwards[FWD_PlayerKeyChanged], FwdReturn, player, key);
	return 1;
}
