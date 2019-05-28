#if defined _gmx_included
	#endinput
#endif

#define _gmx_included

#include <gmx_consts>
#include <gmx_player>


forward GamexCfgLoaded();

native GamexMakeRequest(const endpoint[], GripJSONValue:data, const callback[], const param = 0);

native GamexLog(const GmxLogLevel:level, const fmt[], any:...);
