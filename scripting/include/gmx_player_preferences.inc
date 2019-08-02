#if defined _gmx_player_preferences_included
	#endinput
#endif

#define _gmx_player_preferences_included

forward GMX_PP_PlayerLoading(const id);
forward GMX_PP_PlayerLoaded(const id);
forward APS_PlayerKeyChanged(const id, const key[]);

native bool:GMX_PP_HasKey(const id, const key[]);
native GMX_PP_GetString(const id, const key[], dest[], const length, const defaultValue[] = "");
native GMX_PP_SetString(const id, const key[], const value[]);
native GMX_PP_GetNumber(const id, const key[], const defaultValue = 0);
native GMX_PP_SetNumber(const id, const key[], const value);
native bool:GMX_PP_GetBool(const id, const key[], const bool:defaultValue = false);
native GMX_PP_SetBool(const id, const key[], const bool:value);
native Float:GMX_PP_GetFloat(const id, const key[], const Float:defaultValue = 0.0);
native GMX_PP_SetFloat(const id, const key[], const Float:value);
