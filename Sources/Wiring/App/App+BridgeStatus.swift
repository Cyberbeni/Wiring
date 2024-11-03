extension App {
	func setupServerState() async {
		guard generalConfig.publishServerState else { return }
		let mqttConfig = generalConfig.mqtt
		let name = if mqttConfig.baseTopic == "wiring" {
			"Wiring server"
		} else {
			"Wiring server (\(mqttConfig.baseTopic))"
		}
		let stateTopic = mqttClient.stateTopic
		let config = Mqtt.BinarySensor(
			availabilityTopic: nil,
			device: .init(
				identifiers: stateTopic,
				name: name
			),
			deviceClass: .connectivity,
			name: nil,
			objectId: nil,
			payloadOff: Mqtt.Availability.offline.rawValue,
			payloadOn: Mqtt.Availability.online.rawValue,
			stateTopic: stateTopic,
			uniqueId: stateTopic.replacingOccurrences(of: "/", with: "_")
		)
		await mqttClient.setOnConnectMessage(
			topic: "\(mqttConfig.homeAssistantBaseTopic)/binary_sensor/\(mqttConfig.baseTopic)-server/state/config",
			message: config
		)
	}
}
