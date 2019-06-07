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

#define GMX_MAX_ASSIGN_TOKEN_LENGTH	36
#define GMX_MAX_API_TOKEN_LENGTH	65
#define GMX_MAX_PATH_LENGTH			128
#define GMX_MAX_URL_LENGTH			256
#define GMX_MAX_ERROR_MSG_LENGTH	256
#define GMX_MAX_LOG_MSG_LENGTH		512
#define GMX_MAX_DATA_LENGTH			4000