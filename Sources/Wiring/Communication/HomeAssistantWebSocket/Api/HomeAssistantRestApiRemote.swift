extension HomeAssistantWebSocket.Api {
	enum Remote {
		struct SendCommand: HomeAssistantServiceCall {
			var domain: String { "remote" }
			var service: String { "send_command" }
			let serviceData: ServiceData
			let entityId: String

			struct ServiceData: DictionaryEncodable {
				let device: String
				let command: Command

				enum Command: String {
					case open
					case close
					case stop
				}

				func asDictionary() -> [String : String] {
					[
						"device": device,
						"command": command.rawValue
					]
				}
			}
		}
	}
}
