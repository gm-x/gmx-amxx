#if defined _gmx_included
	#endinput
#endif

#define _gmx_included

#include <gmx_consts>
#include <gmx_version>

/**
 * Called when the config was loaded.
 *
 * @noreturn
 */
forward GMX_CfgLoaded();

/**
 * Description.
 *
 * @noreturn
 */
forward GMX_Init();

/**
 * Called when a player is loading.
 *
 * @return              PLUGIN_CONTINUE to let the client load
 *                      PLUGIN_HANDLED to prevent the client to load
 */
forward GMX_PlayerLoading(const id);

/**
 * Called when a player was loaded.
 *
 * @param id            Client index
 * @param data          --- Description ---
 *
 * @noreturn
 */
forward GMX_PlayerLoaded(const id, GripJSONValue:data);

/**
 * Called when a player is disconnecting.
 *
 * @return              PLUGIN_CONTINUE to let saving information about player's disconnection
 *                      PLUGIN_HANDLED to prevent saving information about player's disconnection
 */
forward GMX_PlayerDisconnecting(const id);

/**
 * Makes request to API.
 *
 * @param endpoint      --- Description ---
 * @param data          --- Description ---
 * @param callback      --- Description ---
 * @param param         --- Description ---
 *
 * @return              ID of request, -1 if error occurred
 * @error               If an invalid number of arguments is set, or API is not enabled, or an
 *                      invalid callback function is provided, an error will be thrown.
 */
native GMX_MakeRequest(const endpoint[], GripJSONValue:data, const callback[] = "", const param = 0);

/**
 * Makes request to API.
 *
 * @param level         Logging level
 * @param fmt           Formatting rules
 * @param ...           Variable number of formatting parameters
 *
 * @return              1 on success, 0 otherwise
 */
native GMX_Log(const GmxLogLevel:level, const fmt[], any:...);

/**
 * Returns server ID
 *
 * @return              server ID
 */
native GMX_GetServerID();

/**
 * Returns time on api part in unix timestamp
 *
 * @return              unix timestamp
 */
native GMX_GetServerTime();

/**
 * Returns diff from server time and api part time in seconds
 *
 * @return              seconds
 */
native GMX_GetServerTimeDiff();

/**
 * Checks if player is loaded.
 *
 * @param id            Client index
 *
 * @return              true if loaded, false otherwise
 * @error               If an invalid number of arguments is set, an error will be thrown.
 */
native bool:GMX_PlayerIsLoaded(const id);

/**
 * Returns player's ID.
 *
 * @param id            Client index
 *
 * @return              Player's ID if it was found
 * @error               If the index is not within the range of 1 to MaxClients,
 *                      or an invalid number of arguments is set, or player is not
 *                      loaded, an error will be thrown.
 */
native GMX_PlayerGetPlayerId(const id);

/**
 * Returns player's user ID.
 *
 * @param id            Client index
 *
 * @return              Player's user ID if it was found
 * @error               If the index is not within the range of 1 to MaxClients,
 *                      or an invalid number of arguments is set, or player is not
 *                      loaded, an error will be thrown.
 */
native GMX_PlayerGetUserId(const id);

/**
 * Returns player's session ID.
 *
 * @param id            Client index
 *
 * @return              Player's session ID if it was found
 * @error               If the index is not within the range of 1 to MaxClients,
 *                      or an invalid number of arguments is set, or player is not
 *                      loaded, an error will be thrown.
 */
native GMX_PlayerGetSessionId(const id);

/**
 * Returns player's immunity level.
 *
 * @param id            Client index
 *
 * @return              Player's immunity level if it was found
 * @error               If the index is not within the range of 1 to MaxClients,
 *                      or an invalid number of arguments is set, or player is not
 *                      loaded, an error will be thrown.
 */
native GMX_PlayerGetImmunity(const id);

/*
* This is callback from GMX Core that gives major/minor versions for verifying compatibility for GMX versions.
* Do not modify this!
*/
public __gmx_version_check(const majorVersion, const minorVersion) {
	if(majorVersion != GMX_MAJOR_VERSION) {
		set_fail_state("Api major version mismatch; expected %d, real %d", GMX_MAJOR_VERSION, majorVersion);
		return;
	}

	if(minorVersion < GMX_MINOR_VERSION){
		set_fail_state("Api minor version mismatch; expected at least %d, real %d", GMX_MINOR_VERSION, minorVersion);
		return;
	}
}
