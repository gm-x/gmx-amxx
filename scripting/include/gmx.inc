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

forward GamexCfgLoaded();

native GamexMakeRequest(const endpoint[], GripJSONValue:data, const callback[], const param = 0);

native GamexLog(const GmxLogLevel:level, const fmt[], any:...);
