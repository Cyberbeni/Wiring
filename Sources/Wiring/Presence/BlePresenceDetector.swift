import Foundation

actor BlePresenceDetector {
	private let mqttClient: MQTTClient
	private let presenceConfig: Config.Presence
	private let topic: String
	private let clientId = UUID()

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

		await mqttClient.setSubscriptions(clientId: clientId, topics: ["\(topic)/+"]) { [weak self] result in
			guard
				let self,
				case let .success(msg) = result,
				msg.topicName.hasPrefix("\(topic)/")
			else { return }
			Task {
				await updateOutput()
			}
		}
	}

	private func updateOutput() async {
		await presenceDetectorAggregator.setBlePresence(true)
		presenceTimeoutTask?.cancel()
		presenceTimeoutTask = Task {
			try await Task.sleep(for: .seconds(presenceConfig.espresenseTimeout.seconds), tolerance: .seconds(0.1))
			guard !Task.isCancelled else { return }
			await presenceDetectorAggregator.setBlePresence(false)
		}
	}
}