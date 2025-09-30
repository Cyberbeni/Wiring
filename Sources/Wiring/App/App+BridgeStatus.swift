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
				model: "Bridge",
				name: name,
				viaDevice: nil,
			),
			deviceClass: .connectivity,
			name: nil,
			payloadOff: Mqtt.Availability.offline.rawValue,
			payloadOn: Mqtt.Availability.online.rawValue,
			stateTopic: stateTopic,
			uniqueId: stateTopic.toUniqueId(),
		)
		await mqttClient.publish(
			topic: "\(mqttConfig.homeAssistantBaseTopic)/binary_sensor/\(mqttConfig.baseTopic)-server/state/config"
				.toHomeAssistantAutodiscoveryTopic(),
			message: config,
			retain: true,
		)
	}
}
