extension App {
	func setupPresenceDetectionMqttDiscovery() async {
		guard let presenceConfig else { return }
		let mqttConfig = generalConfig.mqtt

		for person in presenceConfig.entries.keys {
			// TODO: rename when not just watching WiFi
			let name = "Presence WiFi \(person)"
			let stateTopic = "\(mqttConfig.baseTopic)/presence/\(person)"
			let config = Mqtt.BinarySensor(
				availabilityTopic: mqttClient.stateTopic,
				device: .init(
					identifiers: stateTopic,
					name: nil
				),
				deviceClass: .presence,
				name: name,
				objectId: name,
				stateTopic: stateTopic,
				uniqueId: stateTopic.replacingOccurrences(of: "/", with: "_")
			)
			await mqttClient.setOnConnectMessage(
				topic: "\(mqttConfig.homeAssistantBaseTopic)/binary_sensor/\(mqttConfig.baseTopic)-presence/\(person)/config",
				message: config
			)
		}
	}

	func runNetworkPresenceDetection() {
		guard let presenceConfig else { return }
		let ips = presenceConfig.entries.reduce(into: [String: String]()) { result, entry in
			guard let ip = entry.value.ip else { return }
			result[entry.key] = ip
		}
		guard !ips.isEmpty else { return }
		let networkPresenceDetector: NetworkPresenceDetector
		do {
			networkPresenceDetector = try NetworkPresenceDetector(ips: Set(ips.values), pingInterval: presenceConfig.pingInterval.seconds)
		} catch {
			Log.error("Failed to initialize NetworkPresenceDetector: \(error)")
			return
		}

		let mqttConfig = generalConfig.mqtt
		let arpInterval = presenceConfig.arpInterval

		Task {
			while !Task.isCancelled {
				let activeIps = await networkPresenceDetector.getActiveIps()
				for (person, ip) in ips {
					await mqttClient.publish(topic: "\(mqttConfig.baseTopic)/presence/\(person)", rawMessage: activeIps.contains(ip) ? Mqtt.BinarySensor.Payload.on : .off, retain: false)
				}
				try await Task.sleep(for: .seconds(arpInterval.seconds), tolerance: .seconds(0.1))
			}
		}
	}
}
