#if defined _gmx_player_preferences_included
	#endinput
#endif

#define _gmx_player_preferences_included

/**
 * Called when a player is loading.
 *
 * @param id                Client index
 *
 * @noreturn
 */
forward GMX_PP_PlayerLoading(const id);

/**
 * Called when a player is loaded.
 *
 * @param id                Client index
 *
 * @noreturn
 */
forward GMX_PP_PlayerLoaded(const id);

/**
 * Called when a value of a key is changed.
 *
 * @param id                Client index
 * @param key               Unique key
 *
 * @noreturn
 */
forward APS_PlayerKeyChanged(const id, const key[]);

/**
 * Checks if the specified key for player exists.
 *
 * @param id                Client index
 * @param key               Unique key to which the value will be set
 *
 * @return                  true on success, false otherwise
 * @error                   If the index is not within the range of 1 to MaxClients,
 *                          an error will be thrown.
 */
native bool:GMX_PP_HasKey(const id, const key[]);

/**
 * Gets the value of the specified key set to the player as string.
 *
 * @param id                Client index
 * @param key               Unique key to search for
 * @param dest              Buffer to copy value to
 * @param length            Maximum buffer size
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native GMX_PP_GetString(const id, const key[], dest[], const length, const defaultValue[] = "");

/**
 * Sets a string value for a player for the specified key.
 *
 * @param id                Client index
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native GMX_PP_SetString(const id, const key[], const value[]);

/**
 * Gets the value of the specified key set to the player as integer.
 *
 * @param id                Client index
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native GMX_PP_GetNumber(const id, const key[], const defaultValue = 0);

/**
 * Sets an integer value for a player for the specified key.
 *
 * @param id                Client index
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native GMX_PP_SetNumber(const id, const key[], const value);

/**
 * Gets the value of the specified key set to the player as boolean.
 *
 * @param id                Client index
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native bool:GMX_PP_GetBool(const id, const key[], const bool:defaultValue = false);

/**
 * Sets a boolean value for a player for the specified key.
 *
 * @param id                Client index
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native GMX_PP_SetBool(const id, const key[], const bool:value);

/**
 * Gets the value of the specified key set to the player as float.
 *
 * @param id                Client index
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native Float:GMX_PP_GetFloat(const id, const key[], const Float:defaultValue = 0.0);

/**
 * Sets a float value for a player for the specified key.
 *
 * @param id                Client index
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native GMX_PP_SetFloat(const id, const key[], const Float:value);
