#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif
import Foundation

actor HomeAssistantRestApi {
	static func jsonEncoder() -> JSONEncoder {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
		return encoder
	}

	let config: Config.HomeAssistant
	let encoder = jsonEncoder()

	init(config: Config.HomeAssistant) {
		self.config = config
	}

	func callService(_ serviceCall: any HomeAssistantServiceCall) async {
		guard let url = URL(string: "services/\(serviceCall.domain)/\(serviceCall.service)", relativeTo: config.baseAddress) else {
			Log.error("Unable to create URL.")
			return
		}
		Log.debug("URL: \(url.absoluteString)")
		do {
			var request = URLRequest(url: url)
			request.httpMethod = "POST"
			request.allHTTPHeaderFields = [
				"Authorization": "Bearer \(config.accessToken)",
				"Content-Type": "application/json",
			]
			request.httpBody = try encoder.encode(serviceCall.serviceData)
			Log.info("Calling HomeAssistant service: \(serviceCall)")
			let (data, response) = try await URLSession.shared.data(for: request)
			if let response = response as? HTTPURLResponse {
				if (200 ..< 300).contains(response.statusCode) {
					Log.debug("HTTP call OK.")
				} else {
					let responseText = String(decoding: data, as: UTF8.self)
					Log.error("Error status code: \(response.statusCode), body: \(responseText)")
				}
			} else {
				Log.error("Response is not HTTPURLResponse.")
			}
		} catch {
			Log.error(error)
		}
	}
}
