actor PresenceDetectorAggregator {
	private let mqttClient: MQTTClient

	private let mqttConfig: Config.Mqtt
	private let presenceConfig: Config.Presence
	private let presenceItem: Config.Presence.PresenceItem

	private let person: String
	private var isPresent: Bool?

	func setNetworkPresence(_ newValue: Bool) { networkPresence = newValue }
	private var networkPresence: Bool = false {
		didSet {
			if oldValue != networkPresence {
				Log.debug("\(person) - networkPresence: \(networkPresence)")
			}
			handleInput()
		}
	}

	func setBlePresence(_ newValue: Bool) { blePresence = newValue }
	private var blePresence: Bool = false {
		didSet {
			if oldValue != blePresence {
				Log.debug("\(person) - blePresence: \(blePresence)")
			}
			handleInput()
		}
	}

	func setHomeAssistantPresence(_ newValue: Bool) { homeAssistantPresence = newValue }
	private var homeAssistantPresence: Bool = false {
		didSet {
			if oldValue != homeAssistantPresence {
				Log.debug("\(person) - homeAssistantPresence: \(homeAssistantPresence)")
			}
			handleInput()
		}
	}

	private var updateOutputTask: Task<Void, Error>?

	init(
		mqttClient: MQTTClient,
		mqttConfig: Config.Mqtt,
		presenceConfig: Config.Presence,
		presenceItem: Config.Presence.PresenceItem,
		person: String,
	) {
		self.mqttClient = mqttClient
		self.mqttConfig = mqttConfig
		self.presenceConfig = presenceConfig
		self.presenceItem = presenceItem
		self.person = person
	}

	private func handleInput() {
		let previousIsPresent = isPresent
		isPresent = networkPresence || blePresence || homeAssistantPresence

		guard previousIsPresent != isPresent else { return }
		updateOutputTask?.cancel()
		updateOutputTask = Task {
			if previousIsPresent != nil, isPresent == false {
				try await Task.sleep(for: .seconds(presenceItem.awayTimeout?.seconds ?? presenceConfig.awayTimeout.seconds))
			}
			guard !Task.isCancelled else { return }
			await mqttClient.publish(
				topic: "\(mqttConfig.baseTopic)/presence/\(person)",
				rawMessage: Mqtt.BinarySensor.Payload(isPresent),
				retain: true,
			)
		}
	}
}
