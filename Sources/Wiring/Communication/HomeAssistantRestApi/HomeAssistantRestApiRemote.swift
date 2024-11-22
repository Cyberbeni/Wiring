extension HomeAssistantRestApi {
	enum Remote {
		struct SendCommand: HomeAssistantServiceCall {
			var domain: String { "remote" }
			var service: String { "send_command" }
			let serviceData: ServiceData

			struct ServiceData: Encodable {
				let entityId: String
				let device: String
				let command: Command

				enum Command: String, Encodable {
					case open
					case close
					case stop
				}
			}
		}
	}
}
