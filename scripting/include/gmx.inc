#if defined _gmx_included
	#endinput
#endif

#define _gmx_included

#include <gmx_consts>
#include <gmx_stocks>

/**
 * Called when config was loaded
 */
forward GMX_CfgLoaded();

/**
 * Make request to API
 *
 * @param endpoint
 * @param data
 * @param callback
 * @param param
 *
 * @return ID of request, -1 if error occurred
 */
native GMX_MakeRequest(const endpoint[], GripJSONValue:data, const callback[], const param = 0);

/**
 * Make request to API
 *
 * @param endpoint
 * @param fmt
 * @param ...
 *
 * @return 1 if success, 0 if error occurred
 */
native GMX_Log(const GmxLogLevel:level, const fmt[], any:...);
