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

	func callService(_ serviceCall: some HomeAssistantServiceCall) {
		do {
			let request = try HTTPClient.Request(
				url: "\(config.baseAddress)services/\(serviceCall.domain)/\(serviceCall.service)",
				method: .POST,
				headers: [
					"Authorization": "Bearer \(config.accessToken)",
					"Content-Type": "application/json",
				],
				body: .bytes(encoder.encode(serviceCall.serviceData)),
			)
			Log.info("Calling HomeAssistant service: \(serviceCall)")
			Log.debug("URL: \(request.url)")
			HTTPClient.shared.execute(request: request).whenComplete { result in
				switch result {
				case let .failure(error):
					Log.error(error)
				case let .success(response):
					if (200 ..< 300).contains(response.status.code) {
						Log.debug("HTTP call OK.")
					} else {
						let responseText = response.body.map { String(buffer: $0) } ?? ""
						Log.error("Error status code: \(response.status.code), body: \(responseText)")
					}
				}
			}
		} catch {
			Log.error(error)
		}
	}
}
