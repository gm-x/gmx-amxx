#include <amxmodx>
#include <curl>
#include <reapi>
#include <json>

#define URL "http://127.0.0.1:8000/api/privileges"
#define JWT "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzUxMiJ9.eyJzZXJ2ZXJfaWQiOjF9.02FWNinIulC8QEoJ4yqMZs5p2ytd12_JMoIk8x7JxELINfajoebFISwTLMEaneLIcmt39pJ-hFyc9oVdJcnD8A"

enum AUTH_TYPE {
	AT_STEAMID,
	AT_STEAMID_PASS,
	AT_STEAMID_HASH,
	AT_NICK_PASS,
	AT_NICK_HASH,
}

enum _:PRIVILEGE {
	P_STEAMID[24],
	P_NICK[32],
	AUTH_TYPE:P_AUTH_TYPE,
	P_PASSWORD[34],
	P_PREFIX[32],
	P_FLAGS,
	P_EXPIRED
}

new Array:g_Privileges;

enum _:PLAYER_DATA {
	P_PREFIX[32],
	P_FLAGS,
	P_EXPIRED
}

// new g_Players[MAX_PLAYERS + 1][PLAYER_DATA];

public plugin_init() {
	g_Privileges = ArrayCreate(PRIVILEGE);
	register_srvcmd("amx_reloadadmins", "CmdReload");
}

public plugin_end() {
	ArrayDestroy(g_Privileges);
}

public client_authorized(id) {
	new steamid[24], nick[32];
	get_user_authid(id, steamid, charsmax(steamid));
	get_user_name(id, nick, charsmax(nick));

	new flags = 0;
	for (new i = 0, c = ArraySize(g_Privileges), privilege[PRIVILEGE], bool:found; i < c; i++) {
		ArrayGetArray(g_Privileges, i, privilege, sizeof privilege);
		switch (privilege[P_AUTH_TYPE]) {
			case AT_STEAMID: {
				found = bool:(equal(steamid, privilege[P_STEAMID]));
			}

			case AT_STEAMID_PASS: {
				found = bool:(equal(steamid, privilege[P_STEAMID]));
				if (found) {
					new infopassword[40], password[34];
					get_user_info(id, "_pw", infopassword, charsmax(infopassword));
					hash_string(infopassword, Hash_Sha256, password, charsmax(password));
					if (!equal(password, privilege[P_PASSWORD])) {
						found = false;
					}
				}
			}

			default: {
				found = false;
			}
		}


		if (!found) {
			continue;
		}

		flags |= privilege[P_FLAGS];
	}
	remove_user_flags(id);
	if (flags != 0) {
		set_user_flags(id, flags);
	} else {
		set_user_flags(id, ADMIN_USER);
	}
}

public CmdReload() {
	new CURLcode:code = CURLE_OK;

	new Handle:ch = curl_init();

	code = curl_setopt_string(ch, CURLOPT_URL, URL)
	if (code != CURLE_OK) {
		server_print("^t Can't set URL  '%s'", URL);
		return;
	}

	code = curl_setopt_cell(ch, CURLOPT_HTTPAUTH, 1)
	if (code != CURLE_OK) {
		server_print("^t Can't set HTTPAUTH");
		return;
	}


	code = curl_setopt_string(ch, CURLOPT_USERPWD, JWT)
	if (code != CURLE_OK) {
		server_print("^t Can't set JWT  '%s'", JWT);
		return;
	}

	curl_thread_exec(ch, "OnExecComplete");
}

public OnExecComplete(Handle:ch, CURLcode:code, const response[]) {
	curl_close(ch);
	
	if (code != CURLE_OK) {
		server_print("^t BAD response '%s'", response);
		return;
	}
	
	new JSON:data = json_parse(response, false, false);
	
	if (data == Invalid_JSON || json_get_type(data) != JSONObject) {
		server_print("^t invalid json '%s'", response);
		json_free(data);
		return;
	}
	
	if (!json_object_has_value(data, "privileges", JSONArray, false)) {
		server_print("^t BAD key privileges");
		json_free(data);
		return;
	}
	
	new JSON:privileges = json_object_get_value(data, "privileges", false);
	
	new count = json_array_get_count(privileges);
	
	for (new i = 0, JSON:privilege, priv[PRIVILEGE], authType[10]; i < count; i++) {
		privilege = json_array_get_value(privileges, i);
		if (json_get_type(privilege) != JSONObject) {
			json_free(privilege);
			continue;
		}
		
		json_object_get_string(privilege, "steamid", priv[P_STEAMID], 23, false);
		json_object_get_string(privilege, "nick", priv[P_NICK], 31, false);
		json_object_get_string(privilege, "auth_type", authType, 9, false);
		if (equal(authType, "steamid_pass")) {
			priv[P_AUTH_TYPE] = _:AT_STEAMID_PASS;
		} else if (equal(authType, "steamid_hash")) {
			priv[P_AUTH_TYPE] = _:AT_STEAMID_HASH;
		} else if (equal(authType, "nick_pass")) {
			priv[P_AUTH_TYPE] = _:AT_NICK_PASS;
		} else if (equal(authType, "nick_hash")) {
			priv[P_AUTH_TYPE] = _:AT_NICK_HASH;
		} else {
			priv[P_AUTH_TYPE] = _:AT_STEAMID;
		}
		json_object_get_string(privilege, "password", priv[P_PASSWORD], 33, false);
		json_object_get_string(privilege, "prefix", priv[P_PREFIX], 31, false);
		priv[P_FLAGS] = json_object_get_number(privilege, "flags", false);
		priv[P_EXPIRED] = json_object_get_number(privilege, "expired", false);
		
		ArrayPushArray(g_Privileges, priv, sizeof priv);
		
		json_free(privilege);
	}
	
	json_free(privileges);
	json_free(data);
}