actor PresenceDetectorAggregator {
	private let mqttClient: MQTTClient

	private let mqttConfig: Config.Mqtt
	private let presenceConfig: Config.Presence

	private let person: String
	private var isPresent: Bool?
	private var networkPresence: Bool = false { didSet { handleInput() } }
	func setNetworkPresence(_ newValue: Bool) { networkPresence = newValue }
	private var espresensePresence: Bool = false { didSet { handleInput() } }
	func setEspresensePresence(_ newValue: Bool) { espresensePresence = newValue }

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
		if [networkPresence, espresensePresence].contains(true) {
			isPresent = true
		} else {
			isPresent = false
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
