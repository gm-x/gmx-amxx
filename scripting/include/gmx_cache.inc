#if defined _gmx_cache_included
	#endinput
#endif

#define _gmx_cache_included

#include <grip>

/**
 * Loads saved cache by name.
 *
 * @param name     JSON name
 * @param data     JSON handle
 *
 * @return         true on success, false otherwise
 * @error          If an invalid number of arguments is set, an error will be thrown.
 */
native bool:GMX_CacheLoad(const name[], &GripJSONValue:data);

/**
 * Saves cache by name.
 *
 * @param name     JSON name
 * @param data     JSON handle
 *
 * @return         true on success, false otherwise
 * @error          If an invalid number of arguments is set, an error will be thrown.
 */
native bool:GMX_CacheSave(const name[], const GripJSONValue:data);