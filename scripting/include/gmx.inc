#if defined _gmx_included
	#endinput
#endif

#define _gmx_included

#include <gmx_consts>
#include <gmx_stocks>

#define GMX_MAJOR_VERSION			0
#define GMX_MINOR_VERSION			1
#define GMX_MAINTENANCE_VERSION		1

stock const GMX_API_VERSION_STR[] = "0.1.0";

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
