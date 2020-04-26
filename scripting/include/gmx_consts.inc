#if defined _gmx_consts_included
	#endinput
#endif

#define _gmx_consts_included

const GMX_MAX_COMMAND_LENGTH = 32;
const GMX_MAX_COMMAND_DATA_LENGTH = 64;

enum GmxResponseStatus {
	GmxResponseStatusOk,
	GmxResponseStatusCanceled,
	GmxResponseStatusError,
	GmxResponseStatusTimeout,
	GmxResponseStatusNotFound,
	GmxResponseStatusBadToken,
	GmxResponseStatusServerError,
	GmxResponseStatusBadResponse,
	GmxResponseStatusUnknownError
}

enum GmxLogLevel (+=1) {
	GmxLogCritical = 0,
	GmxLogError,
	GmxLogInfo,
	GmxLogDebug
};