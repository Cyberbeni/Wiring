import Foundation

actor EspresensePresenceDetector {
	private let mqttClient: MQTTClient
	private let topic: String
	private let clientId = UUID()

	private var isStarted = false

	init(mqttClient: MQTTClient, topic: String) {
		self.mqttClient = mqttClient
		self.topic = topic
	}

	func start() async {
		guard !isStarted else { return }
		isStarted = true

		await mqttClient.setSubscriptions(clientId: clientId, topics: ["\(topic)/+"]) { [topic] result in
			guard
				case let .success(msg) = result,
				msg.topicName.hasPrefix("\(topic)/")
			else { return }
			print("MQTT message: \(msg.topicName)")
		}
	}
}
