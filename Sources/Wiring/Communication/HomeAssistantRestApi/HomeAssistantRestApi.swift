import AsyncHTTPClient

nonisolated struct HomeAssistantRestApi {
	private static func jsonEncoder() -> JSONEncoder {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
		return encoder
	}

	let config: Config.HomeAssistant
	private let encoder = jsonEncoder()
	private let maxResponseSize = 100_000

	@concurrent
	func callService(_ serviceCall: any HomeAssistantServiceCall) async {
		let url = "\(config.baseAddress)services/\(serviceCall.domain)/\(serviceCall.service)"
		Log.debug("URL: \(url)")
		do {
			var request = HTTPClientRequest(url: url)
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
				let responseData = try await response.body.collect(upTo: maxResponseSize)
				let responseText = String(buffer: responseData)
				Log.error("Error status code: \(response.status.code), body: \(responseText)")
			}
		} catch {
			Log.error(error)
		}
	}
}
