#if defined _gmx_cache_included
	#endinput
#endif

#define _gmx_cache_included

#include <grip>

native bool:GMX_CacheLoad(const name[], &GripJSONValue:data);
native bool:GMX_CacheSave(const name[], const GripJSONValue:data);