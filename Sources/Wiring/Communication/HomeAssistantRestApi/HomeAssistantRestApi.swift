import AsyncHTTPClient
import Foundation

actor HomeAssistantRestApi {
	private static func jsonEncoder() -> JSONEncoder {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
		return encoder
	}

	private let config: Config.HomeAssistant
	private let encoder = jsonEncoder()
	private let maxResponseSize = 100_000

	init(config: Config.HomeAssistant) {
		self.config = config
	}

	func callService(_ serviceCall: any HomeAssistantServiceCall) async {
		let url = config.baseAddress.appending("services/\(serviceCall.domain)/\(serviceCall.service)")
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
			let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
			if (200 ..< 300).contains(response.status.code) {
				Log.debug("HTTP call OK.")
			} else {
				let body = try await response.body.collect(upTo: maxResponseSize)
				Log.error("Error status code: \(response.status.code), body: \(String(buffer: body))")
			}
		} catch {
			Log.error(error)
		}
	}
}
