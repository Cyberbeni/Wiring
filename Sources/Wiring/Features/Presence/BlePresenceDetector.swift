import Foundation

actor BlePresenceDetector {
	private let mqttClient: MQTTClient
	private let clientId = UUID()
	private let presenceConfig: Config.Presence
	private let topic: String
	private let presenceDetectorAggregator: PresenceDetectorAggregator

	private var isStarted = false
	private var presenceTimeoutTask: Task<Void, Error>?

	init(
		mqttClient: MQTTClient,
		presenceConfig: Config.Presence,
		topic: String,
		presenceDetectorAggregator: PresenceDetectorAggregator
	) {
		self.mqttClient = mqttClient
		self.presenceConfig = presenceConfig
		self.topic = topic
		self.presenceDetectorAggregator = presenceDetectorAggregator
	}

	func start() async {
		guard !isStarted else { return }
		isStarted = true

		await mqttClient.setSubscriptions(clientId: clientId, topics: ["\(topic)/+"]) { [weak self] _ in
			guard
				let self
			else { return }
			Task {
				await updateOutput()
			}
		}
		scheduleAway()
	}

	private func updateOutput() async {
		await presenceDetectorAggregator.setBlePresence(true)
		scheduleAway()
	}

	private func scheduleAway() {
		presenceTimeoutTask?.cancel()
		presenceTimeoutTask = Task {
			try await Task.sleep(for: .seconds(presenceConfig.espresenseTimeout.seconds))
			guard !Task.isCancelled else { return }
			await presenceDetectorAggregator.setBlePresence(false)
		}
	}
}
