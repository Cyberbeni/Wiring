actor PresenceDetector {
	private let mqttClient: MQTTClient

	private let mqttConfig: Config.Mqtt
	private let presenceConfig: Config.Presence

	private let person: String
	private var isPresent: Bool?
	var networkPresence: Bool? { didSet { handleInput() } }
	var espresensePresence: Bool? { didSet { handleInput() } }

	private var updateOutputTask: Task<Void, Error>?

	init(
		mqttClient: MQTTClient,
		mqttConfig: Config.Mqtt,
		presenceConfig: Config.Presence,
		person: String
	) {
		self.mqttClient = mqttClient
		self.mqttConfig = mqttConfig
		self.presenceConfig = presenceConfig
		self.person = person
	}

	private func handleInput() {
		let previousIsPresent = isPresent
		let input = [networkPresence, espresensePresence]
		if input.contains(true) {
			isPresent = true
		} else if input.contains(false) {
			isPresent = false
		} else {
			isPresent = nil
		}
		guard previousIsPresent != isPresent else { return }
		updateOutputTask?.cancel()
		updateOutputTask = Task {
			if previousIsPresent != nil, isPresent == false {
				try await Task.sleep(for: .seconds(presenceConfig.awayTimeout.seconds), tolerance: .seconds(0.1))
			}
			guard !Task.isCancelled else { return }
			await mqttClient.publish(topic: "\(mqttConfig.baseTopic)/presence/\(person)", rawMessage: Mqtt.BinarySensor.Payload(isPresent), retain: true)
		}
	}
}
