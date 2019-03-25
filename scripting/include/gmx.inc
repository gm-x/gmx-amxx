enum {
	GMX_REQ_STATUS_ERROR = 0,
	GMX_REQ_STATUS_OK = 1
}

native GamexMakeRequest(const endpoint[], JSON:data, const callback[], const param = 0);
