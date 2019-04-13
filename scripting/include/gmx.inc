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

native GamexMakeRequest(const endpoint[], GripJSONValue:data, const callback[], const param = 0);
