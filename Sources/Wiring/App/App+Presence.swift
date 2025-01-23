extension App {
	func setupPresenceDetectors() async {
		guard let presenceConfig else { return }
		let mqttConfig = generalConfig.mqtt

		presenceDetectorAggregators = presenceConfig.entries.reduce(into: [:]) { result, entry in
			result[entry.key] = PresenceDetectorAggregator(
				mqttClient: mqttClient,
				mqttConfig: mqttConfig,
				presenceConfig: presenceConfig,
				person: entry.key
			)
		}

		blePresenceDetectors = presenceConfig.entries.compactMap { person, config in
			guard let device = config.espresenseDevice,
			      let aggregator = presenceDetectorAggregators[person]
			else { return nil }
			return BlePresenceDetector(
				mqttClient: mqttClient,
				presenceConfig: presenceConfig,
				topic: "\(presenceConfig.espresenseDevicesBaseTopic)/\(device)",
				presenceDetectorAggregator: aggregator
			)
		}
		for detector in blePresenceDetectors {
			await detector.start()
		}

		let ips = presenceConfig.entries.reduce(into: [String: String]()) { result, entry in
			guard let ip = entry.value.ip else { return }
			result[entry.key] = ip
		}
		if !ips.isEmpty {
			do {
				networkPresenceDetector = try NetworkPresenceDetector(
					presenceConfig: presenceConfig,
					ips: ips,
					presenceDetectorAggregators: presenceDetectorAggregators
				)
			} catch {
				Log.error("Failed to initialize NetworkPresenceDetector: \(error)")
			}
		}

		for person in presenceConfig.entries.keys {
			let name = "Presence \(person)"
			let stateTopic = "\(mqttConfig.baseTopic)/presence/\(person)"
			let binarySensorConfig = Mqtt.BinarySensor(
				availabilityTopic: mqttClient.stateTopic,
				device: .init(
					identifiers: stateTopic,
					name: name,
					viaDevice: mqttClient.stateTopic
				),
				deviceClass: .presence,
				name: .explicitNone,
				payloadOff: nil,
				payloadOn: nil,
				stateTopic: stateTopic,
				uniqueId: stateTopic.toUniqueId()
			)
			await mqttClient.publish(
				topic: "\(mqttConfig.homeAssistantBaseTopic)/binary_sensor/\(mqttConfig.baseTopic)-presence/\(person)/config",
				message: binarySensorConfig,
				retain: true
			)
			let deviceTrackerConfig = Mqtt.DeviceTracker(
				availabilityTopic: mqttClient.stateTopic,
				device: .init(
					identifiers: stateTopic,
					name: name,
					viaDevice: mqttClient.stateTopic
				),
				name: .explicitNone,
				payloadHome: Mqtt.BinarySensor.Payload.on.rawValue,
				payloadNotHome: Mqtt.BinarySensor.Payload.off.rawValue,
				sourceType: .router,
				stateTopic: stateTopic,
				uniqueId: stateTopic.toUniqueId()
			)
			await mqttClient.publish(
				topic: "\(mqttConfig.homeAssistantBaseTopic)/device_tracker/\(mqttConfig.baseTopic)-presence/\(person)/config",
				message: deviceTrackerConfig,
				retain: true
			)
		}
	}

	func startPresenceDetectors() async {
		await networkPresenceDetector?.start()
	}
}
