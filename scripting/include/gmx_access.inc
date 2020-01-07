#if defined _gmx_access_included
	#endinput
#endif

#define _gmx_access_included

enum GMX_PlayerAccess {
	GMX_InvalidPlayerAccess = -1,
};

forward GMX_AccessInit();

native GMX_PlayerAccess:GMX_AccessGetPointer(const key[]);
native GMX_AccessGetKey(const GMX_PlayerAccess:access, key[], const len);
native bool:GMX_PlayerHasAccess(const player, const key[]);
native bool:GMX_PlayerHasPAccess(const player, GMX_PlayerAccess:access);
