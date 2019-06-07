#if defined _gmx_consts_included
	#endinput
#endif

#define _gmx_consts_included

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