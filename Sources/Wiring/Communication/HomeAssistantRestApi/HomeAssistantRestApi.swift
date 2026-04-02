import AsyncHTTPClient

nonisolated struct HomeAssistantRestApi {
	static func jsonEncoder() -> JSONEncoder {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
		return encoder
	}

	let config: Config.HomeAssistant
	let encoder = jsonEncoder()

	@concurrent
	func callService(_ serviceCall: any HomeAssistantServiceCall) async {
		guard let url = URL(string: "services/\(serviceCall.domain)/\(serviceCall.service)", relativeTo: config.baseAddress) else {
			Log.error("Unable to create URL.")
			return
		}
		Log.debug("URL: \(url.absoluteString)")
		do {
			var request = HTTPClientRequest(url: url.absoluteString)
			request.method = .POST
			request.headers = [
				"Authorization": "Bearer \(config.accessToken)",
				"Content-Type": "application/json",
			]
			request.body = try .bytes(encoder.encode(serviceCall.serviceData))
			Log.info("Calling HomeAssistant service: \(serviceCall)")
			let response = try await HTTPClient.shared.execute(request, timeout: .seconds(10))
			if (200 ..< 300).contains(response.status.code) {
				Log.debug("HTTP call OK.")
			} else {
				let responseData = try await response.body.collect(upTo: .max)
				let responseText = String(buffer: responseData)
				Log.error("Error status code: \(response.status.code), body: \(responseText)")
			}
		} catch {
			Log.error(error)
		}
	}
}
