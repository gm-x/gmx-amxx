#if defined _gmx_access_included
	#endinput
#endif

#define _gmx_access_included

enum GMX_PlayerAccess {
	GMX_InvalidPlayerAccess = -1,
};

/**
 * Called when GM-X Access is initiated.
 *
 * @noreturn
 */
forward GMX_AccessInit();

/**
 * Returns the key pointer of the specified key.
 *
 * @param key      Key name to find
 *
 * @return         Key pointer on success, GMX_InvalidPlayerAccess if key was not
 *                 found
 * @error          If an invalid number of arguments is set, an error will be
 *                 thrown.
 */
native GMX_PlayerAccess:GMX_AccessGetPointer(const key[]);

/**
 * Gets access key.
 *
 * @param access   Key pointer
 * @param key      Buffer to copy key value to
 * @param len      Maximum size of the buffer
 *
 * @return         Key pointer on success, GMX_InvalidPlayerAccess if key was not
 *                 found
 * @error          If an invalid number of arguments is set, or an invalid pointer
 *                 is set, an error will be thrown.
 */
native GMX_AccessGetKey(const GMX_PlayerAccess:access, key[], const len);

/**
 * Returns if player has access by key.
 *
 * @param player   Client index
 * @param key      Key name
 *
 * @return         true if player has access, false otherwise
 * @error          If player is not connected, or an invalid number of arguments is
 *                 set, an error will be thrown.
 */
native bool:GMX_PlayerHasAccess(const player, const key[]);

/**
 * Returns if player has access by key pointer.
 *
 * @param player   Client index
 * @param access   Pointer to key
 *
 * @return         true if player has access, false otherwise
 * @error          If player is not connected, or an invalid pointer is set, or an
 *                 invalid number of arguments is set, an error will be thrown.
 */
native bool:GMX_PlayerHasPAccess(const player, GMX_PlayerAccess:access);